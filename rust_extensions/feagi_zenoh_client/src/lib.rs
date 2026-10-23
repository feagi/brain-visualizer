//! FEAGI Zenoh Client GDExtension
//!
//! Connects Brain Visualizer to a feagi-core server over zenoh websocket, as the fallback when
//! the legacy websocket agent can't connect. Uses feagi-interop's zenoh worker to join the
//! network and announce Brain Visualizer with a liveliness token. There is no heartbeat: the
//! server counts as connected for as long as its liveliness token is seen, and the server sees
//! Brain Visualizer for as long as this client's token is up.
//!
//! Connecting blocks on network round trips, so it runs on a background thread. Godot polls the
//! state with `poll_state` each frame.

use feagi_basis::parallelism::block_on_thread;
use feagi_basis::parallelism::feagi_worker::feagi_worker_builder::FeagiWorkerBuilder;
use feagi_basis::parallelism::feagi_worker::spawner_implementations::std_thread::FeagiStdThreadSpawner;
use feagi_interop::node::feagi_node_flags::FeagiNodeFlags;
use feagi_interop::node::feagi_role::{FeagiRole, FeagiRoles};
use feagi_interop::transport::zenoh::zenoh_configuration::ZenohConfigurationBuilder;
use feagi_interop::transport::zenoh::zenoh_liveliness_path::FEAGI_KEY_ROOT;
use feagi_interop::transport::zenoh::zenoh_worker_builder::{ZenohStdWorker, ZenohWorkerBuilder};
use godot::prelude::*;
use std::collections::HashSet;
use std::net::{SocketAddr, ToSocketAddrs};
use std::str::FromStr;
use std::sync::{Arc, Mutex};
use std::thread;
use zenoh::sample::SampleKind;
use zenoh::Wait;

struct FeagiZenohClientLib;

#[gdextension]
unsafe impl ExtensionLibrary for FeagiZenohClientLib {}

//region State

/// Where the client is in connecting. Read by Godot as `poll_state()["state"]`
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum ClientState {
    /// Not connected, and not trying to
    Idle,
    /// Opening the session and announcing Brain Visualizer
    Connecting,
    /// On the network, but no FEAGI brain's liveliness token is seen
    WaitingForServer,
    /// On the network, and a FEAGI brain's liveliness token is seen
    Connected,
    /// Connecting failed. The error is in `poll_state()["error"]`
    Failed,
}

impl ClientState {
    fn as_str(self) -> &'static str {
        match self {
            ClientState::Idle => "idle",
            ClientState::Connecting => "connecting",
            ClientState::WaitingForServer => "waiting_for_server",
            ClientState::Connected => "connected",
            ClientState::Failed => "failed",
        }
    }
}

/// Shared between Godot's thread, the connecting thread, and zenoh's callbacks
#[derive(Default)]
struct SharedState {
    connecting: bool,
    error: Option<String>,
    /// Set once the connecting thread is done, and taken by `disconnect_zenoh`
    connection: Option<ZenohConnection>,
    /// Liveliness keys of the FEAGI brains currently on the network
    brain_keys: HashSet<String>,
    /// Newest sample on the visualization key, older ones are dropped like the websocket does
    newest_visualization_packet: Option<Vec<u8>>,
    received_packet_count: u64,
}

impl SharedState {
    fn client_state(&self) -> ClientState {
        if self.connecting {
            ClientState::Connecting
        } else if self.error.is_some() {
            ClientState::Failed
        } else if self.connection.is_none() {
            ClientState::Idle
        } else if self.brain_keys.is_empty() {
            ClientState::WaitingForServer
        } else {
            ClientState::Connected
        }
    }
}

/// Everything kept alive while connected. Dropping it leaves the network
struct ZenohConnection {
    /// Holds the session announcing Brain Visualizer, and its liveliness token
    worker: ZenohStdWorker,
    /// Watches the network for FEAGI brains and receives the visualization stream. A session of
    /// its own, as the worker does not expose its session
    observer: zenoh::Session,
    _brain_subscriber: zenoh::pubsub::Subscriber<()>,
    _visualization_subscriber: Option<zenoh::pubsub::Subscriber<()>>,
}

impl ZenohConnection {
    /// Withdraws the token and closes both sessions. Errors are ignored, the client is leaving
    /// either way
    fn close(self) {
        let ZenohConnection { mut worker, observer, _brain_subscriber, _visualization_subscriber } = self;
        drop(_visualization_subscriber);
        drop(_brain_subscriber);
        let _ = observer.close().wait();
        let _ = block_on_thread(worker.stop());
        let _ = worker.join();
    }
}

//endregion

//region Godot Class

/// GDExtension class: a zenoh connection to a feagi-core server
#[derive(GodotClass)]
#[class(base=RefCounted)]
pub struct FeagiZenohClient {
    #[base]
    _base: Base<RefCounted>,
    shared: Arc<Mutex<SharedState>>,
}

#[godot_api]
impl IRefCounted for FeagiZenohClient {
    fn init(base: Base<RefCounted>) -> Self {
        Self { _base: base, shared: Arc::new(Mutex::new(SharedState::default())) }
    }
}

#[godot_api]
impl FeagiZenohClient {
    /// Starts connecting to the zenoh websocket server at `server_address` (`host:port`,
    /// `ws/host:port`, or `ws://host:port`) on a background thread. Watch `poll_state()` for
    /// the outcome. Samples on `visualization_key` (a zenoh key expression, empty for none) are
    /// kept for `take_visualization_packet()`. Returns false if the address is invalid, or a
    /// connection is already up or being made
    #[func]
    pub fn connect_zenoh(&self, server_address: GString, visualization_key: GString) -> bool {
        let address = match parse_server_address(&server_address.to_string()) {
            Ok(address) => address,
            Err(error) => {
                let mut shared = self.shared.lock().unwrap();
                shared.error = Some(error);
                return false;
            }
        };
        let visualization_key = visualization_key.to_string().trim().to_string();

        {
            let mut shared = self.shared.lock().unwrap();
            if shared.connecting || shared.connection.is_some() {
                return false;
            }
            shared.connecting = true;
            shared.error = None;
            shared.brain_keys.clear();
            shared.newest_visualization_packet = None;
            shared.received_packet_count = 0;
        }

        let shared = Arc::clone(&self.shared);
        let spawned = thread::Builder::new().name("bv-feagi-zenoh-connect".to_string()).spawn(move || {
            let result = open_connection(address, &visualization_key, &shared);
            let mut state = shared.lock().unwrap();
            state.connecting = false;
            match result {
                Ok(connection) => state.connection = Some(connection),
                Err(error) => state.error = Some(error),
            }
        });
        if spawned.is_err() {
            let mut shared = self.shared.lock().unwrap();
            shared.connecting = false;
            shared.error = Some("Failed to spawn the zenoh connection thread".to_string());
            return false;
        }
        true
    }

    /// Leaves the network: withdraws Brain Visualizer's token and closes the sessions. Blocks
    /// until done. A connection still being made is closed once it is made
    #[func]
    pub fn disconnect_zenoh(&self) {
        let connection = {
            let mut shared = self.shared.lock().unwrap();
            shared.error = None;
            shared.brain_keys.clear();
            shared.newest_visualization_packet = None;
            shared.connection.take()
        };
        if let Some(connection) = connection {
            connection.close();
        }
    }

    /// Returns a Dictionary with: state (String: idle, connecting, waiting_for_server,
    /// connected, failed), error (String), server_count (int), received_packet_count (int)
    #[func]
    pub fn poll_state(&self) -> VarDictionary {
        let shared = self.shared.lock().unwrap();
        vdict!(
            "state" => shared.client_state().as_str(),
            "error" => shared.error.clone().unwrap_or_default(),
            "server_count" => shared.brain_keys.len() as i64,
            "received_packet_count" => shared.received_packet_count as i64
        )
    }

    /// The newest visualization sample since the last call, or an empty array if none came
    #[func]
    pub fn take_visualization_packet(&self) -> PackedByteArray {
        let mut shared = self.shared.lock().unwrap();
        match shared.newest_visualization_packet.take() {
            Some(bytes) => PackedByteArray::from(bytes.as_slice()),
            None => PackedByteArray::new(),
        }
    }
}

impl Drop for FeagiZenohClient {
    fn drop(&mut self) {
        self.disconnect_zenoh();
    }
}

//endregion

//region Connecting

/// Accepts `host:port`, `ws/host:port` and `ws://host:port`, resolving host names
fn parse_server_address(text: &str) -> Result<SocketAddr, String> {
    let text = text.trim();
    let host_port = text
        .strip_prefix("ws://")
        .or_else(|| text.strip_prefix("ws/"))
        .unwrap_or(text)
        .trim_end_matches('/');
    if host_port.is_empty() {
        return Err("zenoh server address is empty".to_string());
    }
    host_port
        .to_socket_addrs()
        .map_err(|error| format!("zenoh server address '{text}' is invalid: {error}"))?
        .next()
        .ok_or_else(|| format!("zenoh server address '{text}' did not resolve"))
}

/// Brain Visualizer shows neural activity and edits genomes
fn brain_visualizer_flags() -> FeagiNodeFlags {
    let mut roles = FeagiRoles::new();
    roles.set_role(FeagiRole::FeagiViewerNeuronVisualizer, true);
    roles.set_role(FeagiRole::FeagiViewerEditor, true);
    let mut flags = FeagiNodeFlags::new();
    flags.set_roles(roles);
    flags
}

/// Joins the network through the worker, then opens the observer session watching for FEAGI
/// brains and, if given, the visualization key
fn open_connection(address: SocketAddr, visualization_key: &str, shared: &Arc<Mutex<SharedState>>) -> Result<ZenohConnection, String> {
    let mut configuration = ZenohConfigurationBuilder::new();
    configuration.set_ws_client_target(address);
    let configuration = configuration.build().map_err(|error| format!("zenoh configuration: {error}"))?;
    let (worker, ()) = ZenohWorkerBuilder::new(configuration, brain_visualizer_flags())
        .build_worker(&FeagiStdThreadSpawner, ())
        .map_err(|error| format!("zenoh worker: {error}"))?;

    match open_observer(address, visualization_key, shared) {
        Ok((observer, brain_subscriber, visualization_subscriber)) => Ok(ZenohConnection {
            worker,
            observer,
            _brain_subscriber: brain_subscriber,
            _visualization_subscriber: visualization_subscriber,
        }),
        Err(error) => {
            let mut worker = worker;
            let _ = block_on_thread(worker.stop());
            let _ = worker.join();
            Err(error)
        }
    }
}

type Observer = (zenoh::Session, zenoh::pubsub::Subscriber<()>, Option<zenoh::pubsub::Subscriber<()>>);

fn open_observer(address: SocketAddr, visualization_key: &str, shared: &Arc<Mutex<SharedState>>) -> Result<Observer, String> {
    // Matches what the worker connects with: a client of the server's websocket, no scouting
    let mut config = zenoh::Config::default();
    let settings = [
        ("mode", "\"client\"".to_string()),
        ("connect/endpoints", format!("[\"ws/{address}\"]")),
        ("scouting/multicast/enabled", "false".to_string()),
    ];
    for (key, value) in settings {
        config.insert_json5(key, &value).map_err(|error| format!("observer configuration {key}: {error}"))?;
    }
    let observer = zenoh::open(config).wait().map_err(|error| format!("observer session: {error}"))?;

    // Every node's token, with history so brains already on the network are seen too
    let brain_shared = Arc::clone(shared);
    let brain_subscriber = observer
        .liveliness()
        .declare_subscriber(format!("{FEAGI_KEY_ROOT}/**"))
        .history(true)
        .callback(move |sample| {
            let key = sample.key_expr().as_str();
            if !is_brain_liveliness_key(key) {
                return;
            }
            let mut state = brain_shared.lock().unwrap();
            match sample.kind() {
                SampleKind::Put => state.brain_keys.insert(key.to_string()),
                SampleKind::Delete => state.brain_keys.remove(key),
            };
        })
        .wait()
        .map_err(|error| format!("liveliness subscriber: {error}"))?;

    let visualization_subscriber = if visualization_key.is_empty() {
        None
    } else {
        let packet_shared = Arc::clone(shared);
        let subscriber = observer
            .declare_subscriber(visualization_key.to_string())
            .callback(move |sample| {
                let bytes = sample.payload().to_bytes().into_owned();
                let mut state = packet_shared.lock().unwrap();
                state.newest_visualization_packet = Some(bytes);
                state.received_packet_count += 1;
            })
            .wait()
            .map_err(|error| format!("visualization subscriber on '{visualization_key}': {error}"))?;
        Some(subscriber)
    };

    Ok((observer, brain_subscriber, visualization_subscriber))
}

/// Whether `key` is the liveliness key (`feagi/<node id>/<flags>`) of a node with a FEAGI brain
/// role. Brain Visualizer's own token, and any other viewer or embodiment, is not
fn is_brain_liveliness_key(key: &str) -> bool {
    let mut segments = key.split('/');
    let (Some(root), Some(_node_id), Some(flags), None) = (segments.next(), segments.next(), segments.next(), segments.next()) else {
        return false;
    };
    if root != FEAGI_KEY_ROOT {
        return false;
    }
    FeagiNodeFlags::from_str(flags).is_ok_and(|flags| flags.get_roles().is_feagi_brain())
}

//endregion

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn brain_liveliness_keys_are_told_apart() {
        let mut roles = FeagiRoles::new();
        roles.set_role(FeagiRole::FeagiBrainDesignerMode, true);
        let mut brain_flags = FeagiNodeFlags::new();
        brain_flags.set_roles(roles);

        assert!(is_brain_liveliness_key(&format!("feagi/AAAAAAAAAAA=/{}", brain_flags.to_base64())));
        assert!(!is_brain_liveliness_key(&format!("feagi/AAAAAAAAAAA=/{}", brain_visualizer_flags().to_base64())));
        assert!(!is_brain_liveliness_key("feagi/AAAAAAAAAAA="));
        assert!(!is_brain_liveliness_key(&format!("other/AAAAAAAAAAA=/{}", brain_flags.to_base64())));
    }

    #[test]
    fn server_addresses_parse() {
        let expected: SocketAddr = "127.0.0.1:7446".parse().unwrap();
        for text in ["127.0.0.1:7446", "ws/127.0.0.1:7446", "ws://127.0.0.1:7446/", " 127.0.0.1:7446 "] {
            assert_eq!(parse_server_address(text), Ok(expected), "{text}");
        }
        assert!(parse_server_address("").is_err());
        assert!(parse_server_address("ws://").is_err());
    }

    /// Manual: connects to a running designer brain server (feagi-core
    /// `cargo run --example designer_brain_server`) and prints the state as it changes.
    /// Stop the server partway through to see its token go away.
    ///
    /// Run with: `cargo test connects_to_brain_server -- --ignored --nocapture`
    #[test]
    #[ignore = "manual: needs a running brain server on 127.0.0.1:7446"]
    fn connects_to_brain_server() {
        let shared = Arc::new(Mutex::new(SharedState::default()));
        let address = parse_server_address("127.0.0.1:7446").unwrap();
        let connection = open_connection(address, "", &shared).expect("connects to the brain server");
        let mut last = None;
        let started = std::time::Instant::now();
        while started.elapsed() < std::time::Duration::from_secs(10) {
            let state = {
                let mut shared = shared.lock().unwrap();
                shared.connection = None;
                (shared.brain_keys.len(), shared.brain_keys.iter().next().cloned())
            };
            if last.as_ref() != Some(&state) {
                println!("{:.1}s: {} brain(s) seen {:?}", started.elapsed().as_secs_f32(), state.0, state.1);
                last = Some(state);
            }
            thread::sleep(std::time::Duration::from_millis(100));
        }
        connection.close();
    }
}
