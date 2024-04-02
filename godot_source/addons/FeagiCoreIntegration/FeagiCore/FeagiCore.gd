extends Node
## Autoloaded, root of all communication adn data to / from FEAGI

#region Statics / consts

enum CONNECTION_STATE {
	DISCONNECTED,
	CONNECTING,
	CONNECTED,
	DISCONNECTING
}

enum CONNECTION_CHECK_RESULTS {
	NO_RESPONSE,
	UNKNOWN_RESPONSE,
	HEALTHY_BUT_NO_GENOME,
	HEALTHY
}

enum GENOME_AVAILABILITY {
	GENOME_LOADED,
	NO_GENOME,
	LOADING_GENOME,
	UNKNOWN
}

#endregion

signal connection_state_changed(new_state: CONNECTION_STATE)
signal retrieved_connection_check_results(result: CONNECTION_CHECK_RESULTS)

var feagi_settings: FeagiGeneralSettings = null
var connection_state: CONNECTION_STATE = CONNECTION_STATE.DISCONNECTED
var genome_availability: GENOME_AVAILABILITY = GENOME_AVAILABILITY.UNKNOWN
var network: FEAGINetworking
var genome_requests
var genome_cache


# Zeroth Stage loading. FEAGICore initialization starts here
func _enter_tree():
	network = FEAGINetworking.new()
	network.name = "FEAGINetworking"
	add_child(network)

	# TEST
	feagi_settings = load("res://addons/FeagiCoreIntegration/FeagiCore/Config/feagi_default_settings.tres")
	attempt_connection(load("res://addons/FeagiCoreIntegration/FeagiCore/Config/network_local_default.tres"))
	
	# At this point, the scripts are initialized, but no attempt to connect to FEAGI was made.

## Use this to attempt connecting to FEAGI using details from the javascript. Returns true if javascript retireved valid info (DOES NOT MEAN CONNECTION WORKED)
func attempt_connection_via_javascript_details() -> bool:
	if feagi_settings == null:
		push_error("FEAGICORE: Cannot connect if no FEAGI settings have been set!")
		return false
	
	var endpoint_details: FeagiEndpointDetails = JavaScriptIntegrations.grab_feagi_endpoint_details()
	if endpoint_details.is_invalid():
		return false
	attempt_connection(endpoint_details)
	return true

## Use this to attempt connecting given explicit endpoint details
func attempt_connection(feagi_endpoint_details: FeagiEndpointDetails) -> void:
	if feagi_settings == null:
		push_error("FEAGICORE: Cannot connect if no FEAGI settings have been set!")
		return
		
	if connection_state != CONNECTION_STATE.DISCONNECTED:
		push_error("FEAGICORE: Cannot initiate a new connection when one is already active!")
		return
	
	_set_connection_state(CONNECTION_STATE.CONNECTING)
	network.check_connection_to_FEAGI(feagi_endpoint_details)

## Called as a response from "attempt_connection" to let us know if the feagi endpoint can take us. Do not call this directly
func FEAGI_retrieve_connection_check_results(result: CONNECTION_CHECK_RESULTS, _details: Dictionary = {}) -> void:
	# details var can be used at a later date
	match(result):
		CONNECTION_CHECK_RESULTS.NO_RESPONSE:
			push_warning("FEAGICORE: Failed to verify FEAGI was running at specified endpoint!")
		CONNECTION_CHECK_RESULTS.UNKNOWN_RESPONSE:
			push_warning("FEAGICORE: Unknown response from specified endpoint!")
		CONNECTION_CHECK_RESULTS.HEALTHY_BUT_NO_GENOME:
			print("FEAGICORE: Verified FEAGI running at endpoint, but no genome is loaded!")
		CONNECTION_CHECK_RESULTS.HEALTHY:
			print("FEAGICORE: Verified FEAGI running at endpoint with genome loaded!")
	retrieved_connection_check_results.emit(result)

		

func _set_connection_state(state: CONNECTION_STATE) -> void:
	match(state): #NOTE: For later use
		_:
			pass
	connection_state = state
	connection_state_changed.emit(state)
	
	
