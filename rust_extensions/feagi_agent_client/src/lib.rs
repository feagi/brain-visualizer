//! FEAGI Agent Client GDExtension
//!
//! Exposes feagi-agent SDK registration to Godot. Use this for standard FEAGI
//! registration and session_id handling (required for FeagiByteContainer flows).
//! After registration a background worker keeps the session alive with heartbeats
//! (see `heartbeat` and `session`); this file is the thin Godot-facing wrapper.

use feagi_agent::command_and_control::agent_registration_message::{
    AgentRegistrationMessage, DeregistrationRequest, DeregistrationResponse,
};
use feagi_agent::command_and_control::FeagiMessage;
use feagi_io::protocol_implementations::websocket::websocket_std::FeagiWebSocketClientRequesterProperties;
use feagi_io::traits_and_enums::client::FeagiClientRequesterProperties;
use feagi_io::traits_and_enums::shared::FeagiEndpointState;
use feagi_io::AgentID;
use feagi_serialization::FeagiByteContainer;
use godot::prelude::*;
use std::thread;
use std::time::{Duration, Instant};

pub mod heartbeat;
pub mod session;

use heartbeat::{HeartbeatConfig, HeartbeatSession};

struct FeagiAgentClientLib;

#[gdextension]
unsafe impl ExtensionLibrary for FeagiAgentClientLib {}

/// GDExtension class: FEAGI agent registration via feagi-agent SDK.
///
/// One instance owns at most one registered session and its heartbeat worker.
#[derive(GodotClass)]
#[class(base=RefCounted)]
pub struct FeagiAgentClient {
    #[base]
    _base: Base<RefCounted>,
    /// Heartbeat session of the last successful registration, until `stop_heartbeat`.
    session: Option<HeartbeatSession>,
}

#[godot_api]
impl IRefCounted for FeagiAgentClient {
    fn init(base: Base<RefCounted>) -> Self {
        Self {
            _base: base,
            session: None,
        }
    }
}

#[godot_api]
impl FeagiAgentClient {
    /// Register with FEAGI via the standard WebSocket registration endpoint using the feagi-agent SDK,
    /// then keep the session alive with a background heartbeat worker.
    /// `heartbeat_interval_s` and `max_missed_heartbeat_acks` must both be > 0 (they come from BV config;
    /// there are no defaults). Any previous session of this client is stopped first.
    /// Returns a Dictionary with: success (bool), visualization_ws_url (String), agent_id_b64 (String), error (String).
    /// Agent ID must be used with FeagiByteContainer for visualization and sensory data.
    #[func]
    pub fn register_via_websocket(
        &mut self,
        registration_ws_url: GString,
        agent_descriptor_b64: GString,
        auth_token_b64: GString,
        heartbeat_interval_s: f64,
        max_missed_heartbeat_acks: i64,
    ) -> VarDictionary {
        let failure = |error: String| {
            vdict!(
                "success" => false,
                "visualization_ws_url" => "",
                "agent_id_b64" => "",
                "error" => error
            )
        };

        let config = match HeartbeatConfig::new(heartbeat_interval_s, max_missed_heartbeat_acks) {
            Ok(config) => config,
            Err(error) => return failure(error),
        };

        // One session per client: release the previous worker and socket first.
        self.stop_heartbeat();

        let url = registration_ws_url.to_string();
        let agent_b64 = agent_descriptor_b64.to_string().trim().to_string();
        let token_b64 = auth_token_b64.to_string().trim().to_string();

        match session::register_with_heartbeat(&url, &agent_b64, &token_b64, config) {
            Ok(registered) => {
                self.session = Some(registered.heartbeat);
                vdict!(
                    "success" => true,
                    "visualization_ws_url" => registered.visualization_ws_url,
                    "agent_id_b64" => registered.agent_id_b64,
                    "error" => ""
                )
            }
            Err(error) => failure(error),
        }
    }

    /// Stop the heartbeat worker and drop the session socket. Safe to call more than once.
    #[func]
    pub fn stop_heartbeat(&mut self) {
        if let Some(mut session) = self.session.take() {
            session.stop();
        }
    }

    /// True while the heartbeat worker is running a live session. False after
    /// `stop_heartbeat`, after a failed heartbeat, or when FEAGI ended the session.
    #[func]
    pub fn is_heartbeat_alive(&self) -> bool {
        self.session
            .as_ref()
            .is_some_and(HeartbeatSession::is_alive)
    }

    /// Why the heartbeat session died. Empty while it is alive, after a clean stop, or when
    /// there is no session.
    #[func]
    pub fn get_heartbeat_error(&self) -> GString {
        match self.session.as_ref() {
            Some(session) => GString::from(session.error().as_str()),
            None => GString::new(),
        }
    }

    /// Request voluntary deregistration for an existing session over WebSocket
    /// command/control transport.
    ///
    /// This allows reconnect flows to release server-side resources immediately,
    /// instead of waiting for FEAGI's liveness timeout.
    #[func]
    pub fn deregister_via_websocket(
        &mut self,
        registration_ws_url: GString,
        agent_id_b64: GString,
    ) -> bool {
        let registration_url = registration_ws_url.to_string().trim().to_string();
        if registration_url.is_empty() {
            return false;
        }
        let agent_id_raw = agent_id_b64.to_string().trim().to_string();
        if agent_id_raw.is_empty() {
            return false;
        }

        // Prefer the live session socket: the heartbeat worker owns it and FEAGI treats a
        // deregistration over it as the end of that same session.
        if let Some(session) = self.session.as_mut() {
            if session.is_alive() && session.agent_id_b64() == agent_id_raw {
                return session.deregister();
            }
        }

        let session_id = match AgentID::try_from_base64(&agent_id_raw) {
            Ok(id) => id,
            Err(_) => return false,
        };

        let requester_props = match FeagiWebSocketClientRequesterProperties::new(&registration_url)
        {
            Ok(p) => p,
            Err(_) => return false,
        };
        let mut requester = requester_props.as_boxed_client_requester();
        if requester.request_connect().is_err() {
            return false;
        }

        let connect_start = Instant::now();
        while connect_start.elapsed() < Duration::from_secs(3) {
            match requester.poll().clone() {
                FeagiEndpointState::ActiveWaiting | FeagiEndpointState::ActiveHasData => break,
                FeagiEndpointState::Errored(_) => {
                    let _ = requester.confirm_error_and_close();
                    return false;
                }
                _ => thread::sleep(Duration::from_millis(10)),
            }
        }

        let dereg_message = FeagiMessage::AgentRegistration(
            AgentRegistrationMessage::ClientRequestDeregistration(DeregistrationRequest::new(None)),
        );
        let mut request_bytes = FeagiByteContainer::new_empty();
        if dereg_message
            .serialize_to_byte_container(&mut request_bytes, session_id, 0)
            .is_err()
        {
            return false;
        }
        if requester
            .publish_request(request_bytes.get_byte_ref())
            .is_err()
        {
            return false;
        }

        let response_start = Instant::now();
        while response_start.elapsed() < Duration::from_secs(3) {
            match requester.poll().clone() {
                FeagiEndpointState::ActiveHasData => {
                    if let Ok(data) = requester.consume_retrieved_response() {
                        let mut container = FeagiByteContainer::new_empty();
                        if container.try_write_data_by_copy_and_verify(data).is_ok() {
                            if let Ok(FeagiMessage::AgentRegistration(
                                AgentRegistrationMessage::ServerRespondsDeregistration(response),
                            )) = FeagiMessage::try_from(&container)
                            {
                                let _ = requester.request_disconnect();
                                return matches!(
                                    response,
                                    DeregistrationResponse::Success
                                        | DeregistrationResponse::NotRegistered
                                );
                            }
                        }
                    }
                    break;
                }
                FeagiEndpointState::Errored(_) => {
                    let _ = requester.confirm_error_and_close();
                    return false;
                }
                _ => thread::sleep(Duration::from_millis(10)),
            }
        }
        let _ = requester.request_disconnect();
        false
    }
}
