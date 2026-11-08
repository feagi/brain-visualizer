//! Engine-independent FEAGI registration plus the heartbeat session that follows it.
//!
//! The registration worker thread registers over the command/control WebSocket, reports the
//! result to the caller, then keeps the registered `CommandControlAgent` and runs the heartbeat
//! loop on the same thread (the agent holds non-`Send` transport objects, so it never leaves the
//! thread that created it). The Godot-facing class in `lib.rs` is a thin wrapper over this module.

use crate::heartbeat::{
    run_heartbeat_loop, HeartbeatConfig, HeartbeatSession, HeartbeatShared, LinkEvent, SessionLink,
};
use base64::Engine;
use feagi_agent::clients::{AgentRegistrationStatus, CommandControlAgent};
use feagi_agent::command_and_control::agent_registration_message::AgentRegistrationMessage;
use feagi_agent::command_and_control::FeagiMessage;
use feagi_agent::{AgentCapabilities, AgentDescriptor, AuthToken};
use feagi_io::protocol_implementations::websocket::websocket_std::FeagiWebSocketClientRequesterProperties;
use feagi_io::traits_and_enums::shared::TransportProtocolEndpoint;
use std::sync::mpsc::{self, RecvTimeoutError};
use std::sync::Arc;
use std::thread;
use std::time::{Duration, Instant};

/// Registration result handed from the worker thread: (visualization ws url, agent id base64).
type RegistrationResult = Result<(String, String), String>;

/// Poll budget of the registration handshake inside the worker.
pub const REGISTRATION_POLL_TIMEOUT: Duration = Duration::from_secs(30);
/// Wall-clock budget the caller waits for the worker's registration result.
pub const REGISTRATION_WALL_TIMEOUT: Duration = Duration::from_secs(35);

/// A successful registration and the heartbeat session keeping it alive.
pub struct RegisteredSession {
    /// Visualization endpoint FEAGI assigned to this agent.
    pub visualization_ws_url: String,
    /// Session agent ID, base64 encoded.
    pub agent_id_b64: String,
    /// Owner handle of the heartbeat worker.
    pub heartbeat: HeartbeatSession,
}

/// [`SessionLink`] over the feagi-agent command/control agent.
struct AgentLink {
    agent: CommandControlAgent,
}

impl SessionLink for AgentLink {
    fn poll(&mut self) -> Result<LinkEvent, String> {
        match self.agent.poll_for_messages() {
            Err(e) => Err(e.to_string()),
            Ok((_, None)) => Ok(LinkEvent::Idle),
            Ok((_, Some(FeagiMessage::HeartBeat))) => Ok(LinkEvent::HeartbeatAck),
            Ok((
                _,
                Some(FeagiMessage::AgentRegistration(
                    AgentRegistrationMessage::ServerRespondsDeregistration(_),
                )),
            )) => Ok(LinkEvent::Deregistered),
            Ok((_, Some(_))) => Ok(LinkEvent::Other),
        }
    }

    fn send_heartbeat(&mut self) -> Result<(), String> {
        self.agent.send_heartbeat().map_err(|e| e.to_string())
    }

    fn send_deregistration(&mut self) -> Result<(), String> {
        self.agent
            .request_deregistration(None)
            .map_err(|e| e.to_string())
    }

    fn is_registered(&self) -> bool {
        matches!(
            self.agent.registration_status(),
            AgentRegistrationStatus::Registered(..)
        )
    }

    fn disconnect(&mut self) {
        // Best effort: the socket may already be closed by a deregistration or an error.
        let _ = self.agent.request_disconnect();
    }
}

/// Register with FEAGI and start the heartbeat worker.
///
/// `url`, `agent_b64` and `token_b64` must be non-empty. Returns once registration completed (or
/// failed, or the wall timeout passed); on success the worker keeps running until the returned
/// [`HeartbeatSession`] is stopped or dropped.
pub fn register_with_heartbeat(
    url: &str,
    agent_b64: &str,
    token_b64: &str,
    config: HeartbeatConfig,
) -> Result<RegisteredSession, String> {
    if url.is_empty() {
        return Err("registration_ws_url is empty".to_string());
    }

    let shared = Arc::new(HeartbeatShared::new());
    let (result_tx, result_rx) = mpsc::channel::<RegistrationResult>();
    let url_for_worker = url.to_string();
    let agent_b64_for_worker = agent_b64.to_string();
    let token_b64_for_worker = token_b64.to_string();
    let shared_for_worker = Arc::clone(&shared);

    let worker = thread::Builder::new()
        .name("bv-feagi-registration".to_string())
        .spawn(move || {
            registration_worker(
                &url_for_worker,
                &agent_b64_for_worker,
                &token_b64_for_worker,
                &config,
                &shared_for_worker,
                &result_tx,
            );
        })
        .map_err(|e| format!("Failed to spawn registration worker: {e}"))?;

    match result_rx.recv_timeout(REGISTRATION_WALL_TIMEOUT) {
        Ok(Ok((visualization_ws_url, agent_id_b64))) => Ok(RegisteredSession {
            visualization_ws_url,
            heartbeat: HeartbeatSession::new(shared, worker, config, agent_id_b64.clone()),
            agent_id_b64,
        }),
        Ok(Err(error)) => {
            // The worker returns right after reporting a failure, so this join is immediate.
            let _ = worker.join();
            Err(error)
        }
        Err(RecvTimeoutError::Timeout) => {
            // Tell the worker to give up; it exits at its next pass and is detached.
            shared.request_stop();
            Err(format!(
                "Registration timed out after {}s",
                REGISTRATION_WALL_TIMEOUT.as_secs()
            ))
        }
        Err(RecvTimeoutError::Disconnected) => {
            let _ = worker.join();
            Err("Registration worker ended without a result".to_string())
        }
    }
}

/// Worker thread body: register, report, then heartbeat until stopped or dead.
fn registration_worker(
    url: &str,
    agent_b64: &str,
    token_b64: &str,
    config: &HeartbeatConfig,
    shared: &HeartbeatShared,
    result_tx: &mpsc::Sender<RegistrationResult>,
) {
    let (mut link, visualization_ws_url, agent_id_b64) =
        match perform_registration_blocking(url, agent_b64, token_b64, shared) {
            Ok(registered) => registered,
            Err(error) => {
                let _ = result_tx.send(Err(error));
                return;
            }
        };
    shared.mark_alive();
    if result_tx
        .send(Ok((visualization_ws_url, agent_id_b64)))
        .is_err()
    {
        // The caller stopped waiting; nobody owns this session.
        link.disconnect();
        shared.mark_dead("registration result was not collected");
        return;
    }
    run_heartbeat_loop(&mut link, config, shared);
}

/// Connect, register and wait for the registration response. Aborts when `shared` carries a stop.
fn perform_registration_blocking(
    url: &str,
    agent_b64: &str,
    token_b64: &str,
    shared: &HeartbeatShared,
) -> Result<(AgentLink, String, String), String> {
    let agent_descriptor = decode_agent_descriptor(agent_b64)?;
    let auth_token = decode_auth_token(token_b64)?;

    let requester_props = FeagiWebSocketClientRequesterProperties::new(url)
        .map_err(|e| format!("WebSocket requester: {}", e))?;
    let mut registration_agent = CommandControlAgent::new(Box::new(requester_props));

    registration_agent
        .request_connect()
        .map_err(|e| format!("Connect: {}", e))?;
    registration_agent
        .request_registration(
            agent_descriptor,
            auth_token,
            vec![AgentCapabilities::ReceiveNeuronVisualizations],
        )
        .map_err(|e| format!("Registration request: {}", e))?;

    let start = Instant::now();
    while start.elapsed() < REGISTRATION_POLL_TIMEOUT {
        if shared.stop_requested() {
            return Err("Registration cancelled".to_string());
        }
        registration_agent
            .poll_for_messages()
            .map_err(|e| format!("Poll: {}", e))?;
        if let AgentRegistrationStatus::Registered(agent_id, endpoints) =
            registration_agent.registration_status()
        {
            let viz_url = endpoints
                .get(&AgentCapabilities::ReceiveNeuronVisualizations)
                .map(endpoint_to_string)
                .ok_or_else(|| {
                    "Registration succeeded but missing ReceiveNeuronVisualizations endpoint"
                        .to_string()
                })?;
            let agent_id_b64 = base64::engine::general_purpose::STANDARD.encode(agent_id.bytes());
            return Ok((
                AgentLink {
                    agent: registration_agent,
                },
                viz_url,
                agent_id_b64,
            ));
        }
        thread::sleep(Duration::from_millis(2));
    }

    Err("Registration timeout".to_string())
}

fn endpoint_to_string(endpoint: &TransportProtocolEndpoint) -> String {
    match endpoint {
        TransportProtocolEndpoint::WebSocket(url) => url.as_str().to_string(),
        TransportProtocolEndpoint::Zmq(url) => url.as_str().to_string(),
    }
}

fn decode_agent_descriptor(b64: &str) -> Result<AgentDescriptor, String> {
    if b64.trim().is_empty() {
        return Err("agent_descriptor: empty value is not allowed".to_string());
    }

    let decoded = base64::engine::general_purpose::STANDARD
        .decode(b64)
        .map_err(|e| format!("agent_descriptor: invalid base64: {}", e))?;

    // Single format: instance_id(4) + manufacturer(20) + agent_name(20) + version(4) = 48 bytes
    let (manufacturer, agent_name, agent_version) = if decoded.len() == 48 {
        let manufacturer = String::from_utf8_lossy(&decoded[4..24])
            .trim_end_matches('\0')
            .to_string();
        let agent_name = String::from_utf8_lossy(&decoded[24..44])
            .trim_end_matches('\0')
            .to_string();
        let agent_version =
            u32::from_le_bytes([decoded[44], decoded[45], decoded[46], decoded[47]]);
        (manufacturer, agent_name, agent_version)
    } else {
        return Err(format!(
            "agent_descriptor: expected 48-byte AgentDescriptor, got {} bytes",
            decoded.len()
        ));
    };

    AgentDescriptor::new(&manufacturer, &agent_name, agent_version)
        .map_err(|e| format!("agent_descriptor: {}", e))
}

fn decode_auth_token(b64: &str) -> Result<AuthToken, String> {
    if b64.trim().is_empty() {
        return Err("auth_token: empty value is not allowed".to_string());
    }
    AuthToken::from_base64(b64).ok_or_else(|| "auth_token: must be base64 of 32 bytes".to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn config() -> HeartbeatConfig {
        HeartbeatConfig::new(1.0, 3).expect("valid config")
    }

    #[test]
    fn empty_url_is_rejected_before_any_thread_starts() {
        let result = register_with_heartbeat("", "a", "t", config());
        assert_eq!(
            result.err().as_deref(),
            Some("registration_ws_url is empty")
        );
    }

    #[test]
    fn empty_descriptor_and_token_are_rejected() {
        assert!(decode_agent_descriptor("  ").is_err());
        assert!(decode_auth_token("").is_err());
    }

    #[test]
    fn descriptor_with_wrong_length_is_rejected() {
        let short = base64::engine::general_purpose::STANDARD.encode([0u8; 10]);
        let err = decode_agent_descriptor(&short).err().unwrap_or_default();
        assert!(err.contains("48-byte"), "{err}");
    }

    #[test]
    fn invalid_registration_inputs_report_an_error() {
        // Fails inside the worker (descriptor or endpoint validation), before any network use.
        let descriptor = base64::engine::general_purpose::STANDARD.encode([0u8; 48]);
        let token = base64::engine::general_purpose::STANDARD.encode([0u8; 32]);
        let result = register_with_heartbeat("not-a-websocket-url", &descriptor, &token, config());
        assert!(result.is_err());
    }
}
