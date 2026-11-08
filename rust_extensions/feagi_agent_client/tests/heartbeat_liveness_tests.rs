//! Heartbeat liveness against a real FEAGI agent server.
//!
//! The server is a `FeagiAgentHandler` from the newer feagi-core release (dev-dependency
//! `feagi-agent-server`), listening on WebSocket ports the OS assigned. The client is this
//! crate's registration + heartbeat session built on the older SDK the extension ships with.
//! The server runs its stale-agent pruning with a short `heartbeat_timeout`, so liveness can be
//! proven in well under a second per interval:
//!
//! - a client with heartbeats survives more than 3x the server's timeout, same agent id;
//! - a client after `stop_heartbeat()` is pruned;
//! - after the server deregisters the agent, `is_heartbeat_alive` turns false within the
//!   configured number of missed acks.

use std::net::{Ipv4Addr, TcpListener};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::thread::{self, JoinHandle};
use std::time::{Duration, Instant};

use base64::Engine;
use feagi_agent_client::heartbeat::HeartbeatConfig;
use feagi_agent_client::session::{register_with_heartbeat, RegisteredSession};
use feagi_agent_server::server::auth::DummyAuth;
use feagi_agent_server::server::{AgentLivenessConfig, FeagiAgentHandler};
use feagi_io_server::protocol_implementations::websocket::websocket_std::{
    FeagiWebSocketServerPublisherProperties, FeagiWebSocketServerRouterProperties,
};

/// Server-side prune threshold used by every test. All other timings derive from it.
const SERVER_HEARTBEAT_TIMEOUT: Duration = Duration::from_millis(600);
/// The client heartbeats several times per server timeout.
const CLIENT_INTERVAL_DIVISOR: u32 = 6;
/// Missed acks tolerated by the client in these tests.
const MAX_MISSED_ACKS: i64 = 3;
/// Server loop pause between polls; only bounds busy-looping.
const SERVER_STEP: Duration = Duration::from_millis(2);

/// Client heartbeat interval: a fraction of the server timeout.
fn client_interval() -> Duration {
    SERVER_HEARTBEAT_TIMEOUT / CLIENT_INTERVAL_DIVISOR
}

/// OS-assigned free TCP port.
fn reserve_free_port() -> u16 {
    TcpListener::bind((Ipv4Addr::LOCALHOST, 0))
        .expect("failed to bind ephemeral port")
        .local_addr()
        .expect("failed to read local addr")
        .port()
}

/// What the server thread publishes for assertions, and the switches the test flips.
#[derive(Default)]
struct ServerProbe {
    registered_agent_ids: Mutex<Vec<String>>,
    stop: AtomicBool,
    force_deregister_all: AtomicBool,
}

impl ServerProbe {
    fn registered(&self) -> Vec<String> {
        self.registered_agent_ids
            .lock()
            .map(|ids| ids.clone())
            .unwrap_or_default()
    }
}

struct TestServer {
    probe: Arc<ServerProbe>,
    thread: Option<JoinHandle<()>>,
    registration_url: String,
}

impl TestServer {
    /// Start a real agent server on OS-assigned ports and wait until its handler is polling.
    fn start() -> Self {
        let registration_port = reserve_free_port();
        let visualization_port = reserve_free_port();
        let registration_bind = format!("{}:{registration_port}", Ipv4Addr::LOCALHOST);
        let registration_url = format!("ws://{registration_bind}");
        let visualization_bind = format!("{}:{visualization_port}", Ipv4Addr::LOCALHOST);
        let visualization_url = format!("ws://{visualization_bind}");

        let probe = Arc::new(ServerProbe::default());
        let probe_for_thread = Arc::clone(&probe);
        let registration_url_for_thread = registration_url.clone();
        let (ready_tx, ready_rx) = std::sync::mpsc::channel::<Result<(), String>>();

        let thread = thread::spawn(move || {
            // The handler holds non-Send transport objects, so it lives on this thread only.
            let mut handler = FeagiAgentHandler::new_with_liveness_config(
                Box::new(DummyAuth {}),
                AgentLivenessConfig {
                    heartbeat_timeout: SERVER_HEARTBEAT_TIMEOUT,
                    stale_check_interval: SERVER_HEARTBEAT_TIMEOUT / 12,
                },
            );
            let started = (|| -> Result<(), String> {
                let router = FeagiWebSocketServerRouterProperties::new_with_remote(
                    &registration_bind,
                    &registration_url_for_thread,
                )
                .map_err(|e| format!("router properties: {e}"))?;
                handler
                    .add_and_start_command_control_server(Box::new(router))
                    .map_err(|e| format!("start router: {e}"))?;
                let publisher = FeagiWebSocketServerPublisherProperties::new(
                    &visualization_bind,
                    &visualization_url,
                )
                .map_err(|e| format!("publisher properties: {e}"))?;
                handler.add_publisher_server(Box::new(publisher));
                Ok(())
            })();
            let started_ok = started.is_ok();
            let _ = ready_tx.send(started);
            if !started_ok {
                return;
            }

            while !probe_for_thread.stop.load(Ordering::SeqCst) {
                if probe_for_thread
                    .force_deregister_all
                    .swap(false, Ordering::SeqCst)
                {
                    handler.force_deregister_all_agents("integration test");
                }
                if let Err(e) = handler.poll_command_and_control() {
                    eprintln!("server poll error: {e}");
                }
                let ids: Vec<String> = handler
                    .get_all_registered_agents()
                    .keys()
                    .map(|id| id.to_base64())
                    .collect();
                if let Ok(mut slot) = probe_for_thread.registered_agent_ids.lock() {
                    *slot = ids;
                }
                thread::sleep(SERVER_STEP);
            }
        });

        ready_rx
            .recv_timeout(Duration::from_secs(5))
            .expect("server thread did not report readiness")
            .expect("server failed to start");
        Self {
            probe,
            thread: Some(thread),
            registration_url,
        }
    }

    /// Register a client with heartbeats whose interval is a fraction of the server timeout.
    fn register(&self, agent_name: &str) -> RegisteredSession {
        let config = HeartbeatConfig::new(client_interval().as_secs_f64(), MAX_MISSED_ACKS)
            .expect("valid config");
        register_with_heartbeat(
            &self.registration_url,
            &descriptor_b64(agent_name),
            &token_b64(),
            config,
        )
        .expect("registration against the test server must succeed")
    }
}

impl Drop for TestServer {
    fn drop(&mut self) {
        self.probe.stop.store(true, Ordering::SeqCst);
        if let Some(thread) = self.thread.take() {
            let _ = thread.join();
        }
    }
}

/// Base64 of the 48-byte descriptor: instance_id(4) + manufacturer(20) + name(20) + version(4).
fn descriptor_b64(agent_name: &str) -> String {
    let mut bytes = [0u8; 48];
    let manufacturer = b"neuraville";
    bytes[4..4 + manufacturer.len()].copy_from_slice(manufacturer);
    let name = agent_name.as_bytes();
    bytes[24..24 + name.len()].copy_from_slice(name);
    bytes[44..48].copy_from_slice(&1u32.to_le_bytes());
    base64::engine::general_purpose::STANDARD.encode(bytes)
}

fn token_b64() -> String {
    base64::engine::general_purpose::STANDARD.encode([0u8; 32])
}

fn wait_until(limit: Duration, condition: impl Fn() -> bool) -> bool {
    let deadline = Instant::now() + limit;
    while Instant::now() < deadline {
        if condition() {
            return true;
        }
        thread::sleep(SERVER_STEP);
    }
    condition()
}

#[test]
fn heartbeating_client_survives_more_than_three_server_timeouts_with_the_same_agent_id() {
    let server = TestServer::start();
    let mut session = server.register("hb-survivor");
    let agent_id = session.agent_id_b64.clone();
    assert!(
        server.probe.registered().contains(&agent_id)
            || wait_until(SERVER_HEARTBEAT_TIMEOUT, || server
                .probe
                .registered()
                .contains(&agent_id)),
        "server must list the freshly registered agent"
    );

    thread::sleep(SERVER_HEARTBEAT_TIMEOUT * 4);

    assert!(
        server.probe.registered().contains(&agent_id),
        "agent must still be registered under the same id after 4x the server timeout"
    );
    assert!(
        session.heartbeat.is_alive(),
        "heartbeat error: {}",
        session.heartbeat.error()
    );
    assert_eq!(session.heartbeat.agent_id_b64(), agent_id);
    session.heartbeat.stop();
}

#[test]
fn client_is_pruned_after_stop_heartbeat() {
    let server = TestServer::start();
    let mut session = server.register("hb-stopped");
    let agent_id = session.agent_id_b64.clone();
    assert!(wait_until(SERVER_HEARTBEAT_TIMEOUT, || server
        .probe
        .registered()
        .contains(&agent_id)));

    assert!(session.heartbeat.stop());
    assert!(!session.heartbeat.is_alive());

    assert!(
        wait_until(SERVER_HEARTBEAT_TIMEOUT * 4, || !server
            .probe
            .registered()
            .contains(&agent_id)),
        "a stopped client must be pruned by the server's stale scan"
    );
}

#[test]
fn heartbeat_turns_dead_within_max_missed_acks_after_server_deregisters_the_agent() {
    let server = TestServer::start();
    let session = server.register("hb-deregistered");
    let agent_id = session.agent_id_b64.clone();
    assert!(wait_until(SERVER_HEARTBEAT_TIMEOUT, || server
        .probe
        .registered()
        .contains(&agent_id)));
    assert!(session.heartbeat.is_alive());

    server
        .probe
        .force_deregister_all
        .store(true, Ordering::SeqCst);
    assert!(wait_until(SERVER_HEARTBEAT_TIMEOUT, || !server
        .probe
        .registered()
        .contains(&agent_id)));

    // One interval to send the next heartbeat, then `MAX_MISSED_ACKS` unanswered intervals,
    // plus one interval of scheduling slack.
    let interval = client_interval();
    let allowed = interval * (u32::try_from(MAX_MISSED_ACKS).expect("small") + 2);
    assert!(
        wait_until(allowed, || !session.heartbeat.is_alive()),
        "heartbeat must report dead within {allowed:?}"
    );
    assert!(
        !session.heartbeat.error().is_empty(),
        "a dead heartbeat must carry a reason"
    );
}

#[test]
fn live_socket_deregistration_removes_the_agent_from_the_server() {
    let server = TestServer::start();
    let mut session = server.register("hb-self-dereg");
    let agent_id = session.agent_id_b64.clone();
    assert!(wait_until(SERVER_HEARTBEAT_TIMEOUT, || server
        .probe
        .registered()
        .contains(&agent_id)));

    assert!(
        session.heartbeat.deregister(),
        "FEAGI must confirm a deregistration sent over the live session"
    );
    assert!(wait_until(SERVER_HEARTBEAT_TIMEOUT, || !server
        .probe
        .registered()
        .contains(&agent_id)));
    assert!(!session.heartbeat.is_alive());
}
