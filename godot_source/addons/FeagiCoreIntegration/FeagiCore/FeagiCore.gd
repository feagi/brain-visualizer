extends Node
## Autoloaded, root of all communication adn data to / from FEAGI

#region Statics / consts

enum CONNECTION_STATE {
	DISCONNECTED,
	CONNECTING,
	CONNECTED,
	DISCONNECTING
}

enum GENOME_LOAD_STATE {
	GENOME_LOADED,
	NO_GENOME,
	LOADING_GENOME,
	GENOME_EXISTS,
	UNKNOWN
}

#endregion

signal connection_state_changed(new_state: CONNECTION_STATE)

var connection_state: CONNECTION_STATE: # This refers primarily to the http api right now
	get: return _connection_state # No setter
var genome_load_state: GENOME_LOAD_STATE = GENOME_LOAD_STATE.UNKNOWN
var network: FEAGINetworking
var genome_requests
var genome_cache: FEAGIGenomeCache

var _connection_state: CONNECTION_STATE = CONNECTION_STATE.DISCONNECTED
var _feagi_settings: FeagiGeneralSettings = null
var _in_use_endpoint_details: FeagiEndpointDetails = null

# Zeroth Stage loading. FEAGICore initialization starts here
func _enter_tree():

	# TEST
	load_FEAGI_settings(load("res://addons/FeagiCoreIntegration/FeagiCore/Config/feagi_default_settings.tres"))
	attempt_connection(load("res://addons/FeagiCoreIntegration/FeagiCore/Config/network_local_default.tres"))
	
	# At this point, the scripts are initialized, but no attempt to connect to FEAGI was made.

## Load general settings (not endpoint related)
func load_FEAGI_settings(settings: FeagiGeneralSettings) -> void:
	_feagi_settings = settings
	if network ==  null:
		network = FEAGINetworking.new(_feagi_settings)
		network.name = "FEAGINetworking"
		add_child(network)
		
	genome_cache = FEAGIGenomeCache.new()

## Use this to attempt connecting to FEAGI using details from the javascript. Returns true if javascript retireved valid info (DOES NOT MEAN CONNECTION WORKED)
func attempt_connection_via_javascript_details() -> bool:
	if _feagi_settings == null:
		push_error("FEAGICORE: Cannot connect if no FEAGI settings have been set!")
		return false
	
	var endpoint_details: FeagiEndpointDetails = JavaScriptIntegrations.grab_feagi_endpoint_details()
	if endpoint_details.is_invalid():
		push_warning("FEAGICORE: Unable to acquire connection details from javascript!")
		return false
	attempt_connection(endpoint_details)
	return true

## Use this to attempt connecting given explicit endpoint details
func attempt_connection(feagi_endpoint_details: FeagiEndpointDetails) -> void:
	if _feagi_settings == null:
		push_error("FEAGICORE: Cannot connect if no FEAGI settings have been set!")
		return
		
	if connection_state != CONNECTION_STATE.DISCONNECTED:
		push_error("FEAGICORE: Cannot initiate a new connection when one is already active!")
		return
	
	if feagi_endpoint_details.is_invalid():
		push_error("FEAGICORE: Connection parameters marked as invalid!")
		return
	
	_set_connection_state(CONNECTION_STATE.CONNECTING)
	_in_use_endpoint_details = feagi_endpoint_details
	network.check_connection_to_FEAGI(feagi_endpoint_details)
	network.http_API.FEAGI_http_health_changed.connect(_http_API_state_change_response)

func _http_API_state_change_response(health: FEAGIHTTPAPI.HTTP_HEALTH) -> void:
	# Bit too much nexting imo, but this is cleaner than having externalm single use functions
	# Godot, pls add nested function support!
	match(health):
		FEAGIHTTPAPI.HTTP_HEALTH.NO_CONNECTION:
			# No response from FEAGI	
			match(connection_state):
				CONNECTION_STATE.CONNECTING:
					# We were likely probing and no response
					push_warning("FEAGICORE: Failed to verify FEAGI was running at specified endpoint!")
					_set_connection_state(CONNECTION_STATE.DISCONNECTED)
				CONNECTION_STATE.CONNECTED:
					# We were connected, but then feagi stopped responding
					push_warning("FEAGICORE: FEAGI Appears Unresponsive!")
					# TODO Disconnect feagi
				_:
					# Not sure how we can land here, but regardless feagi is unresponsive
					push_warning("FEAGICORE: FEAGI Appears Unresponsive!")
					# TODO Disconnect feagi?
			
		FEAGIHTTPAPI.HTTP_HEALTH.CONNECTABLE:
			match(connection_state):
				CONNECTION_STATE.CONNECTING:
					# We were likely probing and got a good response
					print("FEAGICORE: Verified FEAGI running at endpoint")
					_set_connection_state(CONNECTION_STATE.CONNECTED)
					# TODO connect websocket
					# TODO other actions based on genome availabilty (written in cache by now)
				#TODO: other cases
		FEAGIHTTPAPI.HTTP_HEALTH.ERROR:
			# We have an error from FEAGI
			# TODO: Add specific error handling, but for now just copy the no response actions
			match(connection_state):
				CONNECTION_STATE.CONNECTING:
					# We were likely probing and no response
					push_warning("FEAGICORE: FEAGI has returned an error!")
					_set_connection_state(CONNECTION_STATE.DISCONNECTED)
				CONNECTION_STATE.CONNECTED:
					# We were connected, but then feagi stopped responding
					push_warning("FEAGICORE: FEAGI has returned an error!")
					# TODO Disconnect feagi
				_:
					# Not sure how we can land here, but regardless feagi is erroring
					push_warning("FEAGICORE: FEAGI has returned an error!")
					# TODO Disconnect feagi?

func _set_connection_state(state: CONNECTION_STATE) -> void:
	_connection_state = state
	connection_state_changed.emit(state)
	
	
