extends Node
class_name FEAGINetworking
## Handles All Networking to and from FEAGI


var http_API: FEAGIHTTPAPI = null
var websocket_API: FEAGIWebSocketAPI = null

var _general_FEAGI_settings: FeagiGeneralSettings

func _init(feagi_settings: FeagiGeneralSettings):
	_general_FEAGI_settings = feagi_settings
	
	http_API = FEAGIHTTPAPI.new()
	http_API.name = "FEAGIHTTPAPI"
	add_child(http_API)

	websocket_API = FEAGIWebSocketAPI.new()
	websocket_API.name = "FEAGIWebSocketAPI"
	websocket_API.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(websocket_API)

# Used to validate if a potential connection to FEAGI would be viable. Activates [FEAGIHTTPAPI] to do a healthcheck to verify
func check_connection_to_FEAGI(feagi_endpoint_details: FeagiEndpointDetails):
	activate_http_API(feagi_endpoint_details.get_api_URL(), feagi_endpoint_details.header)
	http_API.call_list.GET_healthCheck_FEAGI_VALIDATION()

func activate_http_API(FEAGI_API_address: StringName, headers: PackedStringArray) -> void:
	http_API.setup(FEAGI_API_address, headers, _general_FEAGI_settings)

func activate_websocket_APT(FEAGI_websocket_address: StringName) -> void:
	websocket_API.setup(FEAGI_websocket_address)
