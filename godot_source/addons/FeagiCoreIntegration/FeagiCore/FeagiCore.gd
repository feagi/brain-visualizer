extends Node
## Autoloaded, root of all communication adn data to / from FEAGI

#region Statics / consts

enum CONNECTION_STATE {
	DISCONNECTED,
	CONNECTING,
	CONNECTED,
}

enum GENOME_LOAD_STATE {
	GENOME_LOADED_LOCALLY,
	NO_GENOME_IN_FEAGI,
	RELOADING_GENOME_FROM_FEAGI,
	GENOME_EXISTS_BUT_NOT_LOADED,
	UNKNOWN
}



#endregion

signal connection_state_changed(new_state: CONNECTION_STATE, previous_state: CONNECTION_STATE)
signal genome_load_state_changed(new_state: GENOME_LOAD_STATE, prev_state: GENOME_LOAD_STATE)

var connection_state: CONNECTION_STATE: # This refers primarily to the http api right now
	get: return _connection_state # No setter
var genome_load_state: GENOME_LOAD_STATE:
	get: return _genome_load_state # No setter
var feagi_settings: FeagiGeneralSettings:
	get: return _feagi_settings # No setter
var network: FEAGINetworking
var requests: FEAGIRequests
var feagi_local_cache: FEAGILocalCache

var _connection_state: CONNECTION_STATE = CONNECTION_STATE.DISCONNECTED
var _genome_load_state: GENOME_LOAD_STATE = GENOME_LOAD_STATE.UNKNOWN

var _in_use_endpoint_details: FeagiEndpointDetails = null
var _feagi_settings: FeagiGeneralSettings = null

# Zeroth Stage loading. FEAGICore initialization starts here
func _enter_tree():
	if network ==  null:
		network = FEAGINetworking.new()
		network.name = "FEAGINetworking"
		add_child(network)
	feagi_local_cache = FEAGILocalCache.new()
	requests = FEAGIRequests.new()
	
	network.http_API.FEAGI_http_health_changed.connect(_http_API_state_change_response)
	# At this point, the scripts are initialized, but no attempt to connect to FEAGI was made.

#NOTE: This should be the first call you make
## Load general settings (not endpoint related)
func load_FEAGI_settings(settings: FeagiGeneralSettings) -> void:
	if connection_state != CONNECTION_STATE.DISCONNECTED:
		push_error("FEAGICORE: Cannot change FEAGI settings if currently connected!")
		return
	_feagi_settings = settings


## Use this to attempt connecting to FEAGI using details from the javascript. Returns true if javascript retireved valid info (DOES NOT MEAN CONNECTION WORKED)
func attempt_connection_via_javascript_details() -> bool:
	if feagi_settings == null:
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
	if feagi_settings == null:
		push_error("FEAGICORE: Cannot connect if no FEAGI settings have been set!")
		return
		
	if connection_state != CONNECTION_STATE.DISCONNECTED:
		push_error("FEAGICORE: Cannot initiate a new connection when one is already active!")
		return
	
	if feagi_endpoint_details.is_invalid():
		push_error("FEAGICORE: Connection parameters marked as invalid!")
		return
	
	connection_state_changed.emit(CONNECTION_STATE.CONNECTING, _connection_state)
	_connection_state = CONNECTION_STATE.CONNECTING
	_in_use_endpoint_details = feagi_endpoint_details
	network.activate_and_verify_connection_to_FEAGI(feagi_endpoint_details)

# Disconnect from FEAGI
func disconnect_from_FEAGI() -> void:
	network.disconnect_networking()
	#TODO clear cache
	genome_load_state_changed.emit(GENOME_LOAD_STATE.UNKNOWN,_genome_load_state)
	_genome_load_state = GENOME_LOAD_STATE.UNKNOWN
	connection_state_changed.emit(CONNECTION_STATE.DISCONNECTED, _connection_state)
	_connection_state = CONNECTION_STATE.DISCONNECTED

# (Re)loads genome from FEAGI
func load_genome_from_FEAGI() -> void:
	if connection_state != CONNECTION_STATE.CONNECTED:
		push_error("FEAGICORE: Cannot load genome when not connected to FEAGI!")
		return
	if !feagi_local_cache.genome_availability:
		push_error("FEAGICORE: Cannot load genome when FEAGI reports it as unavailable!")
		return
	if genome_load_state == GENOME_LOAD_STATE.RELOADING_GENOME_FROM_FEAGI:
		push_error("FEAGICORE: Cannot start a reload of the genome when it currently being loaded!")
		return
	genome_load_state_changed.emit(GENOME_LOAD_STATE.RELOADING_GENOME_FROM_FEAGI, _genome_load_state) # This would be a good time to close any UIs
	_genome_load_state = GENOME_LOAD_STATE.RELOADING_GENOME_FROM_FEAGI
	#TODO wipe current data
	

	var is_loading_genome_succesful: bool = await requests.reload_genome()
	if !is_loading_genome_succesful:
		# The above function has done its own error handling, check if we disconnected from FEAGI
		if connection_state != CONNECTION_STATE.DISCONNECTED:
			genome_load_state_changed.emit(GENOME_LOAD_STATE.GENOME_EXISTS_BUT_NOT_LOADED, _genome_load_state)
			_genome_load_state = GENOME_LOAD_STATE.GENOME_EXISTS_BUT_NOT_LOADED
		# Assuming when we disconnected, the genome state was also cleared
		return
	genome_load_state_changed.emit(GENOME_LOAD_STATE.GENOME_LOADED_LOCALLY, _genome_load_state)
	_genome_load_state = GENOME_LOAD_STATE.GENOME_LOADED_LOCALLY
	


func _http_API_state_change_response(health: FEAGIHTTPAPI.HTTP_HEALTH) -> void:
	# Bit too much nesting imo, but this is cleaner than having external single use functions
	# Godot, pls add nested function support!
	#TODO try using an external script instead for cleanup
	match(health):
		FEAGIHTTPAPI.HTTP_HEALTH.NO_CONNECTION:
			# No response from FEAGI	
			match(connection_state):
				CONNECTION_STATE.CONNECTING:
					# We were likely probing and no response
					push_warning("FEAGICORE: Failed to verify FEAGI was running at specified endpoint!")
					connection_state_changed.emit(CONNECTION_STATE.DISCONNECTED, _connection_state)
					_connection_state = CONNECTION_STATE.DISCONNECTED
				CONNECTION_STATE.CONNECTED:
					# We were connected, but then feagi stopped responding
					push_warning("FEAGICORE: FEAGI Appears Unresponsive!")
					disconnect_from_FEAGI()
				_:
					# Not sure how we can land here, but regardless feagi is unresponsive
					push_warning("FEAGICORE: FEAGI Appears Unresponsive!")
					disconnect_from_FEAGI() #?
			
			
		FEAGIHTTPAPI.HTTP_HEALTH.CONNECTABLE:
			match(connection_state):
				CONNECTION_STATE.CONNECTING:
					# We were likely probing and got a good response
					print("FEAGICORE: Verified FEAGI running at endpoint")
					connection_state_changed.emit(CONNECTION_STATE.CONNECTED, _connection_state)
					_connection_state = CONNECTION_STATE.CONNECTED # Seperate the updating of this value and external signaling to make sure order of operations is safe!
					print("FEAGICORE: Connected to FEAGI via HTTP API!")
					if feagi_settings.attempt_connect_websocket_on_launch:
						network.activate_websocket_APT(_in_use_endpoint_details.get_websocket_URL())
						#NOTE: An attempt to connect will be made, but not promised. You must keep an eye on the signals from here to update the UI accordingly
						# This will immediately raise the connecting flag, then either the connected flag or disconnect flag
					if feagi_settings.load_genome_on_connect_if_available:
						if feagi_local_cache.genome_availability:
							print("FEAGICORE: Genome detected, loading automatically as per configuration!")
							load_genome_from_FEAGI()
						else:
							print("FEAGICORE: No Genome detected in FEAGI!")
							genome_load_state_changed.emit(GENOME_LOAD_STATE.NO_GENOME_IN_FEAGI, _genome_load_state)
							_genome_load_state = GENOME_LOAD_STATE.NO_GENOME_IN_FEAGI
					else:
						if feagi_local_cache.genome_availability:
							print("FEAGICORE: Genome detected but configuration is set not to load it automatically. Skipping genome loading!")
							genome_load_state_changed.emit(GENOME_LOAD_STATE.GENOME_EXISTS_BUT_NOT_LOADED, _genome_load_state)
							_genome_load_state = GENOME_LOAD_STATE.GENOME_EXISTS_BUT_NOT_LOADED
						else:
							print("FEAGICORE: No Genome detected in FEAGI!")
							genome_load_state_changed.emit(GENOME_LOAD_STATE.NO_GENOME_IN_FEAGI, _genome_load_state)
							_genome_load_state = GENOME_LOAD_STATE.NO_GENOME_IN_FEAGI
					return
					
				CONNECTION_STATE.CONNECTED:
					#TODO health updated while connected (cache already updated). do other stuff
					pass
				_:
					#This shouldnt be possible
					push_error("FEAGICORE: Somehow ended up getting a connectable healthcheck while not connecting to feagi...")
		
		
		FEAGIHTTPAPI.HTTP_HEALTH.ERROR:
			# We have an error from FEAGI
			# TODO: Add specific error handling, but for now just copy the no response actions
			match(connection_state):
				CONNECTION_STATE.CONNECTING:
					# We were likely probing and no response
					push_warning("FEAGICORE: FEAGI has returned an error!")
					connection_state_changed.emit(CONNECTION_STATE.DISCONNECTED, _connection_state)
					_connection_state = CONNECTION_STATE.DISCONNECTED
				CONNECTION_STATE.CONNECTED:
					# We were connected, but then feagi stopped responding
					push_warning("FEAGICORE: FEAGI has returned an error!")
					disconnect_from_FEAGI()
				_:
					# Not sure how we can land here, but regardless feagi is erroring
					push_warning("FEAGICORE: FEAGI has returned an error!")
					disconnect_from_FEAGI() #?

	
