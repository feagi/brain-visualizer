extends Node
class_name FEAGINetworking
## Handles All Networking to and from FEAGI




var http_API: FEAGIHTTPAPI = null # Responsible for HTTP requests, this var will be null until activate_http_API is called at least once
var websocket_API: FEAGIWebSocketAPI = null

func _init():
	set_process(false) # No point pingin websocket before we connected

# Used to validate if a potential connection to FEAGI would be viable. Activates [FEAGIHTTPAPI] to do a healthcheck to verify
func check_connection_to_FEAGI(feagi_endpoint_details: FeagiEndpointDetails):
	activate_http_API(feagi_endpoint_details.get_api_URL(), feagi_endpoint_details.header)
	http_API.call_list.GET_healthCheck_FEAGI_VALIDATION()

func activate_http_API(FEAGI_API_address: StringName, headers: PackedStringArray) -> void:
	if http_API == null:
		http_API = FEAGIHTTPAPI.new()
		http_API.name = "FEAGIHTTPAPI"
		add_child(http_API)
	http_API.setup(FEAGI_API_address, headers)

func activate_websocket_APT(FEAGI_websocket_address: StringName) -> void:
	if websocket_API == null:
		websocket_API = FEAGIWebSocketAPI.new()
		websocket_API.name = "FEAGIWebSocketAPI"
		add_child(websocket_API)
	websocket_API.setup(FEAGI_websocket_address)
