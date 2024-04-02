extends Node
class_name FEAGINetworking
## Handles All Networking to and from FEAGI
#NOTE: Keep this a [Node] so we have access to the _proccess function

enum FEAGI_CONNECTION_CHECK_RESULTS {
	NO_RESPONSE,
	UNKNOWN_RESPONSE,
	NO_GENOME,
	HEALTHY
}

enum WEBSOCKET_HEALTH {
	NO_CONNECTION,
	CONNECTED
}

signal connection_check_results(results: FEAGI_CONNECTION_CHECK_RESULTS)
signal websocket_health_changed(health: WEBSOCKET_HEALTH)

var websocket_health: WEBSOCKET_HEALTH = WEBSOCKET_HEALTH.NO_CONNECTION

var http_API: FEAGIHTTPAPI = null # Responsible for HTTP requests, this var will be null until _activate_http_API is called at least once

func _init():
	set_process(false) # No point pingin websocket before we connected

# Used to validate if a potential connection to FEAGI would be viable. Activates [FEAGIHTTPAPI] to do a healthcheck to verify
func check_connection_to_FEAGI(feagi_endpoint_details: FeagiEndpointDetails):
	_activate_http_API(feagi_endpoint_details.get_api_URL(), feagi_endpoint_details.header)
	http_API.call_list.GET_healthCheck_FEAGI_VALIDATION()

func _activate_http_API(FEAGI_API_address: StringName, headers: PackedStringArray) -> void:
	http_API = $FEAGIHTTPAPI
	http_API.setup(FEAGI_API_address, headers)
