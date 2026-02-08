extends Node
class_name FEAGINetworking
## Handles All Networking to and from FEAGI

# NOTE: For most signals, get them from http_API and websocket_API directly, no need for duplicates

enum CONNECTION_STATE {
	DISCONNECTED,
	INITIAL_HTTP_PROBING,
	INITIAL_WS_PROBING,
	HEALTHY,
	RETRYING_HTTP,
	RETRYING_WS,
	RETRYING_HTTP_WS
}

enum TRANSPORT_MODE {
	UNKNOWN,
	SHARED_MEMORY,
	WEBSOCKET,
	ZMQ
}

signal connection_state_changed(prev_state: CONNECTION_STATE, current_state: CONNECTION_STATE)
signal genome_reset_request_recieved()


var http_API: FEAGIHTTPAPI = null
var websocket_API: FEAGIWebSocketAPI = null
var connection_state: CONNECTION_STATE:
	get: return _connection_state

var _connection_state: CONNECTION_STATE = CONNECTION_STATE.DISCONNECTED
var _transport_mode: TRANSPORT_MODE = TRANSPORT_MODE.UNKNOWN  # Track which transport is being used
var _feagi_endpoint_details: FeagiEndpointDetails = null  # Store endpoint details for later use
var _heartbeat_timer: Timer = null  # Timer for sending periodic heartbeats to FEAGI
var _heartbeat_interval: float = 15.0  # Send heartbeat every 15 seconds (matches FEAGI's expectation)
var _reconnect_timer: Timer = null
var _reconnect_in_progress: bool = false

func _init():
	http_API = FEAGIHTTPAPI.new()
	http_API.name = "FEAGIHTTPAPI"
	add_child(http_API)

	websocket_API = FEAGIWebSocketAPI.new()
	websocket_API.name = "FEAGIWebSocketAPI"
	websocket_API.process_mode = Node.PROCESS_MODE_DISABLED
	websocket_API.feagi_requesting_reset.connect(func(): 
		print("🔗 NETWORKING: Received feagi_requesting_reset, forwarding to FeagiCore...")
		genome_reset_request_recieved.emit()
		print("✅ NETWORKING: genome_reset_request_recieved signal emitted")
	)
	add_child(websocket_API)
	websocket_API.shm_visualization_enabled.connect(_on_shm_visualization_enabled)

func _on_shm_visualization_enabled(_path: String) -> void:
	# SHM is now active; BV no longer requires WebSocket connectivity for neuron visualization.
	_transport_mode = TRANSPORT_MODE.SHARED_MEMORY
	# Ensure SHM polling runs (it lives in FEAGIWebSocketAPI._process()).
	websocket_API.process_mode = Node.PROCESS_MODE_INHERIT
	# If WS was in retry mode, stop it (reduces log spam / avoids UI disconnect loops).
	websocket_API.disconnect_websocket()
	# If we were waiting on WS, treat connection as healthy (HTTP already validated).
	if _connection_state != CONNECTION_STATE.HEALTHY:
		var prev = _connection_state
		_connection_state = CONNECTION_STATE.HEALTHY
		connection_state_changed.emit(prev, CONNECTION_STATE.HEALTHY)

## Used to validate if a potential connection to FEAGI would be viable. Activates [FEAGIHTTPAPI] to do a healthcheck to verify.
## If viable, proceeds with connection. Returns if sucessful
func attempt_connection(feagi_endpoint_details: FeagiEndpointDetails) -> bool:
	if _connection_state != CONNECTION_STATE.DISCONNECTED:
		push_error("FEAGI NETWORK: Unable to commence a new connection when one is active in some form already!")
		return false
	
	# Store endpoint details for use throughout the connection lifecycle
	_feagi_endpoint_details = feagi_endpoint_details
	_stop_reconnect_loop()
	
	# We dont want prior connections from HTTP or WS to set off other code paths, remove signal connections
	if http_API.FEAGI_http_health_changed.is_connected(_HTTP_health_changed):
		http_API.FEAGI_http_health_changed.disconnect(_HTTP_health_changed)
	if websocket_API.FEAGI_socket_health_changed.is_connected(_WS_health_changed):
		print("FEAGI NETWORK: Disconnecting previous websocket health signal connection")
		websocket_API.FEAGI_socket_health_changed.disconnect(_WS_health_changed)
	
	print("FEAGI NETWORK: Attempting to load new connection...")
	
	# Check HTTP connectivity
	_connection_state = CONNECTION_STATE.INITIAL_HTTP_PROBING
	connection_state_changed.emit(CONNECTION_STATE.DISCONNECTED,  CONNECTION_STATE.INITIAL_HTTP_PROBING)
	print("FEAGI NETWORK: Testing HTTP endpoint at %s" % _feagi_endpoint_details.full_http_address)
	http_API.setup(_feagi_endpoint_details.full_http_address, _feagi_endpoint_details.header)
	http_API.confirm_connectivity() # NOTE: confirm_connectivity will never allow its health to be set as retrying, so we dont neet to worry about that
	
	await http_API.FEAGI_http_health_changed
	
	if http_API.http_health in [http_API.HTTP_HEALTH.NO_CONNECTION, http_API.HTTP_HEALTH.ERROR]:
		_connection_state = CONNECTION_STATE.DISCONNECTED
		connection_state_changed.emit(CONNECTION_STATE.INITIAL_HTTP_PROBING, CONNECTION_STATE.DISCONNECTED)
		push_warning("FEAGI NETWORK: Unable to commence a new connection as there was no HTTP response at endpoint %s" % _feagi_endpoint_details.full_http_address)
		_start_reconnect_loop()
		return false
	
	# 𒓉 CHANGED: Register FIRST to get transport negotiation, THEN connect
	print("FEAGI NETWORK: Registering with FEAGI to negotiate transport...")
	var shm_enabled: bool = await _call_register_agent_for_shm()
	
	# Check if SHM was already enabled during registration (early return)
	# If so, skip WebSocket connection entirely
	if shm_enabled:
		print("𒓉 [TRANSPORT] SHM enabled during registration - skipping WebSocket connection")
		_transport_mode = TRANSPORT_MODE.SHARED_MEMORY  # Remember we're using SHM
		_connection_state = CONNECTION_STATE.HEALTHY
		connection_state_changed.emit(CONNECTION_STATE.INITIAL_HTTP_PROBING, CONNECTION_STATE.HEALTHY)
		_stop_reconnect_loop()
		# Skip to the end - signals will be connected at the bottom of the function
		# (same as normal WebSocket flow after line ~110)
		print("FEAGI NETWORK: Connecting to HTTP health signals for ongoing monitoring")
		http_API.FEAGI_http_health_changed.connect(_HTTP_health_changed)
		# Note: We still connect to WS health signals in case code tries to use WS
		# but we won't actively initiate WS connections when using SHM
		print("FEAGI NETWORK: Connecting to websocket health signals for monitoring (SHM mode)")
		websocket_API.FEAGI_socket_health_changed.connect(_WS_health_changed)
		
		# Start heartbeat after successful registration
		start_heartbeat()
		
		return true
	
	# No SHM available or not recommended - proceed with WebSocket connection
	_transport_mode = TRANSPORT_MODE.WEBSOCKET  # Remember we're using WebSocket
	_connection_state = CONNECTION_STATE.INITIAL_WS_PROBING
	connection_state_changed.emit(CONNECTION_STATE.INITIAL_HTTP_PROBING, CONNECTION_STATE.INITIAL_WS_PROBING)
	print("FEAGI NETWORK: Testing WS endpoint at %s" % _feagi_endpoint_details.full_websocket_address)
	websocket_API.setup(_feagi_endpoint_details.full_websocket_address)
	websocket_API.process_mode = Node.PROCESS_MODE_INHERIT
	websocket_API.connect_websocket()
	
	# NOTE: Since websocket startup can have its health set to retrying, we stay in a loop until we get a sucess or failure
	while true:
		await websocket_API.FEAGI_socket_health_changed
		if websocket_API.socket_health != websocket_API.WEBSOCKET_HEALTH.RETRYING:
			break
	
	if websocket_API.socket_health == websocket_API.WEBSOCKET_HEALTH.NO_CONNECTION:
		_connection_state = CONNECTION_STATE.DISCONNECTED
		http_API.disconnect_http() # HTTP is active, so lets ensure its disabled
		connection_state_changed.emit(CONNECTION_STATE.INITIAL_WS_PROBING, CONNECTION_STATE.DISCONNECTED)
		push_error("FEAGI NETWORK: Unable to commence a new connection as there was no WS response at endpoint %s" % _feagi_endpoint_details.full_websocket_address)
		_start_reconnect_loop()
		return false
	
	# both HTTP and WS are functioning! We are good to go!
	# CRITICAL: Transition to HEALTHY state now that both HTTP and WebSocket are connected
	print("FEAGI NETWORK: ✅ Both HTTP and WebSocket connected successfully - transitioning to HEALTHY state")
	_connection_state = CONNECTION_STATE.HEALTHY
	connection_state_changed.emit(CONNECTION_STATE.INITIAL_WS_PROBING, CONNECTION_STATE.HEALTHY)
	_stop_reconnect_loop()
	
	# connect signals for future changes
	print("FEAGI NETWORK: Connecting to HTTP health signals for ongoing monitoring") 
	http_API.FEAGI_http_health_changed.connect(_HTTP_health_changed)
	print("FEAGI NETWORK: Connecting to websocket health signals for ongoing monitoring")
	websocket_API.FEAGI_socket_health_changed.connect(_WS_health_changed)
	
	# Start heartbeat after successful registration
	start_heartbeat()
	
	return true

func _get_feagi_burst_frequency() -> float:
	# Query FEAGI's current burst frequency before registration
	var addr_list = http_API.get("address_list")
	if addr_list == null:
		push_warning("𒓉 [REG] HTTP address list not initialized")
		return 0.0
	
	var get_url: StringName = addr_list.GET_burstEngine_simulationTimestep
	var def := APIRequestWorkerDefinition.define_single_GET_call(get_url)
	var worker := http_API.make_HTTP_call(def)
	print("𒓉 [REG] Querying FEAGI burst frequency...")
	await worker.worker_done
	var out := worker.retrieve_output_and_close()
	
	if out.has_errored or out.has_timed_out:
		push_warning("𒓉 [REG] Failed to get burst frequency")
		return 0.0
	
	var timestep_str = out.decode_response_as_string()
	var timestep = timestep_str.to_float()
	
	if timestep <= 0.0:
		push_warning("𒓉 [REG] Invalid timestep: " + timestep_str)
		return 0.0
	
	# Convert timestep to frequency
	var frequency = 1.0 / timestep
	print("𒓉 [REG] ✅ FEAGI burst: %.3fs timestep = %.1f Hz" % [timestep, frequency])
	return frequency

func _call_register_agent_for_shm() -> bool:
	# STEP 1: Query FEAGI's burst frequency BEFORE registration
	var feagi_hz = await _get_feagi_burst_frequency()
	if feagi_hz <= 0.0:
		print("𒓉 [REG] ⚠️ Failed to get FEAGI burst frequency, defaulting to 20 Hz request")
		feagi_hz = 20.0
	
	# STEP 2: Calculate requested rate = min(feagi_frequency, 20)
	# - If FEAGI < 20 Hz → request FEAGI's exact rate
	# - If FEAGI >= 20 Hz → cap at 20 Hz (BV default)
	var requested_hz = min(feagi_hz, 20.0)
	print("𒓉 [REG] FEAGI running at %.1f Hz, BV will request %.1f Hz (capped at 20 Hz)" % [feagi_hz, requested_hz])
	# Ensure SHM polling has a negotiated rate even if registration response omits `rates`
	set_meta("_negotiated_viz_hz", requested_hz)
	
	if FeagiCore.feagi_settings == null or FeagiCore.feagi_settings.agent_descriptor_b64.strip_edges() == "":
		push_error("𒓉 [REG] Missing agent_descriptor_b64 in FEAGI settings; cannot register BV agent")
		return false

	var agent_descriptor_b64: String = FeagiCore.feagi_settings.agent_descriptor_b64

	# Build registration payload (matches FEAGI 2.0 infrastructure agent schema)
	var payload := {
		"agent_type": "visualization",
		"agent_id": agent_descriptor_b64,
		"agent_data_port": 0,
		"agent_version": ProjectSettings.get_setting("application/config/version", "dev"),
		"controller_version": ProjectSettings.get_setting("application/config/version", "dev"),
		"capabilities": {
			"visualization": {
				"visualization_type": "3d_brain",
				"rate_hz": requested_hz,
				"bridge_proxy": false
			}
		},
		"metadata": {"request_shared_memory": false},
		# Default to WebSocket so registration succeeds on all platforms (e.g. Windows where viz SHM is not available).
		# FEAGI will not allocate visualization SHM; BV receives neuron data via WebSocket.
		"chosen_transport": "websocket"
	}
	# Avoid chained member resolution at parse time; guard address_list
	var addr_list = http_API.get("address_list")
	if addr_list == null:
		push_warning("FEAGI NETWORK: HTTP address list not initialized; skipping agent register")
		return false
	var post_url: StringName = addr_list.POST_agent_register
	var def := APIRequestWorkerDefinition.define_single_POST_call(post_url, payload)
	var worker := http_API.make_HTTP_call(def)
	print("𒓉 [REG] Posting /v1/agent/register …")
	await worker.worker_done
	var out := worker.retrieve_output_and_close()
	if out.has_errored or out.has_timed_out:
		print("𒓉 [REG] Agent register failed or timed out")
		print("𒓉 [REG] Error? ", out.has_errored, ", Timeout? ", out.has_timed_out)
		if out.has_errored:
			var body := out.decode_response_as_dict()
			print("𒓉 [REG] Error body: ", body)
			# Check if FEAGI rejected the requested transport
			if out.response_code >= 400 and out.response_code < 500:
				push_error("𒓉 [REG] ❌ FEAGI rejected registration (HTTP %d): %s" % [out.response_code, body.get("message", "Unknown error")])
				if body.has("message") and "transport" in str(body["message"]).to_lower():
					push_error("𒓉 [REG] ❌ Requested transport 'websocket' not supported by FEAGI")
					# TODO: Could retry with different transport or inform user
			return false
		return false
	var resp := out.decode_response_as_dict()
	print("𒓉 [REG] Response: ", resp)
	
	# Extract negotiated visualization rate
	if resp.has("rates") and typeof(resp["rates"]) == TYPE_DICTIONARY:
		var rates: Dictionary = resp["rates"]
		if rates.has("visualization"):
			var viz_rates: Dictionary = rates["visualization"]
			var requested_hz_response = viz_rates.get("requested_hz", 20.0)
			var feagi_hz_from_response = viz_rates.get("feagi_hz", 0.0)
			var negotiated_hz_response = viz_rates.get("negotiated_hz", 20.0)
			print("𒓉 [RATE-NEGO] Visualization rate negotiation:")
			print("  FEAGI burst: %.1f Hz" % feagi_hz_from_response)
			print("  BV requested: %.1f Hz (min(FEAGI, 20))" % requested_hz_response)
			print("  Negotiated: %.1f Hz" % negotiated_hz_response)
			# Store negotiated rate for future use (e.g., timing expectations)
			set_meta("_negotiated_viz_hz", negotiated_hz_response)
	
	# Check registration success and transport negotiation
	if resp.get("status", "") == "success":
		# FEAGI 2.0: Check SHM paths first (legacy compatibility)
		if resp.has("shm_paths") and typeof(resp["shm_paths"]) == TYPE_DICTIONARY:
			var shm_paths: Dictionary = resp["shm_paths"]
			if shm_paths.has("visualization"):
				var viz_path: String = str(shm_paths["visualization"])
				print("𒓉 [TRANSPORT] ✅ Using SHM transport: ", viz_path)
				OS.set_environment("FEAGI_VIZ_NEURONS_SHM", viz_path)
				
				# Enable SHM visualization and SKIP WebSocket connection
				if websocket_API and websocket_API.has_method("enable_shared_memory_visualization"):
					websocket_API.process_mode = Node.PROCESS_MODE_INHERIT
					websocket_API.enable_shared_memory_visualization(viz_path)
					print("𒓉 [TRANSPORT] ✅ SHM visualization enabled, WebSocket will be skipped")
				return true  # Success - using SHM, no need for WebSocket
		
		# FEAGI 2.0: Parse new transports array format
		if resp.has("transports") and typeof(resp["transports"]) == TYPE_ARRAY:
			var transports: Array = resp["transports"]
			var recommended: String = resp.get("recommended_transport", "zmq")
			
			print("𒓉 [TRANSPORT] FEAGI 2.0 multi-transport registration:")
			print("𒓉 [TRANSPORT] Available transports: ", transports.size())
			print("𒓉 [TRANSPORT] Recommended: ", recommended)
			
			# Try to find WebSocket transport
			for transport_option in transports:
				if typeof(transport_option) != TYPE_DICTIONARY:
					continue
				
				var transport_dict: Dictionary = transport_option
				var transport_type: String = transport_dict.get("transport_type", "")
				var enabled: bool = transport_dict.get("enabled", false)
				
				if transport_type == "websocket" and enabled:
					var ws_host: String = transport_dict.get("host", "127.0.0.1")
					var ports: Dictionary = transport_dict.get("ports", {})
					var ws_viz_port: int = int(ports.get("visualization", 9050))
					
					# Use host directly from config (config is source of truth)
					# Config should use 127.0.0.1 for localhost-only connections
					
					print("𒓉 [TRANSPORT] ✅ Found WebSocket transport:")
					print("    Host: ", ws_host)
					print("    Visualization port: ", ws_viz_port)
					
					var ws_address: String = "ws://%s:%d" % [ws_host, ws_viz_port]
					print("𒓉 [TRANSPORT] Connecting to: ", ws_address)
					
					# Update endpoint with FEAGI-provided address
					if _feagi_endpoint_details:
						_feagi_endpoint_details.full_websocket_address = ws_address
					
					# WebSocket connection will proceed with FEAGI-provided address
					return false
			
			# No WebSocket found, check if ZMQ is available
			print("𒓉 [TRANSPORT] No WebSocket transport available from FEAGI")
			print("𒓉 [TRANSPORT] Falling back to default configuration")
			return false
		
		# Legacy format compatibility (old registration response)
		print("𒓉 [TRANSPORT] Legacy registration format detected")
		return false
	
	# Default: SHM not available, fall back to WebSocket
	return false
	
## Completely disconnect all networking systems from FEAGI
func disconnect_networking() -> void:
	# Stop heartbeat before disconnecting
	stop_heartbeat()
	
	# NOTE: Signals will NOT be firing for these for their changing states
	_change_connection_state(CONNECTION_STATE.DISCONNECTED)


func _HTTP_health_changed(_prev_health: FEAGIHTTPAPI.HTTP_HEALTH, current_health: FEAGIHTTPAPI.HTTP_HEALTH) -> void:
	match current_health:
		FEAGIHTTPAPI.HTTP_HEALTH.NO_CONNECTION:
			# Only relevant time this fires is if a retrying worker fails to recover
			# NOTE: Technically also if on "confirm_connectivity" we time out, however the signal to this method is not active during that time
			# Ergo, only path to this is from HTTP_HEALTH.RETRYING
			_change_connection_state(CONNECTION_STATE.DISCONNECTED)
		
		FEAGIHTTPAPI.HTTP_HEALTH.ERROR:
			# NOTE: Not possible to get this since this is only fired during "confirm_connectivity"
			push_error("FEAGI NETWORK: Impossible condition HTTPERROR. Please report this issue if you see it!")
		
		FEAGIHTTPAPI.HTTP_HEALTH.CONNECTABLE:
			# Besides during "confirm_connectivity" (which is never connected to this), this only comes from a retrying worker recovering
			# Only path to this is from HTTP_HEALTH.RETRYING
			_change_connection_state(CONNECTION_STATE.HEALTHY)
		
		FEAGIHTTPAPI.HTTP_HEALTH.RETRYING:
			# Only path to this is from HTTP_HEALTH.CONNECTABLE
			_change_connection_state(CONNECTION_STATE.RETRYING_HTTP)


func _WS_health_changed(_previous_health: FEAGIWebSocketAPI.WEBSOCKET_HEALTH, current_health: FEAGIWebSocketAPI.WEBSOCKET_HEALTH) -> void:
	print("FEAGI NETWORK: 📡 _WS_health_changed received: %s → %s" % [FEAGIWebSocketAPI.WEBSOCKET_HEALTH.keys()[_previous_health], FEAGIWebSocketAPI.WEBSOCKET_HEALTH.keys()[current_health]])
	# In SHM mode, WS connectivity is not required for neuron visualization.
	if _transport_mode == TRANSPORT_MODE.SHARED_MEMORY:
		return
	print("FEAGI NETWORK: Current connection state before WS change: %s" % CONNECTION_STATE.keys()[_connection_state])
	print("FEAGI NETWORK: Current transport mode: %s" % TRANSPORT_MODE.keys()[_transport_mode])
	
	# If we're using Shared Memory, ignore WebSocket health changes
	if _transport_mode == TRANSPORT_MODE.SHARED_MEMORY:
		print("FEAGI NETWORK: ℹ️ Ignoring WebSocket health change - using Shared Memory transport")
		return
	
	match current_health:
		FEAGIWebSocketAPI.WEBSOCKET_HEALTH.NO_CONNECTION:
			print("FEAGI NETWORK: WS NO_CONNECTION → Changing to DISCONNECTED")
			# Only path to this is from WEBSOCKET_HEALTH.RETRYING (again, "confirm_connectivity" has this method disconnected)
			_change_connection_state(CONNECTION_STATE.DISCONNECTED)
		
		FEAGIWebSocketAPI.WEBSOCKET_HEALTH.CONNECTED:
			print("FEAGI NETWORK: WS CONNECTED → Changing to HEALTHY")
			# Only path to this is from WEBSOCKET_HEALTH.RETRYING (again, "confirm_connectivity" has this method disconnected)
			_change_connection_state(CONNECTION_STATE.HEALTHY)
		
		FEAGIWebSocketAPI.WEBSOCKET_HEALTH.RETRYING:
			print("FEAGI NETWORK: WS RETRYING → Changing to RETRYING_WS")
			 # Only path to this is from WEBSOCKET_HEALTH.CONNECTED
			_change_connection_state(CONNECTION_STATE.RETRYING_WS)


func _change_connection_state(new_state: CONNECTION_STATE) -> void:
	var prev_state: CONNECTION_STATE = _connection_state
	
	# NOTE: Due to WS and HTTP possibly failing/recovering at similar times, we may do some silly things between switching from 1 or both them failing in the enum value
	var scanning_state: CONNECTION_STATE = new_state # NOTE: Since we may manipulate new_state, we dont want to mess up the match case
	match(scanning_state):
		CONNECTION_STATE.DISCONNECTED:
			# Either user requested this or something failed
			# Keep HTTP heartbeat alive for auto-reconnect monitoring
			# Only stop WebSocket - HTTP will detect when FEAGI comes back
			print("🔌 [NETWORK] Entering DISCONNECTED - keeping HTTP alive for auto-reconnect")
			# NOTE: These APIs will not emit disconnection signals from this
			# http_API.disconnect_http()  # ← KEEP HTTP ALIVE for session monitoring
			websocket_API.disconnect_websocket()
		CONNECTION_STATE.INITIAL_HTTP_PROBING: # not possible:
			return
		CONNECTION_STATE.INITIAL_WS_PROBING: # not possible:
			return
		CONNECTION_STATE.HEALTHY:
			if prev_state == CONNECTION_STATE.RETRYING_HTTP_WS: # 2 things were broken, one got fixed
				if http_API.http_health != FEAGIHTTPAPI.HTTP_HEALTH.CONNECTABLE:
					new_state = CONNECTION_STATE.RETRYING_HTTP
				elif websocket_API.socket_health != FEAGIWebSocketAPI.WEBSOCKET_HEALTH.CONNECTED:
					new_state = CONNECTION_STATE.RETRYING_WS
		CONNECTION_STATE.RETRYING_HTTP:
			if prev_state == CONNECTION_STATE.RETRYING_WS: # are both actually broken?
				new_state = CONNECTION_STATE.RETRYING_HTTP_WS
		CONNECTION_STATE.RETRYING_WS:
			if prev_state == CONNECTION_STATE.RETRYING_HTTP: # are both actually broken?
				new_state = CONNECTION_STATE.RETRYING_HTTP_WS
	
	_connection_state = new_state
	connection_state_changed.emit(prev_state, new_state)


## Start sending periodic heartbeats to FEAGI
func start_heartbeat() -> void:
	# Stop any existing heartbeat timer
	stop_heartbeat()
	
	# Create and configure heartbeat timer
	_heartbeat_timer = Timer.new()
	_heartbeat_timer.name = "HeartbeatTimer"
	_heartbeat_timer.wait_time = _heartbeat_interval
	_heartbeat_timer.autostart = true
	_heartbeat_timer.timeout.connect(_send_heartbeat)
	add_child(_heartbeat_timer)
	
	print("💗 [HEARTBEAT] Started heartbeat timer (interval: %.1fs)" % _heartbeat_interval)
	
	# Send initial heartbeat immediately
	_send_heartbeat()


## Stop sending heartbeats to FEAGI
func stop_heartbeat() -> void:
	if _heartbeat_timer != null:
		_heartbeat_timer.stop()
		if _heartbeat_timer.timeout.is_connected(_send_heartbeat):
			_heartbeat_timer.timeout.disconnect(_send_heartbeat)
		_heartbeat_timer.queue_free()
		_heartbeat_timer = null
		print("💗 [HEARTBEAT] Stopped heartbeat timer")


## Send a single heartbeat to FEAGI
func _send_heartbeat() -> void:
	# Guard: Ensure HTTP API is available
	if not http_API or http_API.http_health != FEAGIHTTPAPI.HTTP_HEALTH.CONNECTABLE:
		push_warning("💗 [HEARTBEAT] Skipping heartbeat - HTTP not connected")
		return
	
	# Guard: Ensure address list is available
	var addr_list = http_API.get("address_list")
	if addr_list == null:
		push_warning("💗 [HEARTBEAT] Skipping heartbeat - address list not initialized")
		return
	
	if FeagiCore.feagi_settings == null or FeagiCore.feagi_settings.agent_descriptor_b64.strip_edges() == "":
		push_warning("💗 [HEARTBEAT] Missing agent_descriptor_b64; skipping heartbeat")
		return

	var agent_descriptor_b64: String = FeagiCore.feagi_settings.agent_descriptor_b64

	# Build heartbeat payload
	var payload := {
		"agent_id": agent_descriptor_b64
	}
	
	# Send heartbeat (fire and forget - don't await)
	var heartbeat_url: StringName = addr_list.POST_agent_heartbeat
	var def := APIRequestWorkerDefinition.define_single_POST_call(heartbeat_url, payload)
	var worker := http_API.make_HTTP_call(def)
	
	# Optional: Log heartbeat send (can be removed once stable)
	# print("💗 [HEARTBEAT] Sent heartbeat to FEAGI")

## Start auto-reconnect loop while disconnected.
func _start_reconnect_loop() -> void:
	if _reconnect_timer and _reconnect_timer.is_inside_tree() and not _reconnect_timer.is_stopped():
		return
	if FeagiCore.feagi_settings == null:
		push_warning("FEAGI NETWORK: Cannot start reconnect loop - settings not loaded")
		return
	var interval_seconds: float = FeagiCore.feagi_settings.seconds_between_healthcheck_pings
	if _reconnect_timer == null:
		_reconnect_timer = Timer.new()
		_reconnect_timer.name = "ReconnectTimer"
		_reconnect_timer.autostart = false
		_reconnect_timer.one_shot = false
		_reconnect_timer.timeout.connect(_on_reconnect_timer_timeout)
		add_child(_reconnect_timer)
	_reconnect_timer.wait_time = interval_seconds
	_reconnect_timer.start()

## Stop auto-reconnect loop.
func _stop_reconnect_loop() -> void:
	if _reconnect_timer != null:
		_reconnect_timer.stop()

func _on_reconnect_timer_timeout() -> void:
	if _connection_state != CONNECTION_STATE.DISCONNECTED:
		_stop_reconnect_loop()
		return
	if _reconnect_in_progress:
		return
	if _feagi_endpoint_details == null:
		push_warning("FEAGI NETWORK: No endpoint details available for reconnect")
		return
	_reconnect_in_progress = true
	await FeagiCore.attempt_connection_to_FEAGI(_feagi_endpoint_details)
	_reconnect_in_progress = false
