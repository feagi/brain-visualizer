//! FEAGI Agent Client GDExtension
//!
//! Exposes feagi-agent SDK registration to Godot. Use this for standard FEAGI
//! registration and session_id handling (required for FeagiByteContainer flows).

use godot::prelude::*;
use feagi_agent::clients::RegistrationAgent;
use feagi_agent::registration::{
    AgentCapabilities, AgentDescriptor, AuthToken, RegistrationRequest,
};
use base64::Engine;
use feagi_io::core::protocol_implementations::ProtocolImplementation;
use feagi_io::core::protocol_implementations::websocket::FeagiWebSocketClientRequesterProperties;
use feagi_io::core::traits_and_enums::client::FeagiClientRequesterProperties;

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
    /// Returns a Dictionary with: success (bool), visualization_ws_url (String), session_id_b64 (String), error (String).
    /// Session ID must be used with FeagiByteContainer for visualization and sensory data.
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
        let mut registration_agent = RegistrationAgent::new(requester_props.as_boxed_client_requester());

        if let Err(e) = registration_agent.connect() {
            let _ = registration_agent.disconnect();
            return vdict!("success": false, "error": format!("Connect: {}", e));
        }

        let request = RegistrationRequest::new(
            agent_descriptor,
            auth_token,
            vec![AgentCapabilities::ReceiveNeuronVisualizations],
            ProtocolImplementation::WebSocket,
        );

        let result = registration_agent.try_register(request);
        let _ = registration_agent.disconnect();

        match result {
            Ok((session_id, endpoints)) => {
                let viz_url = endpoints
                    .get(&AgentCapabilities::ReceiveNeuronVisualizations)
                    .cloned()
                    .unwrap_or_default();
                let session_id_b64 = base64::engine::general_purpose::STANDARD.encode(session_id.bytes());
                vdict!(
                    "success": true,
                    "visualization_ws_url": viz_url,
                    "session_id_b64": session_id_b64,
                    "error": ""
                )
            }
            Err(e) => vdict!(
                "success": false,
                "visualization_ws_url": "",
                "session_id_b64": "",
                "error": format!("{}", e)
            ),
        }
    }

    /// Extract session ID bytes from a FeagiByteContainer buffer (first bytes after header).
    /// Returns PackedByteArray of 8 bytes or empty if buffer is too short.
    /// Used to validate incoming visualization data matches our registered session.
    #[func]
    pub fn get_session_id_from_byte_container(&self, buffer: PackedByteArray) -> PackedByteArray {
        use feagi_serialization::FeagiByteContainer;
        let bytes: Vec<u8> = buffer.to_vec();
        if bytes.len() < FeagiByteContainer::GLOBAL_BYTE_HEADER_BYTE_COUNT + FeagiByteContainer::SESSION_ID_BYTE_COUNT {
            return PackedByteArray::new();
        }
        let offset = FeagiByteContainer::GLOBAL_BYTE_HEADER_BYTE_COUNT;
        let end = offset + FeagiByteContainer::SESSION_ID_BYTE_COUNT;
        PackedByteArray::from(&bytes[offset..end])
    }
}

impl FeagiAgentClient {
    fn decode_agent_descriptor(b64: &str) -> Result<AgentDescriptor, String> {
        let raw = if b64.trim().is_empty() {
            Self::default_agent_descriptor_b64()
        } else {
            b64.to_string()
        };
        AgentDescriptor::try_from_base64(&raw).map_err(|e| format!("agent_descriptor: {}", e))
    }

    fn decode_auth_token(b64: &str) -> Result<AuthToken, String> {
        let raw = if b64.trim().is_empty() {
            base64::engine::general_purpose::STANDARD.encode([0u8; 32])
        } else {
            b64.to_string()
        };
        AuthToken::from_base64(&raw).ok_or_else(|| "auth_token: must be base64 of 32 bytes".to_string())
    }

    fn default_agent_descriptor_b64() -> String {
        // 72 bytes: 4 (instance_id LE) + 32 (manufacturer) + 32 (agent_name) + 4 (version LE)
        let mut bytes = [0u8; 72];
        bytes[0..4].copy_from_slice(&1u32.to_le_bytes());
        bytes[4..14].copy_from_slice(b"neuraville");
        bytes[36..52].copy_from_slice(b"brain-visualizer");
        bytes[68..72].copy_from_slice(&1u32.to_le_bytes());
        base64::engine::general_purpose::STANDARD.encode(&bytes[..])
    }
}
