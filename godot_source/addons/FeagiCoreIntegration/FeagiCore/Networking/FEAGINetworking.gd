extends Node
class_name FEAGINetworking
## Handles All Networking to and from FEAGI
const TRANSPORT_DEBUG_REV: String = "ws-endpoint-resolver-rev-12"

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
var _heartbeat_interval: float = 5.0  # Send heartbeat every 5 seconds to provide margin against 30s liveness timeout.
var _reconnect_timer: Timer = null
var _reconnect_in_progress: bool = false
var _transport_registration_failed: bool = false

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
	_transport_registration_failed = false
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
	
	# REST registration is deprecated; transport setup is now resolved without REST calls.
	print("FEAGI NETWORK: Preparing transport (REST registration disabled)...")
	var shm_enabled: bool = await _register_agent_via_transport()
	
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
		
		return true

	if _transport_registration_failed:
		_connection_state = CONNECTION_STATE.DISCONNECTED
		connection_state_changed.emit(CONNECTION_STATE.INITIAL_HTTP_PROBING, CONNECTION_STATE.DISCONNECTED)
		push_error("FEAGI NETWORK: Transport registration failed; refusing direct WebSocket fallback. Ensure WS registration endpoint is reachable.")
		_start_reconnect_loop()
		return false
	
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

## Deprecated: REST agent registration is disabled.
func _get_registration_auth_token_b64() -> String:
	return ""

## Deprecated: REST agent registration is disabled.
func _normalize_agent_descriptor_b64(b64: String) -> String:
	return b64

func _register_agent_via_transport() -> bool:
	# REST registration is no longer supported. Register via transport-specific client.
	print("𒓉 [TRANSPORT] Resolver revision: ", TRANSPORT_DEBUG_REV)
	print("𒓉 [TRANSPORT] Registering visualization agent via WebSocket transport")
	# STEP 1: Query FEAGI's burst frequency
	var feagi_hz = await _get_feagi_burst_frequency()
	if feagi_hz <= 0.0:
		print("𒓉 [TRANSPORT] ⚠️ Failed to get FEAGI burst frequency, defaulting to 20 Hz")
		feagi_hz = 20.0
	
	# STEP 2: Calculate target rate = min(feagi_frequency, 20)
	var requested_hz = min(feagi_hz, 20.0)
	print("𒓉 [TRANSPORT] FEAGI running at %.1f Hz, BV target %.1f Hz (capped at 20 Hz)" % [feagi_hz, requested_hz])
	# Ensure SHM polling has a deterministic rate.
	set_meta("_negotiated_viz_hz", requested_hz)
	# SHM may already be active from environment variables consumed by FEAGIWebSocketAPI.
	if websocket_API and websocket_API.get("_use_shared_mem"):
		print("𒓉 [TRANSPORT] SHM already active via environment configuration")
		return true

	# Perform transport registration through Rust extension (no REST endpoint).
	if not ClassDB.class_exists("FeagiAgentClient"):
		push_warning("𒓉 [TRANSPORT] FeagiAgentClient extension unavailable; falling back to configured WebSocket endpoint.")
		return false

	var agent_client = ClassDB.instantiate("FeagiAgentClient")
	if agent_client == null:
		push_warning("𒓉 [TRANSPORT] Failed to instantiate FeagiAgentClient; falling back to configured WebSocket endpoint.")
		return false

	var resolved_ws_endpoints: Dictionary = await _resolve_ws_endpoints()
	print("𒓉 [TRANSPORT] Resolved WS endpoints (%s): %s" % [TRANSPORT_DEBUG_REV, resolved_ws_endpoints])
	var registration_ws_url: String = str(resolved_ws_endpoints.get("registration", "")).strip_edges()
	var advertised_viz_ws_url: String = str(resolved_ws_endpoints.get("visualization", "")).strip_edges()
	var configured_viz_ws_url: String = str(_feagi_endpoint_details.full_websocket_address).strip_edges()
	# Some FEAGI builds may publish swapped endpoint labels in connection_info.
	# If "registration" points to our configured visualization URL and an alternate
	# visualization endpoint is advertised, use that alternate as the registration target.
	if registration_ws_url != "" \
		and advertised_viz_ws_url != "" \
		and registration_ws_url == configured_viz_ws_url \
		and advertised_viz_ws_url != configured_viz_ws_url:
		push_warning(
			"𒓉 [TRANSPORT] connection_info appears to expose swapped WS labels; using %s for registration instead of %s." % [
				advertised_viz_ws_url, registration_ws_url
			]
		)
		registration_ws_url = advertised_viz_ws_url
	if registration_ws_url.strip_edges() == "":
		_transport_registration_failed = true
		push_error("𒓉 [TRANSPORT] Could not resolve WebSocket registration endpoint from /v1/network/connection_info.")
		return false
	print("𒓉 [TRANSPORT] Using WS registration endpoint: ", registration_ws_url)
	set_meta("_registration_ws_url", registration_ws_url)
	var descriptor_b64 := ""
	var auth_token_b64 := ""
	if FeagiCore.feagi_settings != null:
		descriptor_b64 = str(FeagiCore.feagi_settings.agent_descriptor_b64).strip_edges()
		auth_token_b64 = str(FeagiCore.feagi_settings.auth_token_b64).strip_edges()

	var registration_output: Dictionary
	if agent_client.has_method("register_via_websocket_with_heartbeat"):
		registration_output = agent_client.register_via_websocket_with_heartbeat(
			registration_ws_url,
			descriptor_b64,
			auth_token_b64,
			_heartbeat_interval
		)
	else:
		push_warning("𒓉 [TRANSPORT] feagi_agent_client extension is running legacy API; using default heartbeat interval.")
		registration_output = agent_client.register_via_websocket(
			registration_ws_url,
			descriptor_b64,
			auth_token_b64
		)
	print("𒓉 [TRANSPORT] registration_output: ", registration_output)
	if not bool(registration_output.get("success", false)):
		var reg_error: String = str(registration_output.get("error", "unknown registration error"))
		# FEAGI may still consider this client registered (e.g. re-registration or duplicate call).
		# Use advertised/configured visualization endpoint and continue.
		if "already registered" in reg_error.to_lower() or "client already" in reg_error.to_lower():
			print("𒓉 [TRANSPORT] Client already registered on FEAGI; using advertised/configured visualization endpoint.")
			if advertised_viz_ws_url != "":
				_feagi_endpoint_details.full_websocket_address = advertised_viz_ws_url
				print("𒓉 [TRANSPORT] Using advertised visualization endpoint: ", advertised_viz_ws_url)
			elif configured_viz_ws_url != "":
				_feagi_endpoint_details.full_websocket_address = configured_viz_ws_url
				print("𒓉 [TRANSPORT] Using configured visualization endpoint: ", configured_viz_ws_url)
			else:
				_transport_registration_failed = true
				push_error("𒓉 [TRANSPORT] Already registered but no visualization URL available.")
				return false
			# Return false so caller connects WebSocket for visualization (we did not enable SHM).
			return false
		_transport_registration_failed = true
		push_error("𒓉 [TRANSPORT] Transport registration failed (%s)." % reg_error)
		return false

	var registered_ws_url := str(registration_output.get("visualization_ws_url", "")).strip_edges()
	if registered_ws_url != "":
		if advertised_viz_ws_url != "" and registered_ws_url != advertised_viz_ws_url:
			push_warning(
				"𒓉 [TRANSPORT] Registration returned visualization endpoint %s, but FEAGI advertises %s. Using advertised visualization endpoint." % [
					registered_ws_url, advertised_viz_ws_url
				]
			)
			_feagi_endpoint_details.full_websocket_address = advertised_viz_ws_url
			print("𒓉 [TRANSPORT] Using advertised visualization endpoint: ", advertised_viz_ws_url)
		else:
			_feagi_endpoint_details.full_websocket_address = registered_ws_url
			print("𒓉 [TRANSPORT] Registered visualization endpoint: ", registered_ws_url)
	elif advertised_viz_ws_url != "":
		_feagi_endpoint_details.full_websocket_address = advertised_viz_ws_url
		print("𒓉 [TRANSPORT] Using advertised visualization endpoint: ", advertised_viz_ws_url)
	else:
		push_warning("𒓉 [TRANSPORT] Registration succeeded without visualization_ws_url; using configured WebSocket endpoint.")
		return false

	var registered_agent_id := str(registration_output.get("agent_id_b64", "")).strip_edges()
	if registered_agent_id != "":
		set_meta("_registered_agent_id_b64", registered_agent_id)
		print("𒓉 [TRANSPORT] Registered agent_id: ", registered_agent_id)

	return false

func _resolve_ws_endpoints() -> Dictionary:
	# Resolve WebSocket registration and visualization endpoints from FEAGI network connection info.
	# Use direct HTTPClient polling to avoid signal ordering/race issues during startup.
	var addr_list = http_API.get("address_list")
	if addr_list == null:
		print("𒓉 [TRANSPORT] _resolve_ws_endpoints early return: address_list is null")
		return {}
	var info_url: StringName = addr_list.GET_network_connection_info
	print("𒓉 [TRANSPORT] Resolving WS endpoints from: ", info_url)

	var url_text: String = str(info_url).strip_edges()
	var url_re := RegEx.new()
	var compile_ok: Error = url_re.compile("^http://([^/:]+):(\\d+)(/.*)$")
	if compile_ok != OK:
		print("𒓉 [TRANSPORT] _resolve_ws_endpoints early return: failed to compile URL regex")
		return {}
	var match: RegExMatch = url_re.search(url_text)
	if match == null:
		print("𒓉 [TRANSPORT] _resolve_ws_endpoints early return: invalid URL format: ", url_text)
		return {}
	var host: String = match.get_string(1)
	var port: int = int(match.get_string(2))
	var path: String = match.get_string(3)

	var client := HTTPClient.new()
	var connect_err: Error = client.connect_to_host(host, port)
	if connect_err != OK:
		print("𒓉 [TRANSPORT] _resolve_ws_endpoints early return: connect_to_host failed=", connect_err)
		return {}

	var started_ms: int = Time.get_ticks_msec()
	while client.get_status() in [HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_CONNECTING]:
		var poll_err := client.poll()
		if poll_err != OK:
			print("𒓉 [TRANSPORT] _resolve_ws_endpoints early return: poll(connect) failed=", poll_err)
			client.close()
			return {}
		if Time.get_ticks_msec() - started_ms > 3000:
			print("𒓉 [TRANSPORT] _resolve_ws_endpoints early return: connect timeout exceeded 3s")
			client.close()
			return {}
		await get_tree().process_frame

	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		print("𒓉 [TRANSPORT] _resolve_ws_endpoints early return: client not connected, status=", client.get_status())
		client.close()
		return {}

	var request_err: Error = client.request(HTTPClient.METHOD_GET, path, http_API.get_headers())
	if request_err != OK:
		print("𒓉 [TRANSPORT] _resolve_ws_endpoints early return: request() failed=", request_err)
		client.close()
		return {}

	var request_started_ms: int = Time.get_ticks_msec()
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		var req_poll_err := client.poll()
		if req_poll_err != OK:
			print("𒓉 [TRANSPORT] _resolve_ws_endpoints early return: poll(request) failed=", req_poll_err)
			client.close()
			return {}
		if Time.get_ticks_msec() - request_started_ms > 3000:
			print("𒓉 [TRANSPORT] _resolve_ws_endpoints early return: request timeout exceeded 3s")
			client.close()
			return {}
		await get_tree().process_frame

	var response_code: int = client.get_response_code()
	var body := PackedByteArray()
	if client.has_response():
		var body_started_ms: int = Time.get_ticks_msec()
		while client.get_status() == HTTPClient.STATUS_BODY:
			var body_poll_err := client.poll()
			if body_poll_err != OK:
				print("𒓉 [TRANSPORT] _resolve_ws_endpoints early return: poll(body) failed=", body_poll_err)
				client.close()
				return {}
			var chunk: PackedByteArray = client.read_response_body_chunk()
			if chunk.size() > 0:
				body.append_array(chunk)
			if Time.get_ticks_msec() - body_started_ms > 3000:
				print("𒓉 [TRANSPORT] _resolve_ws_endpoints early return: body timeout exceeded 3s")
				client.close()
				return {}
			await get_tree().process_frame
	client.close()

	var errored: bool = response_code != 200
	print("𒓉 [TRANSPORT] connection_info response: code=%s errored=%s body_bytes=%s" % [
		response_code, errored, body.size()
	])
	if errored:
		print("𒓉 [TRANSPORT] _resolve_ws_endpoints early return: non-200 response_code=", response_code)
		return {}

	var raw_response: String = body.get_string_from_utf8()
	var raw_preview: String = raw_response.replace("\u0000", "").strip_edges()
	if raw_preview.length() > 240:
		raw_preview = raw_preview.substr(0, 240)
	print("𒓉 [TRANSPORT] connection_info raw preview: ", raw_preview)
	var extracted := _extract_ws_endpoints_from_raw_response(raw_response)
	if not extracted.is_empty():
		print("𒓉 [TRANSPORT] Resolved WS endpoints from raw response: ", extracted)
		return extracted
	var parser := JSON.new()
	var parse_err: Error = parser.parse(raw_response.replace("\u0000", "").strip_edges())
	var info: Dictionary = {}
	if parse_err == OK and parser.data is Dictionary:
		info = parser.data
	print("𒓉 [TRANSPORT] connection_info parsed keys: ", info.keys() if not info.is_empty() else [])
	if info.is_empty():
		print("𒓉 [TRANSPORT] _resolve_ws_endpoints early return: parsed info empty")
		push_warning("𒓉 [TRANSPORT] connection_info decode returned empty dictionary. response_code=%s body_bytes=%s parse_err=%s" % [response_code, body.size(), parse_err])
		return {}
	if not info.has("websocket") or typeof(info["websocket"]) != TYPE_DICTIONARY:
		print("𒓉 [TRANSPORT] _resolve_ws_endpoints early return: missing websocket dictionary")
		return {}
	var ws_cfg: Dictionary = info["websocket"]
	if not ws_cfg.get("enabled", false):
		print("𒓉 [TRANSPORT] _resolve_ws_endpoints early return: websocket transport disabled")
		return {}
	var ws_endpoints: Dictionary = {}
	if ws_cfg.has("endpoints") and typeof(ws_cfg["endpoints"]) == TYPE_DICTIONARY:
		ws_endpoints = ws_cfg["endpoints"]
	var ws_ports: Dictionary = {}
	if ws_cfg.has("ports") and typeof(ws_cfg["ports"]) == TYPE_DICTIONARY:
		ws_ports = ws_cfg["ports"]
	var ws_host: String = str(ws_cfg.get("host", "")).strip_edges()
	var registration_url: String = str(ws_endpoints.get("registration", "")).strip_edges()
	var visualization_url: String = str(ws_endpoints.get("visualization", "")).strip_edges()
	if registration_url == "" and ws_host != "":
		var registration_port: int = int(ws_ports.get("registration", 0))
		if registration_port > 0:
			registration_url = "ws://%s:%d" % [ws_host, registration_port]
	if visualization_url == "" and ws_host != "":
		var visualization_port: int = int(ws_ports.get("visualization", 0))
		if visualization_port > 0:
			visualization_url = "ws://%s:%d" % [ws_host, visualization_port]
	return {
		"registration": registration_url,
		"visualization": visualization_url
	}

func _extract_ws_endpoints_from_raw_response(raw_response: String) -> Dictionary:
	var cleaned: String = raw_response.replace("\u0000", "").strip_edges()
	if cleaned == "":
		return {}
	var reg := RegEx.new()
	if reg.compile("\"registration\"\\s*:\\s*\"(ws://[^\"]+)\"") != OK:
		return {}
	var viz := RegEx.new()
	if viz.compile("\"visualization\"\\s*:\\s*\"(ws://[^\"]+)\"") != OK:
		return {}
	var reg_match: RegExMatch = reg.search(cleaned)
	var viz_match: RegExMatch = viz.search(cleaned)
	var registration_url: String = reg_match.get_string(1).strip_edges() if reg_match != null else ""
	var visualization_url: String = viz_match.get_string(1).strip_edges() if viz_match != null else ""
	if registration_url == "" and visualization_url == "":
		return {}
	return {
		"registration": registration_url,
		"visualization": visualization_url
	}
	
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
	
	# Avoid no-op emissions so UI/state listeners do not process duplicate transitions.
	if prev_state == new_state:
		return
	_connection_state = new_state
	connection_state_changed.emit(prev_state, new_state)


## Start sending periodic heartbeats to FEAGI
func start_heartbeat() -> void:
	# Agent heartbeat over REST is deprecated and intentionally disabled.
	return


## Stop sending heartbeats to FEAGI
func stop_heartbeat() -> void:
	var registered_agent_id := ""
	if has_meta("_registered_agent_id_b64"):
		registered_agent_id = str(get_meta("_registered_agent_id_b64")).strip_edges()
	var registration_ws_url := ""
	if has_meta("_registration_ws_url"):
		registration_ws_url = str(get_meta("_registration_ws_url")).strip_edges()
	if registered_agent_id != "" and ClassDB.class_exists("FeagiAgentClient"):
		var agent_client = ClassDB.instantiate("FeagiAgentClient")
		if agent_client != null:
			agent_client.stop_heartbeat_for_agent(registered_agent_id)
			if registration_ws_url != "":
				agent_client.deregister_via_websocket(registration_ws_url, registered_agent_id)
	if _heartbeat_timer != null:
		_heartbeat_timer.stop()
		if _heartbeat_timer.timeout.is_connected(_send_heartbeat):
			_heartbeat_timer.timeout.disconnect(_send_heartbeat)
		_heartbeat_timer.queue_free()
		_heartbeat_timer = null


## Send a single heartbeat to FEAGI
func _send_heartbeat() -> void:
	# Agent heartbeat over REST is deprecated and intentionally disabled.
	return

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
