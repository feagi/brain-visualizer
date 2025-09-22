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

# Timer for periodic simulation_timestep checks
var _simulation_timestep_timer: Timer

# Health check failure tracking
var _consecutive_health_failures: int = 0
const MAX_HEALTH_FAILURES_BEFORE_DISCONNECT: int = 3



# FEAGICore initialization starts here before any external action
func _enter_tree():
	if network ==  null:
		network = FEAGINetworking.new()
		network.name = "FEAGINetworking"
		network.genome_reset_request_recieved.connect(_recieve_genome_reset_request)
		add_child(network)
	feagi_local_cache = FEAGILocalCache.new()
	feagi_local_cache.genome_refresh_needed.connect(_on_genome_refresh_needed)
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
	
	print("FEAGICORE: [3D_SCENE_DEBUG] Starting connection to FEAGI...")
	_in_use_endpoint_details = feagi_endpoint_details
	
	# Attempt a connection to FEAGI
	print("FEAGICORE: [3D_SCENE_DEBUG] Attempting network connection...")
	var was_connection_sucessful: bool = await network.attempt_connection(feagi_endpoint_details)
	if !was_connection_sucessful:
		print("FEAGICORE: [3D_SCENE_DEBUG] ❌ Network connection FAILED - 3D scene will not load")
		return
	
	print("FEAGICORE: [3D_SCENE_DEBUG] ✅ Network connection successful")
	
	# Start the health worker
	print("FEAGICORE: [3D_SCENE_DEBUG] Starting health check worker...")
	network.http_API.kill_polling_healthcheck_worker() # Ensure theres only 1 worker
	
	# SAFETY: Ensure HTTP API and address list are constructed before referencing
	var http_api = network.http_API if network != null else null
	if http_api == null:
		push_error("FEAGICORE: HTTP API not initialized before health check request")
		return
	var addr_list = http_api.get("address_list")
	if addr_list == null:
		push_error("FEAGICORE: HTTP API address list not initialized before health check request")
		return
	# Use locals to avoid chained member resolution at parse time
	var health_url: StringName = addr_list.GET_system_healthCheck
	var health_check_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(health_url)
	
	var process_output_for_cache: Callable = func(polled_result: FeagiRequestOutput) :  # Functional Programming my beloved
		if polled_result.has_timed_out:
			print("FEAGICORE: [3D_SCENE_DEBUG] ⚠️ Health check timed out")
			return
		if polled_result.has_errored:
			print("FEAGICORE: [3D_SCENE_DEBUG] ❌ Health check errored")
			return
		var health_data: Dictionary = polled_result.decode_response_as_dict()
		print("FEAGICORE: [3D_SCENE_DEBUG] ✅ Health check successful, updating cache...")
		print("FEAGICORE: [3D_SCENE_DEBUG] Health check data received: ", health_data)
		feagi_local_cache.update_health_from_FEAGI_dict(health_data)
	
	_polling_health_check_worker = FeagiCore.network.http_API.make_HTTP_call(health_check_request)

	await _polling_health_check_worker.worker_done
	
	# confirm we have the required keys
	print("FEAGICORE: [3D_SCENE_DEBUG] Processing health check response...")
	var raw_output: FeagiRequestOutput = _polling_health_check_worker.retrieve_output_and_continue()
	var processed_response: Dictionary = raw_output.decode_response_as_dict()
	print("FEAGICORE: [3D_SCENE_DEBUG] Processed health check response: ", processed_response)
	if !("genome_availability" in processed_response) or !("brain_readiness" in processed_response):
		print("FEAGICORE: [3D_SCENE_DEBUG] ❌ Health check missing required keys (genome_availability/brain_readiness) - 3D scene will not load")
		_polling_health_check_worker = null
		network.disconnect_networking()
		return
	
	print("FEAGICORE: [3D_SCENE_DEBUG] ✅ Health check contains required keys")
	process_output_for_cache.call(raw_output)
	
	# Start periodic HTTP health check for simulation_timestep (websocket doesn't have it)
	_start_periodic_simulation_timestep_check()
	
	print("FEAGICORE: [3D_SCENE_DEBUG] Evaluating genome state...")
	print("FEAGICORE: [3D_SCENE_DEBUG] - genome_availability: ", feagi_local_cache.genome_availability)
	print("FEAGICORE: [3D_SCENE_DEBUG] - brain_readiness: ", feagi_local_cache.brain_readiness)
	
	if feagi_local_cache.genome_availability:
		if feagi_local_cache.brain_readiness:
			# genome ready to be downloaded:
			print("FEAGICORE: [3D_SCENE_DEBUG] ✅ Both genome_availability and brain_readiness are true - initiating genome reload")
			_change_genome_state(GENOME_LOAD_STATE.GENOME_RELOADING)
			return
		else:
			# Genome in the middle of processing
			print("FEAGICORE: [3D_SCENE_DEBUG] ⚠️ Genome available but brain not ready - waiting for processing to complete")
			_change_genome_state(GENOME_LOAD_STATE.GENOME_PROCESSING)
	else:
		# No Genome!
		print("FEAGICORE: [3D_SCENE_DEBUG] ❌ No genome available - 3D scene cannot load")
		_change_genome_state(GENOME_LOAD_STATE.NO_GENOME_AVAILABLE)
	
	feagi_local_cache.genome_availability_or_brain_readiness_changed.connect(_if_brain_readiness_or_genome_availability_changes)

func _start_periodic_simulation_timestep_check() -> void:
	"""Start persistent HTTP health check - this should NEVER stop as long as BV is running"""
	print("FEAGICORE: [HEALTH_CHECK] Starting persistent health check timer...")
	
	# Check if network components are ready
	if not network or not network.http_API or not requests:
		print("FEAGICORE: [HEALTH_CHECK] ⚠️ Network not ready - will retry health check startup in 2 seconds")
		# If network isn't ready, try again in 2 seconds - NEVER give up!
		get_tree().create_timer(2.0).timeout.connect(_start_periodic_simulation_timestep_check)
		return

	if _simulation_timestep_timer:
		print("FEAGICORE: [HEALTH_CHECK] Replacing existing health check timer...")
		_simulation_timestep_timer.queue_free()

	_simulation_timestep_timer = Timer.new()
	_simulation_timestep_timer.name = "SimulationTimestepTimer"
	_simulation_timestep_timer.wait_time = 2.0  # Check every 2 seconds for faster disconnect detection
	_simulation_timestep_timer.timeout.connect(_fetch_simulation_timestep)
	_simulation_timestep_timer.autostart = false
	add_child(_simulation_timestep_timer)
	
	_simulation_timestep_timer.start()
	print("FEAGICORE: [HEALTH_CHECK] ✅ Health check timer started - will run every 2 seconds")

	# Also fetch it immediately
	_fetch_simulation_timestep()

func _fetch_simulation_timestep() -> void:
	"""Fetch simulation_timestep from HTTP health check with fast failure detection"""
	print("FEAGICORE: [HEALTH_CHECK] 🔍 Running periodic health check...")
	
	# SAFETY CHECK: Ensure health check timer is still running - restart if needed
	if not _simulation_timestep_timer or not _simulation_timestep_timer.is_inside_tree():
		print("FEAGICORE: [HEALTH_CHECK] ⚠️ Health check timer missing - restarting!")
		_start_periodic_simulation_timestep_check()
		return
	
	# Check if network components are available
	if not network or not network.http_API:
		print("FEAGICORE: [HEALTH_CHECK] ❌ Network components not available - cannot fetch simulation_timestep")
		return
	
	# If disconnected, try to restore the address list for reconnection attempts
	if not network.http_API.address_list and _in_use_endpoint_details:
		var addr_class = load("res://addons/FeagiCoreIntegration/FeagiCore/Networking/API/FEAGIHTTPAddressList.gd")
		network.http_API.address_list = addr_class.new(_in_use_endpoint_details.full_http_address)
	
	if not network.http_API.address_list:
		push_warning("FEAGI CORE: No address list available - cannot fetch simulation_timestep")
		return

	# Create a fast-failing health check request for disconnect detection - do it manually to bypass global settings
	var health_url: StringName = network.http_API.address_list.GET_system_healthCheck
	var fast_health_check_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.new()
	fast_health_check_request.full_address = health_url
	fast_health_check_request.method = HTTPClient.Method.METHOD_GET
	fast_health_check_request.call_type = APIRequestWorker.CALL_PROCESS_TYPE.SINGLE
	fast_health_check_request.data_to_send_to_FEAGI = null
	
	# Set custom fast-failing settings (bypassing global defaults)
	fast_health_check_request.http_timeout = 3.0  # Fast timeout: 3 seconds instead of 10
	fast_health_check_request.number_of_retries_allowed = 1  # Only 1 retry instead of 5 (bypasses global setting)
	
	var health_check_worker: APIRequestWorker = network.http_API.make_HTTP_call(fast_health_check_request)
	await health_check_worker.worker_done
	
	var response: FeagiRequestOutput = health_check_worker.retrieve_output_and_close()
	if response.success:
		print("FEAGICORE: [HEALTH_CHECK] ✅ Health check SUCCESS - updating cache and connection states")
		# Reset failure counter on success
		_consecutive_health_failures = 0
		
		# Update cache with health data for genome change detection
		var health_data: Dictionary = response.decode_response_as_dict()
		print("FEAGICORE: [HEALTH_CHECK] 📊 Health data: genome_availability=%s, brain_readiness=%s, feagi_session=%s, genome_num=%s" % [
			health_data.get("genome_availability", "?"), 
			health_data.get("brain_readiness", "?"),
			health_data.get("feagi_session", "?"),
			health_data.get("genome_num", "?")
		])
		feagi_local_cache.update_health_from_FEAGI_dict(health_data)
		
		# If we were disconnected and health check succeeds, restore connection states
		if network.connection_state == FEAGINetworking.CONNECTION_STATE.DISCONNECTED:
			# Restore HTTP health to CONNECTABLE
			network.http_API._request_state_change(network.http_API.HTTP_HEALTH.CONNECTABLE)
			
			# Also ensure websocket gets reconnected if needed
			if network.websocket_API.socket_health == network.websocket_API.WEBSOCKET_HEALTH.NO_CONNECTION:
				if _in_use_endpoint_details:
					network.websocket_API.setup(_in_use_endpoint_details.full_websocket_address)
					network.websocket_API.process_mode = Node.PROCESS_MODE_INHERIT
					# Ensure signal is connected
					if not network.websocket_API.FEAGI_socket_health_changed.is_connected(network._WS_health_changed):
						network.websocket_API.FEAGI_socket_health_changed.connect(network._WS_health_changed)
					network.websocket_API.connect_websocket()
		elif network.http_API.http_health == network.http_API.HTTP_HEALTH.NO_CONNECTION:
			# Just restore HTTP health if it was down but connection wasn't fully disconnected
			network.http_API._request_state_change(network.http_API.HTTP_HEALTH.CONNECTABLE)
	else:
		# Increment failure counter
		_consecutive_health_failures += 1
		print("FEAGICORE: [HEALTH_CHECK] ❌ Health check FAILED - failure %d/%d" % [_consecutive_health_failures, MAX_HEALTH_FAILURES_BEFORE_DISCONNECT])
		
		# Only trigger disconnect EXACTLY on the 3rd failure, not on subsequent failures
		if _consecutive_health_failures == MAX_HEALTH_FAILURES_BEFORE_DISCONNECT:
			print("FEAGICORE: [HEALTH_CHECK] 💀 3rd failure reached - triggering DISCONNECTED state")
			network.http_API._request_state_change(network.http_API.HTTP_HEALTH.NO_CONNECTION)


# Disconnect from FEAGI
func disconnect_from_FEAGI() -> void:
	print("FEAGICORE: Disconnecting from FEAGI!")
	_change_genome_state(GENOME_LOAD_STATE.UNKNOWN)
	
func can_interact_with_feagi() -> bool:
	return _genome_load_state == GENOME_LOAD_STATE.GENOME_READY
	

#region Internal

func _change_genome_state(new_state: GENOME_LOAD_STATE) -> void:
	var prev_state: GENOME_LOAD_STATE = _genome_load_state
	print("FEAGICORE: [3D_SCENE_DEBUG] Genome state transition: ", GENOME_LOAD_STATE.keys()[prev_state], " -> ", GENOME_LOAD_STATE.keys()[new_state])
	
	match(new_state):
		GENOME_LOAD_STATE.UNKNOWN:
			# This will only occur if we are disconnecting from FEAGI (or connection lost), thus can come from any
			print("FEAGICORE: [3D_SCENE_DEBUG] State UNKNOWN: Clearing genome and disconnecting")
			feagi_local_cache.clear_whole_genome()
			network.disconnect_networking()
			if feagi_local_cache.genome_availability_or_brain_readiness_changed.is_connected(_if_brain_readiness_or_genome_availability_changes):
				feagi_local_cache.genome_availability_or_brain_readiness_changed.disconnect(_if_brain_readiness_or_genome_availability_changes)
			feagi_local_cache.set_health_dead()
		GENOME_LOAD_STATE.NO_GENOME_AVAILABLE:
			# Can Only Come here from Unknown
			print("FEAGICORE: [3D_SCENE_DEBUG] State NO_GENOME_AVAILABLE: No genome found - 3D scene cannot load")
			feagi_local_cache.clear_whole_genome()
		GENOME_LOAD_STATE.GENOME_RELOADING:
			# Can come from Unknown, No_Genome_Available, Genome_Processing, or Genome_Ready
			print("FEAGICORE: [3D_SCENE_DEBUG] State GENOME_RELOADING: Starting FULL genome download...")
			print("FEAGICORE: [3D_SCENE_DEBUG] 🔥 This will be a COMPLETE reload - same as fresh BV startup!")
			print("FEAGICORE: [3D_SCENE_DEBUG] 📊 Current cache will be wiped and rebuilt from scratch")
			about_to_reload_genome.emit()
			feagi_local_cache.clear_whole_genome()
			reload_genome_await()
		GENOME_LOAD_STATE.GENOME_READY:
			# Only path to here is from Genome_Reloading.
			print("FEAGICORE: [3D_SCENE_DEBUG] State GENOME_READY: ✅ Genome loaded successfully - 3D scene should now initialize")
			pass
		GENOME_LOAD_STATE.GENOME_PROCESSING:
			# Can come from Unknown or from Genome_Ready
			print("FEAGICORE: [3D_SCENE_DEBUG] State GENOME_PROCESSING: FEAGI is processing - waiting for completion")
			pass
	
	_genome_load_state = new_state
	genome_load_state_changed.emit(new_state, prev_state)

# Hacky
func reload_genome_await():
	print("FEAGICORE: [3D_SCENE_DEBUG] reload_genome_await() called - starting genome reload process...")
	var start_time = Time.get_time_dict_from_system()
	var timeout_seconds = 30.0  # 30 second timeout
	
	# Create a timer to track progress AND monitor FEAGI health during reload
	var timer = Timer.new()
	timer.wait_time = 5.0  # Check every 5 seconds
	var start_ticks = Time.get_ticks_msec()
	var reload_aborted = false
	
	timer.timeout.connect(func(): 
		var elapsed_ms = Time.get_ticks_msec() - start_ticks
		var elapsed_seconds = elapsed_ms / 1000.0
		print("FEAGICORE: [3D_SCENE_DEBUG] ⏳ Genome reload still in progress... (", int(elapsed_seconds), "s elapsed)")
		
		# CRITICAL: Check if FEAGI is still alive during reload
		print("FEAGICORE: [3D_SCENE_DEBUG] 🩺 Checking FEAGI health during reload...")
		
		# Quick health check during reload
		if not network or not network.http_API or not network.http_API.address_list:
			print("FEAGICORE: [3D_SCENE_DEBUG] 🚨 Network components unavailable during reload - aborting!")
			reload_aborted = true
			timer.stop()
			return
			
		# Fast health check (same as main system)
		var fast_health_check_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.new()
		fast_health_check_request.full_address = network.http_API.address_list.GET_system_healthCheck
		fast_health_check_request.method = HTTPClient.Method.METHOD_GET
		fast_health_check_request.call_type = APIRequestWorker.CALL_PROCESS_TYPE.SINGLE
		fast_health_check_request.data_to_send_to_FEAGI = null
		fast_health_check_request.http_timeout = 3.0  # Fast timeout
		fast_health_check_request.number_of_retries_allowed = 1  # Only 1 retry
		
		var health_worker: APIRequestWorker = network.http_API.make_HTTP_call(fast_health_check_request)
		await health_worker.worker_done
		
		var health_response: FeagiRequestOutput = health_worker.retrieve_output_and_close()
		if not health_response.success:
			print("FEAGICORE: [3D_SCENE_DEBUG] 🚨 FEAGI went down during genome reload - aborting!")
			reload_aborted = true
			timer.stop()
			# Trigger disconnect state
			_consecutive_health_failures = MAX_HEALTH_FAILURES_BEFORE_DISCONNECT
			network.http_API._request_state_change(network.http_API.HTTP_HEALTH.NO_CONNECTION)
		else:
			print("FEAGICORE: [3D_SCENE_DEBUG] ✅ FEAGI still healthy - checking if reload is actually needed...")
			
		# SMART CHECK: Maybe we don't need to reload at all!
		var health_data = health_response.decode_response_as_dict()
		if "feagi_session" in health_data and "genome_num" in health_data:
			var current_session = int(health_data["feagi_session"])
			var current_genome_num = int(health_data["genome_num"])
			var cached_session = feagi_local_cache._previous_feagi_session
			var cached_genome_num = feagi_local_cache._previous_genome_num
			
			# Check if genome is actually available and brain is ready
			var genome_available = health_data.get("genome_availability", false)
			var brain_ready = health_data.get("brain_readiness", false)
			
			# Only restore scene if: same session+genome AND genome is actually available AND brain is ready
			if cached_session == current_session and cached_genome_num == current_genome_num and genome_available and brain_ready and current_genome_num > 0:
				print("FEAGICORE: [3D_SCENE_DEBUG] 🎯 Same session (%d), genome (%d), and FEAGI is fully ready - no reload needed!" % [current_session, current_genome_num])
				print("FEAGICORE: [3D_SCENE_DEBUG] 🚀 Skipping reload and directly restoring scene...")
				reload_aborted = true  # Stop the unnecessary reload
				timer.stop()
				
				# Update health cache and transition directly to READY
				feagi_local_cache.update_health_from_FEAGI_dict(health_data)
				_change_genome_state(GENOME_LOAD_STATE.GENOME_READY)
				return
			elif cached_session == current_session and cached_genome_num == current_genome_num:
				print("FEAGICORE: [3D_SCENE_DEBUG] ⚠️  Same session (%d) and genome (%d) but FEAGI not ready (available: %s, ready: %s) - waiting..." % [current_session, current_genome_num, genome_available, brain_ready])
			else:
				print("FEAGICORE: [3D_SCENE_DEBUG] 🔄 Session or genome changed (session: %d→%d, genome: %d→%d) - reload needed" % [cached_session, current_session, cached_genome_num, current_genome_num])
			
			print("FEAGICORE: [3D_SCENE_DEBUG] ✅ Continuing with full genome reload...")
	)
	add_child(timer)
	timer.start()
	
	print("FEAGICORE: [3D_SCENE_DEBUG] Calling requests.reload_genome()...")
	var genome_result = await requests.reload_genome()
	
	timer.queue_free()  # Clean up timer
	
	# Check if reload was aborted due to FEAGI failure during the process
	if reload_aborted:
		print("FEAGICORE: [3D_SCENE_DEBUG] ❌ Genome reload was ABORTED due to FEAGI failure during process")
		print("FEAGICORE: [3D_SCENE_DEBUG] 🔄 System will return to disconnected state and wait for FEAGI recovery")
		return  # Don't transition to GENOME_READY - stay in current state for retry
	
	# Check if reload failed for other reasons
	if not genome_result.success:
		print("FEAGICORE: [3D_SCENE_DEBUG] ❌ Genome reload FAILED")
		if genome_result.has_timed_out:
			print("FEAGICORE: [3D_SCENE_DEBUG] - Reason: Request timed out")
		elif genome_result.has_errored:
			print("FEAGICORE: [3D_SCENE_DEBUG] - Reason: HTTP error occurred")
		else:
			print("FEAGICORE: [3D_SCENE_DEBUG] - Reason: Unknown error")
		print("FEAGICORE: [3D_SCENE_DEBUG] 🔄 Will retry when conditions improve")
		return  # Don't transition to GENOME_READY
	
	print("FEAGICORE: [3D_SCENE_DEBUG] ✅ requests.reload_genome() completed successfully")
	
	# DEBUG: Check what we actually loaded
	print("FEAGICORE: [3D_SCENE_DEBUG] 🔍 Genome reload debug info:")
	print("  - Cortical areas loaded: %d" % feagi_local_cache.cortical_areas.available_cortical_areas.size())
	print("  - Brain regions loaded: %d" % feagi_local_cache.brain_regions.available_brain_regions.size())
	print("  - Root region available: %s" % feagi_local_cache.brain_regions.is_root_available())
	if feagi_local_cache.brain_regions.is_root_available():
		var root = feagi_local_cache.brain_regions.get_root_region()
		print("  - Root region name: %s" % root.friendly_name)
	else:
		print("  - ❌ NO ROOT REGION FOUND - This explains why 3D scene can't initialize!")
	
	print("FEAGICORE: [3D_SCENE_DEBUG] Transitioning to GENOME_READY state...")
	_change_genome_state(GENOME_LOAD_STATE.GENOME_READY)
	print("FEAGICORE: [3D_SCENE_DEBUG] ✅ Successfully transitioned to GENOME_READY")

func _if_brain_readiness_or_genome_availability_changes(available: bool, ready: bool) -> void:
	print("FEAGICORE: [3D_SCENE_DEBUG] Genome/brain state changed - genome_availability: ", available, ", brain_readiness: ", ready)
	
	if !available:
		print("FEAGICORE: [3D_SCENE_DEBUG] Genome no longer available - transitioning to NO_GENOME_AVAILABLE")
		_change_genome_state(GENOME_LOAD_STATE.NO_GENOME_AVAILABLE)
		return
	if ready:
		print("FEAGICORE: [3D_SCENE_DEBUG] Brain is ready - transitioning to GENOME_READY")
		_change_genome_state(GENOME_LOAD_STATE.GENOME_READY)
	else:
		print("FEAGICORE: [3D_SCENE_DEBUG] Brain not ready - transitioning to GENOME_PROCESSING")
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
	print("🔄 FEAGICORE: _recieve_genome_reset_request() called - current state: ", GENOME_LOAD_STATE.keys()[genome_load_state])
	
	# Allow reload from READY or PROCESSING states (PROCESSING means we had a genome before)
	if genome_load_state == GENOME_LOAD_STATE.GENOME_READY or genome_load_state == GENOME_LOAD_STATE.GENOME_PROCESSING:
		print("✅ FEAGICORE: Triggering genome reload from %s state" % GENOME_LOAD_STATE.keys()[genome_load_state])
		_change_genome_state(GENOME_LOAD_STATE.GENOME_RELOADING)
	else:
		print("⚠️ FEAGICORE: Ignoring genome reset request - current state doesn't warrant reload: %s" % GENOME_LOAD_STATE.keys()[genome_load_state])
		print("   💡 NOTE: Reset requests only trigger from GENOME_READY or GENOME_PROCESSING states")

func _on_genome_refresh_needed(feagi_session: int, genome_num: int, reason: String):
	print("🔄 FEAGICORE: Health check detected genome refresh needed - %s" % reason)
	print("   📊 Session: %d, Genome: %d, Current state: %s" % [feagi_session, genome_num, GENOME_LOAD_STATE.keys()[genome_load_state]])
	
	# Allow force reloads to override stuck GENOME_RELOADING state
	if genome_load_state == GENOME_LOAD_STATE.GENOME_RELOADING:
		if "cache empty" in reason or "STUCK RELOAD" in reason:
			print("🚨 FEAGICORE: FORCE RELOAD detected - restarting stuck genome reload")
			print("   🔧 Current GENOME_RELOADING state will be reset and restarted")
			# Continue to reload logic below instead of returning
		else:
			print("⚠️ FEAGICORE: Already in GENOME_RELOADING state - ignoring duplicate refresh request")
			return
	
	# Health check-triggered reloads are different from user-initiated reloads
	# They can happen from any state when FEAGI reports genome is ready but cache is empty
	match genome_load_state:
		GENOME_LOAD_STATE.NO_GENOME_AVAILABLE:
			print("✅ FEAGICORE: Empty cache detected - triggering genome reload from NO_GENOME_AVAILABLE state")
			_change_genome_state(GENOME_LOAD_STATE.GENOME_RELOADING)
		GENOME_LOAD_STATE.GENOME_READY, GENOME_LOAD_STATE.GENOME_PROCESSING:
			print("✅ FEAGICORE: Triggering genome reload from %s state" % GENOME_LOAD_STATE.keys()[genome_load_state])
			_change_genome_state(GENOME_LOAD_STATE.GENOME_RELOADING)
		GENOME_LOAD_STATE.GENOME_RELOADING:
			print("🚨 FEAGICORE: FORCE RESTARTING stuck genome reload")
			_change_genome_state(GENOME_LOAD_STATE.GENOME_RELOADING)  # This will restart the process
		GENOME_LOAD_STATE.UNKNOWN:
			print("⚠️ FEAGICORE: Cannot reload from UNKNOWN state - connection issues?")
		_:
			print("⚠️ FEAGICORE: Unexpected state %s for genome refresh" % GENOME_LOAD_STATE.keys()[genome_load_state])

#endregion
