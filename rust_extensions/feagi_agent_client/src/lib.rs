//! FEAGI Agent Client GDExtension
//!
//! Exposes feagi-agent SDK registration to Godot. Use this for standard FEAGI
//! registration and session_id handling (required for FeagiByteContainer flows).

use base64::Engine;
use feagi_agent::clients::{AgentRegistrationStatus, CommandControlAgent};
use feagi_agent::command_and_control::agent_registration_message::{
    AgentRegistrationMessage, DeregistrationRequest, DeregistrationResponse,
};
use feagi_agent::command_and_control::FeagiMessage;
use feagi_agent::{AgentCapabilities, AgentDescriptor, AuthToken};
use feagi_io::protocol_implementations::websocket::websocket_std::FeagiWebSocketClientRequesterProperties;
use feagi_io::traits_and_enums::client::FeagiClientRequesterProperties;
use feagi_io::traits_and_enums::shared::FeagiEndpointState;
use feagi_io::traits_and_enums::shared::TransportProtocolEndpoint;
use feagi_io::AgentID;
use feagi_serialization::FeagiByteContainer;
use godot::prelude::*;
use std::collections::HashMap;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex, OnceLock};
use std::thread;
use std::time::{Duration, Instant};

struct FeagiAgentClientLib;

#[gdextension]
unsafe impl ExtensionLibrary for FeagiAgentClientLib {}

type HeartbeatStopFlag = Arc<AtomicBool>;
type HeartbeatRegistry = HashMap<String, HeartbeatStopFlag>;

fn heartbeat_registry() -> &'static Mutex<HeartbeatRegistry> {
    static REGISTRY: OnceLock<Mutex<HeartbeatRegistry>> = OnceLock::new();
    REGISTRY.get_or_init(|| Mutex::new(HashMap::new()))
}

/// GDExtension class: FEAGI agent registration via feagi-agent SDK.
#[derive(GodotClass)]
#[class(base=RefCounted)]
pub struct FeagiAgentClient {
    #[base]
    _base: Base<RefCounted>,
}

#[godot_api]
impl IRefCounted for FeagiAgentClient {
    fn init(base: Base<RefCounted>) -> Self {
        Self { _base: base }
    }
}

#[godot_api]
impl FeagiAgentClient {
    /// Register with FEAGI via the standard WebSocket registration endpoint using the feagi-agent SDK.
    /// Returns a Dictionary with: success (bool), visualization_ws_url (String), agent_id_b64 (String), error (String).
    /// Agent ID must be used with FeagiByteContainer for visualization and sensory data.
    #[func]
    pub fn register_via_websocket(
        &self,
        registration_ws_url: GString,
        agent_descriptor_b64: GString,
        auth_token_b64: GString,
    ) -> VarDictionary {
        self.register_via_websocket_internal(
            registration_ws_url,
            agent_descriptor_b64,
            auth_token_b64,
            5.0,
        )
    }

    /// Register with FEAGI via WebSocket and configure heartbeat interval.
    ///
    /// This method is preferred when the caller wants explicit heartbeat timing.
    #[func]
    pub fn register_via_websocket_with_heartbeat(
        &self,
        registration_ws_url: GString,
        agent_descriptor_b64: GString,
        auth_token_b64: GString,
        heartbeat_interval_s: f64,
    ) -> VarDictionary {
        self.register_via_websocket_internal(
            registration_ws_url,
            agent_descriptor_b64,
            auth_token_b64,
            heartbeat_interval_s,
        )
    }

    fn register_via_websocket_internal(
        &self,
        registration_ws_url: GString,
        agent_descriptor_b64: GString,
        auth_token_b64: GString,
        heartbeat_interval_s: f64,
    ) -> VarDictionary {
        let url = registration_ws_url.to_string();
        let agent_b64 = agent_descriptor_b64.to_string().trim().to_string();
        let token_b64 = auth_token_b64.to_string().trim().to_string();

        if url.is_empty() {
            return vdict!("success": false, "error": "registration_ws_url is empty");
        }
        if heartbeat_interval_s <= 0.0 {
            return vdict!(
                "success": false,
                "error": "heartbeat_interval_s must be > 0"
            );
        }

        let agent_descriptor = match Self::decode_agent_descriptor(&agent_b64) {
            Ok(ad) => ad,
            Err(e) => return vdict!("success": false, "error": e),
        };

        let auth_token = match Self::decode_auth_token(&token_b64) {
            Ok(t) => t,
            Err(e) => return vdict!("success": false, "error": e),
        };

        let requester_props = match FeagiWebSocketClientRequesterProperties::new(&url) {
            Ok(p) => p,
            Err(e) => {
                return vdict!("success": false, "error": format!("WebSocket requester: {}", e))
            }
        };
        let mut registration_agent = CommandControlAgent::new(Box::new(requester_props));

        if let Err(e) = registration_agent.request_connect() {
            return vdict!("success": false, "error": format!("Connect: {}", e));
        }

        if let Err(e) = registration_agent.request_registration(
            agent_descriptor,
            auth_token,
            vec![AgentCapabilities::ReceiveNeuronVisualizations],
        ) {
            return vdict!("success": false, "error": format!("Registration request: {}", e));
        }

        // Poll registration response (blocking loop with bounded timeout)
        let start = std::time::Instant::now();
        let timeout = std::time::Duration::from_secs(30);
        loop {
            match registration_agent.poll_for_messages() {
                Ok(_) => {
                    if let AgentRegistrationStatus::Registered(agent_id, endpoints) =
                        registration_agent.registration_status()
                    {
                        let viz_url = endpoints
                            .get(&AgentCapabilities::ReceiveNeuronVisualizations)
                            .map(Self::endpoint_to_string)
                            .unwrap_or_default();
                        let agent_id_b64 =
                            base64::engine::general_purpose::STANDARD.encode(agent_id.bytes());
                        Self::start_or_replace_background_heartbeat(
                            agent_id_b64.clone(),
                            url.clone(),
                            Duration::from_secs_f64(heartbeat_interval_s),
                        );
                        return vdict!(
                            "success": true,
                            "visualization_ws_url": viz_url,
                            "agent_id_b64": agent_id_b64,
                            "error": ""
                        );
                    }
                }
                Err(e) => {
                    return vdict!(
                        "success": false,
                        "visualization_ws_url": "",
                        "agent_id_b64": "",
                        "error": format!("{}", e)
                    );
                }
            }

            if start.elapsed() >= timeout {
                return vdict!(
                    "success": false,
                    "visualization_ws_url": "",
                    "agent_id_b64": "",
                    "error": "Registration timeout"
                );
            }

            std::thread::sleep(std::time::Duration::from_millis(5));
        }
    }

    /// Stop background command/control heartbeat for a registered session.
    ///
    /// Returns success even when there is no running heartbeat for the provided
    /// session ID (idempotent stop semantics).
    #[func]
    pub fn stop_heartbeat_for_agent(&self, agent_id_b64: GString) -> bool {
        let agent_id = agent_id_b64.to_string().trim().to_string();
        if agent_id.is_empty() {
            return false;
        }
        let mut registry = heartbeat_registry()
            .lock()
            .expect("heartbeat registry mutex poisoned");
        if let Some(stop_flag) = registry.remove(&agent_id) {
            stop_flag.store(true, Ordering::Release);
        }
        true
    }

    /// Request voluntary deregistration for an existing session over WebSocket
    /// command/control transport.
    ///
    /// This allows reconnect flows to release server-side resources immediately,
    /// instead of waiting for heartbeat timeout cleanup.
    #[func]
    pub fn deregister_via_websocket(
        &self,
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
                            if let Ok(message) = FeagiMessage::try_from(&container) {
                                if let FeagiMessage::AgentRegistration(registration_message) =
                                    message
                                {
                                    if let AgentRegistrationMessage::ServerRespondsDeregistration(
                                        response,
                                    ) = registration_message
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

    /// Extract agent ID bytes from a FeagiByteContainer buffer (first bytes after header).
    /// Returns PackedByteArray of 8 bytes or empty if buffer is too short.
    /// Used to validate incoming visualization data matches our registered session.
    #[func]
    pub fn get_session_id_from_byte_container(&self, buffer: PackedByteArray) -> PackedByteArray {
        use feagi_serialization::FeagiByteContainer;
        let bytes: Vec<u8> = buffer.to_vec();
        if bytes.len()
            < FeagiByteContainer::GLOBAL_BYTE_HEADER_BYTE_COUNT
                + FeagiByteContainer::AGENT_ID_BYTE_COUNT
        {
            return PackedByteArray::new();
        }
        let offset = FeagiByteContainer::GLOBAL_BYTE_HEADER_BYTE_COUNT;
        let end = offset + FeagiByteContainer::AGENT_ID_BYTE_COUNT;
        PackedByteArray::from(&bytes[offset..end])
    }
}

impl FeagiAgentClient {
    fn heartbeat_request_timeout(heartbeat_interval: Duration) -> Duration {
        let max_timeout = Duration::from_secs(5);
        if heartbeat_interval < max_timeout {
            heartbeat_interval
        } else {
            max_timeout
        }
    }

    fn heartbeat_retry_interval(heartbeat_interval: Duration) -> Duration {
        let retry_seconds = (heartbeat_interval.as_secs_f64() / 3.0).max(1.0);
        Duration::from_secs_f64(retry_seconds)
    }

    fn start_or_replace_background_heartbeat(
        agent_id_b64: String,
        registration_ws_url: String,
        heartbeat_interval: Duration,
    ) {
        let stop_flag = Arc::new(AtomicBool::new(false));
        let mut registry = heartbeat_registry()
            .lock()
            .expect("heartbeat registry mutex poisoned");
        if let Some(previous_stop_flag) =
            registry.insert(agent_id_b64.clone(), Arc::clone(&stop_flag))
        {
            previous_stop_flag.store(true, Ordering::Release);
        }
        drop(registry);

        thread::Builder::new()
            .name("bv-feagi-heartbeat".to_string())
            .spawn(move || {
                let session_id = match AgentID::try_from_base64(&agent_id_b64) {
                    Ok(id) => id,
                    Err(_) => return,
                };
                while !stop_flag.load(Ordering::Acquire) {
                    let timeout = Self::heartbeat_request_timeout(heartbeat_interval);
                    let heartbeat_result = Self::send_single_heartbeat(
                        &registration_ws_url,
                        session_id,
                        timeout,
                    );
                    let wait_interval = if heartbeat_result.is_ok() {
                        heartbeat_interval
                    } else {
                        Self::heartbeat_retry_interval(heartbeat_interval)
                    };
                    let sleep_start = Instant::now();
                    while sleep_start.elapsed() < wait_interval {
                        if stop_flag.load(Ordering::Acquire) {
                            return;
                        }
                        thread::sleep(Duration::from_millis(50));
                    }
                }
            })
            .ok();
    }

    fn send_single_heartbeat(
        registration_ws_url: &str,
        session_id: AgentID,
        timeout: Duration,
    ) -> Result<(), String> {
        let requester_props = FeagiWebSocketClientRequesterProperties::new(registration_ws_url)
            .map_err(|e| format!("requester init failed: {}", e))?;
        let mut requester = requester_props.as_boxed_client_requester();
        requester
            .request_connect()
            .map_err(|e| format!("request_connect failed: {}", e))?;

        let connect_start = Instant::now();
        loop {
            match requester.poll().clone() {
                FeagiEndpointState::ActiveWaiting | FeagiEndpointState::ActiveHasData => break,
                FeagiEndpointState::Errored(err) => {
                    let _ = requester.confirm_error_and_close();
                    return Err(format!("requester errored: {}", err));
                }
                _ => {
                    if connect_start.elapsed() >= timeout {
                        return Err("connect timeout".to_string());
                    }
                    thread::sleep(Duration::from_millis(10));
                }
            }
        }

        let heartbeat_message = FeagiMessage::HeartBeat;
        let mut request_bytes = FeagiByteContainer::new_empty();
        heartbeat_message
            .serialize_to_byte_container(&mut request_bytes, session_id, 0)
            .map_err(|e| format!("heartbeat serialization failed: {}", e))?;
        requester
            .publish_request(request_bytes.get_byte_ref())
            .map_err(|e| format!("heartbeat publish failed: {}", e))?;

        let response_start = Instant::now();
        loop {
            match requester.poll().clone() {
                FeagiEndpointState::ActiveHasData => {
                    let _ = requester.consume_retrieved_response();
                    break;
                }
                FeagiEndpointState::Errored(err) => {
                    let _ = requester.confirm_error_and_close();
                    return Err(format!("heartbeat response errored: {}", err));
                }
                _ => {
                    if response_start.elapsed() >= timeout {
                        return Err("heartbeat response timeout".to_string());
                    }
                    thread::sleep(Duration::from_millis(10));
                }
            }
        }

        let _ = requester.request_disconnect();
        Ok(())
    }

    fn endpoint_to_string(endpoint: &TransportProtocolEndpoint) -> String {
        match endpoint {
            TransportProtocolEndpoint::WebSocket(url) => url.as_str().to_string(),
            TransportProtocolEndpoint::Zmq(url) => url.as_str().to_string(),
        }
    }

    fn decode_agent_descriptor(b64: &str) -> Result<AgentDescriptor, String> {
        if b64.trim().is_empty() {
            return AgentDescriptor::new("neuraville", "brain-visualizer", 1)
                .map_err(|e| format!("agent_descriptor: {}", e));
        }

        let decoded = base64::engine::general_purpose::STANDARD
            .decode(b64)
            .map_err(|e| format!("agent_descriptor: invalid base64: {}", e))?;

        let (manufacturer, agent_name, agent_version) = match decoded.len() {
            // New layout: instance_id(4) + manufacturer(128) + agent_name(64) + version(4) = 200
            200 => {
                let manufacturer = String::from_utf8_lossy(&decoded[4..132])
                    .trim_end_matches('\0')
                    .to_string();
                let agent_name = String::from_utf8_lossy(&decoded[132..196])
                    .trim_end_matches('\0')
                    .to_string();
                let agent_version =
                    u32::from_le_bytes([decoded[196], decoded[197], decoded[198], decoded[199]]);
                (manufacturer, agent_name, agent_version)
            }
            // Legacy layout: instance_id(4) + manufacturer(32) + agent_name(32) + version(4) = 72
            72 => {
                let manufacturer = String::from_utf8_lossy(&decoded[4..36])
                    .trim_end_matches('\0')
                    .to_string();
                let agent_name = String::from_utf8_lossy(&decoded[36..68])
                    .trim_end_matches('\0')
                    .to_string();
                let agent_version =
                    u32::from_le_bytes([decoded[68], decoded[69], decoded[70], decoded[71]]);
                (manufacturer, agent_name, agent_version)
            }
            // Very old layout: instance_id(4) + manufacturer(20) + agent_name(20) + version(4) = 48
            48 => {
                let manufacturer = String::from_utf8_lossy(&decoded[4..24])
                    .trim_end_matches('\0')
                    .to_string();
                let agent_name = String::from_utf8_lossy(&decoded[24..44])
                    .trim_end_matches('\0')
                    .to_string();
                let agent_version =
                    u32::from_le_bytes([decoded[44], decoded[45], decoded[46], decoded[47]]);
                (manufacturer, agent_name, agent_version)
            }
            size => {
                return Err(format!(
                    "agent_descriptor: unsupported descriptor encoding length {} (expected 200/72/48 bytes)",
                    size
                ));
            }
        };

        AgentDescriptor::new(&manufacturer, &agent_name, agent_version)
            .map_err(|e| format!("agent_descriptor: {}", e))
    }

    fn decode_auth_token(b64: &str) -> Result<AuthToken, String> {
        let raw = if b64.trim().is_empty() {
            base64::engine::general_purpose::STANDARD.encode([0u8; 32])
        } else {
            b64.to_string()
        };
        AuthToken::from_base64(&raw)
            .ok_or_else(|| "auth_token: must be base64 of 32 bytes".to_string())
    }
}
