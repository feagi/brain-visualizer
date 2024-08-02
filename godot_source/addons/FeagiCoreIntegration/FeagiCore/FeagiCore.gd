extends Node
## Autoloaded, root of all communication and data to / from FEAGI

# TODO writeup


#region Statics / consts

enum GENOME_LOAD_STATE {
	UNKNOWN, # Not connected to feagi, genome state unknown
	NO_GENOME_AVAILABLE, # connected to feagi, but no genome found
	GENOME_RELOADING, # currently downloading the genome from feagi
	GENOME_READY, # genome downloaded, ready for user operations
	GENOME_PROCESSING # feagi is hung up somewhere. Wait, prevent user input
}

#endregion

signal genome_load_state_changed(new_state: GENOME_LOAD_STATE, prev_state: GENOME_LOAD_STATE)
signal delay_between_bursts_updated(new_delay: float)
signal skip_rate_updated(new_skip_rate: int)
signal skip_rate_updated_supression_threshold(new_supression_threshold: int)
signal about_to_reload_genome()

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

var _genome_load_state: GENOME_LOAD_STATE = GENOME_LOAD_STATE.UNKNOWN

var _in_use_endpoint_details: FeagiEndpointDetails = null
var _feagi_settings: FeagiGeneralSettings = null

var _polling_health_check_worker: APIRequestWorker = null # Due to unique circumstances, we keep this here

var _delay_between_bursts: float = 0
var _skip_rate: int = 0
var _supression_threshold: int = 0



# FEAGICore initialization starts here before any external action
func _enter_tree():
	if network ==  null:
		network = FEAGINetworking.new()
		network.name = "FEAGINetworking"
		network.genome_reset_request_recieved.connect(_recieve_genome_reset_request)
		add_child(network)
	feagi_local_cache = FEAGILocalCache.new()
	requests = FEAGIRequests.new()
	# At this point, the scripts are initialized, but no attempt to connect to FEAGI was made.


#NOTE: This should be the first call you make to CORE
## Load general settings (not endpoint related)
func load_FEAGI_settings(settings: FeagiGeneralSettings) -> void:
	if network.connection_state != FEAGINetworking.CONNECTION_STATE.DISCONNECTED:
		push_error("FEAGICORE: Cannot change FEAGI settings if currently connected!")
		return
	_feagi_settings = settings


## Initiate a new connection using javascript details (URL parameters). Only works on web exports
func attempt_connection_to_FEAGI_via_javascript_details(fallback_manual_endpoint_details: FeagiEndpointDetails) -> void:
	if feagi_settings == null:
		push_error("FEAGICORE: Cannot connect if no FEAGI settings have been set! Halting attempted connection to FEAGI!")
		return
	
	var endpoint_details: FeagiEndpointDetails = JavaScriptIntegrations.overwrite_with_details_from_address_bar(fallback_manual_endpoint_details)
	attempt_connection_to_FEAGI(endpoint_details)


## Attempt to connect to FEAGI. If sucessful, Genome loading will follow automatically
func attempt_connection_to_FEAGI(feagi_endpoint_details: FeagiEndpointDetails) -> void:
	if feagi_settings == null:
		push_error("FEAGICORE: Cannot connect if no FEAGI settings have been set!")
		return
		
	if network.connection_state != FEAGINetworking.CONNECTION_STATE.DISCONNECTED:
		push_error("FEAGICORE: Cannot initiate a new connection when one is already active!")
		return
	
	print("FEAGICORE: Connecting to FEAGI!")
	_in_use_endpoint_details = feagi_endpoint_details
	
	# Attempt a connection to FEAGI
	var was_connection_sucessful: bool = await network.attempt_connection(feagi_endpoint_details)
	if !was_connection_sucessful:
		return
	
	# Start the polling health worker
	network.http_API.kill_polling_healthcheck_worker() # Ensure theres only 1 worker
	
	var polling_health_check_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_polling_call(
		FeagiCore.network.http_API.address_list.GET_system_healthCheck,
		HTTPClient.METHOD_GET,
		null,
		FeagiCore.feagi_settings.seconds_between_healthcheck_pings,
	)
	
	_polling_health_check_worker = FeagiCore.network.http_API.make_HTTP_call(polling_health_check_request)
	_polling_health_check_worker.name = FeagiCore.network.http_API.HEALTH_CHECK_WORKER_NAME
	
	var process_output_for_cache: Callable = func(polled_result: FeagiRequestOutput) :  # Functional Programming my beloved
		if polled_result.has_timed_out:
			return
		if polled_result.has_errored:
			return
		var health_data: Dictionary = polled_result.decode_response_as_dict()
		feagi_local_cache.update_health_from_FEAGI_dict(health_data)
	
	# NOTE: Nothing in core will respond to the events here since we are not connected to them yet!
	_polling_health_check_worker.worker_retrieved_latest_poll.connect(process_output_for_cache)
	await _polling_health_check_worker.worker_retrieved_latest_poll
	
	# confirm we have the required keys
	var raw_output: FeagiRequestOutput = _polling_health_check_worker.retrieve_output_and_continue()
	var processed_response: Dictionary = raw_output.decode_response_as_dict()
	if !("genome_availability" in processed_response) or !("brain_readiness" in processed_response):
		push_error("FEAGICORE: Healthcheck is missing keys for brain readiness or genome availability! Halting connection!")
		_polling_health_check_worker = null
		network.disconnect_networking()
		return
	
	if feagi_local_cache.genome_availability:
		if feagi_local_cache.brain_readiness:
			# genome ready to be downloaded:
			_change_genome_state(GENOME_LOAD_STATE.GENOME_RELOADING)
			return
		else:
			# Genome in the middle of processing
			_change_genome_state(GENOME_LOAD_STATE.GENOME_PROCESSING)
	else:
		# No Genome!
		_change_genome_state(GENOME_LOAD_STATE.NO_GENOME_AVAILABLE)
	
	feagi_local_cache.genome_availability_or_brain_readiness_changed.connect(_if_brain_readiness_or_genome_availability_changes)


# Disconnect from FEAGI
func disconnect_from_FEAGI() -> void:
	print("FEAGICORE: Disconnecting from FEAGI!")
	_change_genome_state(GENOME_LOAD_STATE.UNKNOWN)
	
func can_interact_with_feagi() -> bool:
	return _genome_load_state == GENOME_LOAD_STATE.GENOME_READY
	

#region Internal

func _change_genome_state(new_state: GENOME_LOAD_STATE) -> void:
	var prev_state: GENOME_LOAD_STATE = _genome_load_state
	match(new_state):
		GENOME_LOAD_STATE.UNKNOWN:
			# This will only occur if we are disconnecting from FEAGI (or connection lost), thus can come from any
			feagi_local_cache.clear_whole_genome()
			network.disconnect_networking()
			if feagi_local_cache.genome_availability_or_brain_readiness_changed.is_connected(_if_brain_readiness_or_genome_availability_changes):
				feagi_local_cache.genome_availability_or_brain_readiness_changed.disconnect(_if_brain_readiness_or_genome_availability_changes)
			feagi_local_cache.set_health_dead()
		GENOME_LOAD_STATE.NO_GENOME_AVAILABLE:
			# Can Only Come here from Unknown
			feagi_local_cache.clear_whole_genome()
		GENOME_LOAD_STATE.GENOME_RELOADING:
			# Can come from Unknown, No_Genome_Available, Genome_Processing, or Genome_Ready
			about_to_reload_genome.emit()
			feagi_local_cache.clear_whole_genome()
			requests.reload_genome()
		GENOME_LOAD_STATE.GENOME_READY:
			# Only path to here is from Genome_Reloading.
			pass
		GENOME_LOAD_STATE.GENOME_PROCESSING:
			# Can come from Unknown or from Genome_Ready
			pass
	
	_genome_load_state = new_state
	genome_load_state_changed.emit(prev_state, new_state)


func _if_brain_readiness_or_genome_availability_changes(available: bool, ready: bool) -> void:
	if !available:
		_change_genome_state(GENOME_LOAD_STATE.NO_GENOME_AVAILABLE)
		return
	if ready:
		_change_genome_state(GENOME_LOAD_STATE.GENOME_READY)
	else:
		_change_genome_state(GENOME_LOAD_STATE.GENOME_PROCESSING)


func feagi_retrieved_burst_rate(delay_bursts_apart: float) -> void:
	_delay_between_bursts = delay_bursts_apart
	delay_between_bursts_updated.emit(delay_bursts_apart)

func feagi_recieved_skip_rate(new_skip_rate: int) -> void:
	_skip_rate = new_skip_rate
	skip_rate_updated.emit(new_skip_rate)

func feagi_recieved_supression_threshold(new_supression_threshold: int) -> void:
	_supression_threshold = new_supression_threshold
	skip_rate_updated_supression_threshold.emit(new_supression_threshold)


func _recieve_genome_reset_request():
	_change_genome_state(GENOME_LOAD_STATE.GENOME_RELOADING)

#endregion
