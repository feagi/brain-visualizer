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

## Used to validate if a potential connection to FEAGI would be viable. Activates [FEAGIHTTPAPI] to do a healthcheck to verify.
## If viable, proceeds with connection. Returns if sucessful
func attempt_connection(feagi_endpoint_details: FeagiEndpointDetails) -> bool:
	if _connection_state != CONNECTION_STATE.DISCONNECTED:
		push_error("FEAGI NETWORK: Unable to commence a new connection when one is active in some form already!")
		return false
	
	# Store endpoint details for use throughout the connection lifecycle
	_feagi_endpoint_details = feagi_endpoint_details
	
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
		push_error("FEAGI NETWORK: Unable to commence a new connection as there was no HTTP response at endpoint %s" % _feagi_endpoint_details.full_http_address)
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
		# Skip to the end - signals will be connected at the bottom of the function
		# (same as normal WebSocket flow after line ~110)
		print("FEAGI NETWORK: Connecting to HTTP health signals for ongoing monitoring")
		http_API.FEAGI_http_health_changed.connect(_HTTP_health_changed)
		# Note: We still connect to WS health signals in case code tries to use WS
		# but we won't actively initiate WS connections when using SHM
		print("FEAGI NETWORK: Connecting to websocket health signals for monitoring (SHM mode)")
		websocket_API.FEAGI_socket_health_changed.connect(_WS_health_changed)
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
		return false
	
	# both HTTP and WS are functioning! We are good to go!
	# connect signals for future changes
	print("FEAGI NETWORK: Connecting to HTTP health signals for ongoing monitoring") 
	http_API.FEAGI_http_health_changed.connect(_HTTP_health_changed)
	print("FEAGI NETWORK: Connecting to websocket health signals for ongoing monitoring")
	websocket_API.FEAGI_socket_health_changed.connect(_WS_health_changed)
	
	return true

func _call_register_agent_for_shm() -> bool:
	# Build registration payload
	var payload := {
		"agent_type": "visualizer",
		"agent_id": "brain-visualizer",
		"agent_data_port": 0,
		"agent_version": ProjectSettings.get_setting("application/config/version", "dev"),
		"controller_version": ProjectSettings.get_setting("application/config/version", "dev"),
		# Provide capability with explicit refresh rate to align with FEAGI rate processing
		"capabilities": {"visualization": {"rate_hz": 30.0, "enabled": true}},
		"metadata": {"request_shared_memory": true}
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
		print("𒓉 [REG] Agent register failed or timed out; will continue without SHM auto-config")
		print("𒓉 [REG] Error? ", out.has_errored, ", Timeout? ", out.has_timed_out)
		if out.has_errored:
			var body := out.decode_response_as_dict()
			print("𒓉 [REG] Error body: ", body)
		return false
	var resp := out.decode_response_as_dict()
	print("𒓉 [REG] Response: ", resp)
	
	# Check registration success and transport negotiation
	if resp.get("status", "") == "success":
		# NEW: Check transport negotiation from registration response
		if resp.has("transport") and typeof(resp["transport"]) == TYPE_DICTIONARY:
			var transport: Dictionary = resp["transport"]
			var recommended: String = transport.get("recommended", "")
			var available: Array = transport.get("available", [])
			
			print("𒓉 [TRANSPORT] Available transports: ", available)
			print("𒓉 [TRANSPORT] Recommended: ", recommended)
			
			# If SHM is recommended, use it directly
			if recommended == "shm" and transport.has("shm_paths"):
				var shm_paths: Dictionary = transport["shm_paths"]
				if shm_paths.has("visualization"):
					var viz_path: String = str(shm_paths["visualization"])
					print("𒓉 [TRANSPORT] ✅ Using SHM transport: ", viz_path)
					OS.set_environment("FEAGI_VIZ_NEURONS_SHM", viz_path)
					
					# Enable SHM visualization and SKIP WebSocket connection
					if websocket_API and websocket_API.has_method("enable_shared_memory_visualization"):
						# CRITICAL: Enable processing so SHM polling happens in _process()
						websocket_API.process_mode = Node.PROCESS_MODE_INHERIT
						websocket_API.enable_shared_memory_visualization(viz_path)
						print("𒓉 [TRANSPORT] ✅ SHM visualization enabled, WebSocket will be skipped")
					return true  # Success - using SHM, no need for WebSocket
			
			# If WebSocket is recommended (via bridge)
			elif recommended == "websocket":
				if transport.has("websocket") and typeof(transport["websocket"]) == TYPE_DICTIONARY:
					var ws_info: Dictionary = transport["websocket"]
					var ws_host: String = ws_info.get("host", "127.0.0.1")
					var ws_port: int = int(ws_info.get("port", 9050))
					var bridge_address: String = "ws://%s:%d" % [ws_host, ws_port]
					print("𒓉 [TRANSPORT] Using WebSocket transport via bridge: ", bridge_address)
					# Update the WebSocket address to point to the bridge
					if _feagi_endpoint_details:
						_feagi_endpoint_details.full_websocket_address = bridge_address
				else:
					print("𒓉 [TRANSPORT] Using WebSocket transport via bridge (default)")
				# WebSocket connection will proceed normally below with updated address
				return false
			
			# If ZMQ is recommended (direct)
			elif recommended == "zmq":
				print("𒓉 [TRANSPORT] Direct ZMQ transport recommended (not currently supported in BV)")
				# BV doesn't support direct ZMQ, will fall back to WebSocket
				return false
	
	# Default: SHM not available, fall back to WebSocket
	return false
	
## Completely disconnect all networking systems from FEAGI
func disconnect_networking() -> void:
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
			# Ensure everything is disconnected
			# NOTE: These APIs will not emit disconnection signals from this
			http_API.disconnect_http()
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
