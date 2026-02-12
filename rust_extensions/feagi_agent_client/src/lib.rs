//! FEAGI Agent Client GDExtension
//!
//! Exposes feagi-agent SDK registration to Godot. Use this for standard FEAGI
//! registration and session_id handling (required for FeagiByteContainer flows).

use godot::prelude::*;
use feagi_agent::clients::{AgentRegistrationStatus, CommandControlSubAgent};
use feagi_agent::{AgentCapabilities, AgentDescriptor, AuthToken};
use base64::Engine;
use feagi_io::protocol_implementations::websocket::websocket_std::FeagiWebSocketClientRequesterProperties;
use feagi_io::traits_and_enums::shared::TransportProtocolEndpoint;

struct FeagiAgentClientLib;

#[gdextension]
unsafe impl ExtensionLibrary for FeagiAgentClientLib {}

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
        let url = registration_ws_url.to_string();
        let agent_b64 = agent_descriptor_b64.to_string().trim().to_string();
        let token_b64 = auth_token_b64.to_string().trim().to_string();

        if url.is_empty() {
            return vdict!("success": false, "error": "registration_ws_url is empty");
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
            Err(e) => return vdict!("success": false, "error": format!("WebSocket requester: {}", e)),
        };
        let mut registration_agent = CommandControlSubAgent::new(Box::new(requester_props));

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
                        let agent_id_b64 = base64::engine::general_purpose::STANDARD.encode(agent_id.bytes());
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

    /// Extract agent ID bytes from a FeagiByteContainer buffer (first bytes after header).
    /// Returns PackedByteArray of 8 bytes or empty if buffer is too short.
    /// Used to validate incoming visualization data matches our registered session.
    #[func]
    pub fn get_session_id_from_byte_container(&self, buffer: PackedByteArray) -> PackedByteArray {
        use feagi_serialization::FeagiByteContainer;
        let bytes: Vec<u8> = buffer.to_vec();
        if bytes.len() < FeagiByteContainer::GLOBAL_BYTE_HEADER_BYTE_COUNT + FeagiByteContainer::AGENT_ID_BYTE_COUNT {
            return PackedByteArray::new();
        }
        let offset = FeagiByteContainer::GLOBAL_BYTE_HEADER_BYTE_COUNT;
        let end = offset + FeagiByteContainer::AGENT_ID_BYTE_COUNT;
        PackedByteArray::from(&bytes[offset..end])
    }
}

impl FeagiAgentClient {
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
        AuthToken::from_base64(&raw).ok_or_else(|| "auth_token: must be base64 of 32 bytes".to_string())
    }

}
