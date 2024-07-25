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
signal delay_between_bursts_updated(new_delay: float)
signal skip_rate_updated(new_skip_rate: int)
signal skip_rate_updated_supression_threshold(new_supression_threshold: int)
signal about_to_reload_genome()

var connection_state: CONNECTION_STATE: # This refers primarily to the http api right now
	get: return _connection_state # No setter
var genome_load_state: GENOME_LOAD_STATE:
	get: return _genome_load_state # No setter
var feagi_settings: FeagiGeneralSettings:
	get: return _feagi_settings # No setter
var delay_between_bursts: float:
	get: return _delay_between_bursts
var skip_rate: int:
	get: return _skip_rate
var supression_threshold: int:
	get: return _supression_threshold

var network: FEAGINetworking
var requests: FEAGIRequests
var feagi_local_cache: FEAGILocalCache

var _connection_state: CONNECTION_STATE = CONNECTION_STATE.DISCONNECTED
var _genome_load_state: GENOME_LOAD_STATE = GENOME_LOAD_STATE.UNKNOWN

var _in_use_endpoint_details: FeagiEndpointDetails = null
var _feagi_settings: FeagiGeneralSettings = null

var _delay_between_bursts: float = 0
var _skip_rate: int = 0
var _supression_threshold: int = 0

# Zeroth Stage loading. FEAGICore initialization starts here
func _enter_tree():
	if network ==  null:
		network = FEAGINetworking.new()
		network.name = "FEAGINetworking"
		network.genome_reset_request_recieved.connect(_recieve_genome_reset_request)
		network.recieved_healthcheck_poll.connect(_on_healthcheck_poll)
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
	

## Use this to attempt connecting to FEAGI using details from the javascript, with fall back values from provided endpoint details
func attempt_connection_via_javascript_details(fallback_manual_endpoint_details: FeagiEndpointDetails) -> void:
	if feagi_settings == null:
		print("FEAGICORE: Cannot connect if no FEAGI settings have been set! Halting attempted connection to FEAGI!") # Do both print and push warning to make things easier to put together in logs
		push_error("FEAGICORE: Cannot connect if no FEAGI settings have been set! Halting attempted connection to FEAGI!")
		return
	
	var endpoint_details: FeagiEndpointDetails = JavaScriptIntegrations.overwrite_with_details_from_address_bar(fallback_manual_endpoint_details)

	attempt_connection(endpoint_details)
	return

## Use this to attempt connecting given explicit endpoint details
func attempt_connection(feagi_endpoint_details: FeagiEndpointDetails) -> void:
	if feagi_settings == null:
		push_error("FEAGICORE: Cannot connect if no FEAGI settings have been set!")
		return
		
	if connection_state != CONNECTION_STATE.DISCONNECTED:
		push_error("FEAGICORE: Cannot initiate a new connection when one is already active!")
		return
	
	var cache_state: CONNECTION_STATE = _connection_state
	_connection_state = CONNECTION_STATE.CONNECTING
	connection_state_changed.emit(CONNECTION_STATE.CONNECTING, cache_state)
	_in_use_endpoint_details = feagi_endpoint_details
	network.activate_and_verify_connection_to_FEAGI(feagi_endpoint_details)

# Disconnect from FEAGI
func disconnect_from_FEAGI() -> void:
	print("FEAGICORE: Disconnecting from FEAGI!")
	unload_genome()
	network.disconnect_networking()
	var cache_state: CONNECTION_STATE = _connection_state
	_connection_state = CONNECTION_STATE.DISCONNECTED
	connection_state_changed.emit(CONNECTION_STATE.DISCONNECTED, cache_state)
	

# Loads genome from FEAGI
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
	var cache_genome_state: GENOME_LOAD_STATE = _genome_load_state
	_genome_load_state = GENOME_LOAD_STATE.RELOADING_GENOME_FROM_FEAGI
	genome_load_state_changed.emit(GENOME_LOAD_STATE.RELOADING_GENOME_FROM_FEAGI, cache_genome_state) # This would be a good time to close any UIs

	var genome_load_response: FeagiRequestOutput = await requests.reload_genome()
	if !genome_load_response.success:
		# The above function has done its own error handling, check if we disconnected from FEAGI
		if connection_state != CONNECTION_STATE.DISCONNECTED:
			cache_genome_state = _genome_load_state
			_genome_load_state = GENOME_LOAD_STATE.GENOME_EXISTS_BUT_NOT_LOADED
			genome_load_state_changed.emit(GENOME_LOAD_STATE.GENOME_EXISTS_BUT_NOT_LOADED, cache_genome_state)
		# Assuming when we disconnected, the genome state was also cleared
		
		return
	cache_genome_state = _genome_load_state
	_genome_load_state = GENOME_LOAD_STATE.GENOME_LOADED_LOCALLY
	genome_load_state_changed.emit(GENOME_LOAD_STATE.GENOME_LOADED_LOCALLY, cache_genome_state)
	
## Unload the genome from the local cahce. Does not by itself disconnect from FEAGI
func unload_genome() -> void:
	if genome_load_state == GENOME_LOAD_STATE.RELOADING_GENOME_FROM_FEAGI:
		push_error("FEAGICORE: Genome is in the middle of being reloaded! Unable to wipe cache!")
		return
	if genome_load_state == GENOME_LOAD_STATE.GENOME_EXISTS_BUT_NOT_LOADED:
		push_error("FEAGICORE: Unable to wipe local genome since it is not loaded!")
		return
	feagi_local_cache.clear_whole_genome()
	var cache_genome_state: GENOME_LOAD_STATE = _genome_load_state
	_genome_load_state = GENOME_LOAD_STATE.UNKNOWN
	genome_load_state_changed.emit(GENOME_LOAD_STATE.UNKNOWN,cache_genome_state)

func request_reload_genome() -> void:
	if connection_state != CONNECTION_STATE.CONNECTED:
		push_error("FEAGICORE: Cannot reload genome when not connected to FEAGI!")
		return
	if !feagi_local_cache.genome_availability:
		push_error("FEAGICORE: Cannot reload genome when FEAGI reports it as unavailable!")
		return
	if genome_load_state != GENOME_LOAD_STATE.GENOME_LOADED_LOCALLY:
		push_error("FEAGICORE: Cannot start a reload of the genome when it is not loaded!")
		return
		
	var cache_genome_state: GENOME_LOAD_STATE = _genome_load_state
	_genome_load_state = GENOME_LOAD_STATE.RELOADING_GENOME_FROM_FEAGI
	genome_load_state_changed.emit(GENOME_LOAD_STATE.RELOADING_GENOME_FROM_FEAGI,cache_genome_state)
	
	var genome_load_response: FeagiRequestOutput = await requests.reload_genome()
	if !genome_load_response.success:
		# The above function has done its own error handling, check if we disconnected from FEAGI
		if connection_state != CONNECTION_STATE.DISCONNECTED:
			cache_genome_state = _genome_load_state
			_genome_load_state = GENOME_LOAD_STATE.GENOME_EXISTS_BUT_NOT_LOADED
			genome_load_state_changed.emit(GENOME_LOAD_STATE.GENOME_EXISTS_BUT_NOT_LOADED, cache_genome_state)
		# Assuming when we disconnected, the genome state was also cleared
		
	cache_genome_state = _genome_load_state
	_genome_load_state = GENOME_LOAD_STATE.GENOME_LOADED_LOCALLY
	genome_load_state_changed.emit(GENOME_LOAD_STATE.GENOME_LOADED_LOCALLY, cache_genome_state)
	

## Returns true if we can safely interact with feagi (connected and genome loaded)
func can_interact_with_feagi() -> bool:
	if connection_state != CONNECTION_STATE.CONNECTED:
		return false
	if genome_load_state != GENOME_LOAD_STATE.GENOME_LOADED_LOCALLY:
		return false
	return true



#region Internal

func feagi_retrieved_burst_rate(delay_bursts_apart: float) -> void:
	_delay_between_bursts = delay_bursts_apart
	delay_between_bursts_updated.emit(delay_bursts_apart)

func feagi_recieved_skip_rate(new_skip_rate: int) -> void:
	_skip_rate = new_skip_rate
	skip_rate_updated.emit(new_skip_rate)

func feagi_recieved_supression_threshold(new_supression_threshold: int) -> void:
	_supression_threshold = new_supression_threshold
	skip_rate_updated_supression_threshold.emit(new_supression_threshold)

## Respond to changing HTTP health during start procedure (not used in general healthcheck polling when already active)
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
					var cache_connection: CONNECTION_STATE = _connection_state
					_connection_state = CONNECTION_STATE.DISCONNECTED
					connection_state_changed.emit(CONNECTION_STATE.DISCONNECTED, cache_connection)
				CONNECTION_STATE.CONNECTED:
					# We were connected, but then feagi stopped responding
					push_warning("FEAGICORE: FEAGI Appears Unresponsive!")
					print("FEAGICORE: Disconnecting from FEAGI due to lack of connection!")
					disconnect_from_FEAGI()
				_:
					# Not sure how we can land here, but regardless feagi is unresponsive
					push_warning("FEAGICORE: FEAGI Appears Unresponsive!")
					print("FEAGICORE: Disconnecting from FEAGI due to lack of connection!")
					disconnect_from_FEAGI() #?
				
		FEAGIHTTPAPI.HTTP_HEALTH.CONNECTABLE:
			match(connection_state):
				CONNECTION_STATE.CONNECTING:
					# We were likely probing and got a good response
					print("FEAGICORE: Verified FEAGI running at endpoint")
					var cache_connection: CONNECTION_STATE = _connection_state
					_connection_state = CONNECTION_STATE.CONNECTED # Seperate the updating of this value and external signaling to make sure order of operations is safe!
					connection_state_changed.emit(CONNECTION_STATE.CONNECTED, cache_connection)
					print("FEAGICORE: Connected to FEAGI via HTTP API!")
					if feagi_settings.attempt_connect_websocket_on_launch:
						network.activate_websocket_APT(_in_use_endpoint_details.full_websocket_address)
						#NOTE: An attempt to connect will be made, but not promised. You must keep an eye on the signals from here to update the UI accordingly
						# This will immediately raise the connecting flag, then either the connected flag or disconnect flag
					if feagi_settings.load_genome_on_connect_if_available:
						if feagi_local_cache.genome_availability:
							print("FEAGICORE: Genome detected, loading automatically as per configuration!")
							load_genome_from_FEAGI()
						else:
							print("FEAGICORE: No Genome detected in FEAGI!")
							var cache_genome_state: GENOME_LOAD_STATE = _genome_load_state
							_genome_load_state = GENOME_LOAD_STATE.NO_GENOME_IN_FEAGI
							genome_load_state_changed.emit(GENOME_LOAD_STATE.NO_GENOME_IN_FEAGI, cache_genome_state)
					else:
						if feagi_local_cache.genome_availability:
							print("FEAGICORE: Genome detected but configuration is set not to load it automatically. Skipping genome loading!")
							var cache_genome_state: GENOME_LOAD_STATE = _genome_load_state
							_genome_load_state = GENOME_LOAD_STATE.GENOME_EXISTS_BUT_NOT_LOADED
							genome_load_state_changed.emit(GENOME_LOAD_STATE.GENOME_EXISTS_BUT_NOT_LOADED, cache_genome_state)
						else:
							print("FEAGICORE: No Genome detected in FEAGI!")
							var cache_genome_state: GENOME_LOAD_STATE = _genome_load_state
							_genome_load_state = GENOME_LOAD_STATE.NO_GENOME_IN_FEAGI
							genome_load_state_changed.emit(GENOME_LOAD_STATE.NO_GENOME_IN_FEAGI, cache_genome_state)
					if feagi_settings.enable_HTTP_healthcheck:
						print("FEAGICORE: Establishing polling HTTP healthcheck as per configuration!")
						network.establish_HTTP_healthcheck()
					return
					
				CONNECTION_STATE.CONNECTED:
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
					var cache_connection: CONNECTION_STATE = _connection_state
					_connection_state = CONNECTION_STATE.DISCONNECTED
					connection_state_changed.emit(CONNECTION_STATE.DISCONNECTED, cache_connection)
				CONNECTION_STATE.CONNECTED:
					# We were connected, but then feagi stopped responding
					push_warning("FEAGICORE: FEAGI has returned an error!")
					disconnect_from_FEAGI()
				_:
					# Not sure how we can land here, but regardless feagi is erroring
					push_warning("FEAGICORE: FEAGI has returned an error!")
					disconnect_from_FEAGI() #?


## Respond to health check polling
func _on_healthcheck_poll() -> void:
	if _genome_load_state == GENOME_LOAD_STATE.NO_GENOME_IN_FEAGI && feagi_local_cache.genome_availability:
		# There was no genome in FEAGI but now there is.
		if _feagi_settings.late_load_genome_if_not_immediately_available:
			print("FEAGICORE: Genome is now detected in FEAGI! Loading as per configuration!")
			load_genome_from_FEAGI()
		else:
			print("FEAGICORE: Genome is now detected in FEAGI! NOT Loading as per configuration!")
			var prev_state: GENOME_LOAD_STATE = _genome_load_state
			_genome_load_state = GENOME_LOAD_STATE.GENOME_EXISTS_BUT_NOT_LOADED
			genome_load_state_changed.emit(GENOME_LOAD_STATE.GENOME_EXISTS_BUT_NOT_LOADED, prev_state)

	if !feagi_local_cache.genome_availability && _genome_load_state == GENOME_LOAD_STATE.GENOME_LOADED_LOCALLY:
		# we lost the genome, unload
		print("FEAGICORE: Genome is no longer detected in FEAGI! Unloading the local cached genome!")
		unload_genome()
		return


func _recieve_genome_reset_request():
	#about_to_reload_genome.emit()
	#requests.reload_genome()
	load_genome_from_FEAGI()

#endregion
