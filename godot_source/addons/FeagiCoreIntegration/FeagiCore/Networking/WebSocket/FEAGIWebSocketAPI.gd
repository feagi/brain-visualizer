extends Node
class_name FEAGIWebSocketAPI

enum WEBSOCKET_HEALTH {
	NO_CONNECTION,
	CONNECTED,
	RETRYING
}

const DEF_SOCKET_INBOUND_BUFFER_SIZE: int = 10000000
const DEF_SOCKET_BUFFER_SIZE: int = 10000000
const DEF_PING_INTERVAL_SECONDS: float = 2.0
const SOCKET_GENOME_UPDATE_FLAG: String = "updated" # FEAGI sends this string via websocket if genome is reloaded / changed
const SOCKET_GENEOME_UPDATE_LATENCY: String = "ping" # TODO DELETE

signal FEAGI_socket_health_changed(previous_health: WEBSOCKET_HEALTH, current_health: WEBSOCKET_HEALTH)
signal FEAGI_socket_retrying_connection(retry_count: int, max_retry_count: int)
signal FEAGI_sent_SVO_data(cortical_ID: StringName, SVO_data: PackedByteArray)
signal FEAGI_sent_direct_neural_points(cortical_ID: StringName, points_data: PackedByteArray)
signal FEAGI_sent_direct_neural_points_bulk(cortical_ID: StringName, x_array: PackedInt32Array, y_array: PackedInt32Array, z_array: PackedInt32Array, p_array: PackedFloat32Array)
signal feagi_requesting_reset()
signal feagi_return_visual_data(SingleRawImage: PackedByteArray)


var socket_health: WEBSOCKET_HEALTH:
	get: return _socket_health

#var _cache_websocket_data: PackedByteArray # outside to try to avoid reallocation penalties # NOTE: Godot doesnt seem to care and reallocates anyways lol
var _socket_web_address: StringName = ""
var _socket: WebSocketPeer
var _socket_health: WEBSOCKET_HEALTH = WEBSOCKET_HEALTH.NO_CONNECTION
var _retry_count: int = 0
var _is_purposfully_disconnecting: bool = false
var _last_connect_time: int = 0  # Track when we last attempted to connect
var _retry_timer_active: bool = false  # Track if a retry timer is already running
var _last_disconnect_time: int = 0  # Track last disconnect to prevent rapid processing
var _temp_genome_ID: float = 0.0
var _temp_genome_num: int = 0

# Missing cortical area handling
var _missing_cortical_areas: Dictionary = {}  # cortical_id -> {last_warning_time, fetch_attempted}
const MISSING_AREA_WARNING_INTERVAL: float = 10.0  # Only warn every 10 seconds per area

# Case-insensitive cortical area mapping cache
var _case_mapping_cache: Dictionary = {}  # lowercase_id -> actual_cached_id

# Rust-based high-performance deserializer
var _rust_deserializer = null
const WASMDecoder = preload("res://Utils/WASMDecoder.gd")

# Queue Type 11 messages on Web until WASM is ready
var _pending_type11: Array = []
var _waiting_for_wasm: bool = false
var _rust_init_attempts: int = 0
const MAX_RUST_INIT_ATTEMPTS := 5

# 𒓉 Shared memory neuron visualization (FEAGI → Brain Visualizer)
var _use_shared_mem: bool = false
var _shm_path: String = ""
var _shm_file: FileAccess = null
var _shm_header_size: int = 256
var _shm_num_slots: int = 0
var _shm_slot_size: int = 0
var _shm_last_seq: int = -1
var _ws_notice_printed: bool = false
var _shm_notice_printed: bool = false
var _ws_notice_deadline_ms: int = 0
var _pending_shm_path: String = ""
var _shm_init_attempts: int = 0
var _shm_init_max_attempts: int = 10
var _shm_no_new_reported: bool = false
var _shm_missed_cycles: int = 0
var _shm_reopen_threshold: int = 12
var _shm_last_error: String = ""
var _shm_attempting: bool = false
var _shm_debug_logs: bool = false

# SHM update rate tracking
var _shm_updates_received: int = 0
var _shm_last_rate_log_time: float = 0.0
var _shm_rate_log_interval: float = 5.0  # Log rate every 5 seconds


func _ready():
	# Initialize platform-specific decoding path
	if OS.has_feature("web"):
		print("🌐 Web build detected: using WASM decoder; native GDExtension is unavailable on Web.")
		# Kick off WASM loader early so it's ready by the time data arrives
		WASMDecoder.ensure_wasm_loaded()
	else:
		# Initialize Rust-based high-performance deserializer (REQUIRED on desktop)
		_init_rust_deserializer()

	# 𒓉 Try to initialize shared memory visualization (env-provided path)
	_init_shm_visualization()
	# Defer WS fallback notice to allow registration to provide SHM path
	_ws_notice_deadline_ms = Time.get_ticks_msec() + 3000
	
	# Reset missing area tracking when genome reloads
	if FeagiCore.feagi_local_cache:
		FeagiCore.feagi_local_cache.cache_reloaded.connect(_on_genome_reloaded)

func _init_rust_deserializer() -> void:
	if _rust_deserializer != null:
		return
	if ClassDB.class_exists("FeagiDataDeserializer"):
		_rust_deserializer = ClassDB.instantiate("FeagiDataDeserializer")
		if _rust_deserializer:
			print("🦀 FEAGI Rust deserializer initialized successfully!")
			return
		else:
			push_error("🦀 CRITICAL: Failed to instantiate FEAGI Rust deserializer!")
			return
	# Class not registered yet – retry a few times to allow GDExtension to finish loading
	_rust_init_attempts += 1
	if _rust_init_attempts <= MAX_RUST_INIT_ATTEMPTS:
		var t := get_tree().create_timer(0.25)
		t.timeout.connect(_init_rust_deserializer)
		return
	push_error("🦀 CRITICAL: FeagiDataDeserializer class not found after retries. Ensure addon is installed and library built (debug/release).")

func _process(_delta: float):
	# 𒓉 Poll SHM for neuron visualization bytes if enabled
	if _use_shared_mem:
		_poll_shm_once()
		if not _shm_notice_printed:
			var fps = Engine.get_frames_per_second()
			print("𒓉 [WS] SHM polling active at ~%d Hz (every frame); path=%s" % [fps, _shm_path])
			_shm_notice_printed = true
	else:
		# Print once to make it obvious we're on WS path, but only after a brief delay
		# and not while we are actively trying to initialize SHM
		if not _ws_notice_printed and _pending_shm_path == "" and not _shm_attempting and Time.get_ticks_msec() >= _ws_notice_deadline_ms:
			if _shm_last_error != "":
				print("𒓉 [WS] Neuron visualization using WebSocket (SHM disabled); last_shm_error=", _shm_last_error)
			else:
				print("𒓉 [WS] Neuron visualization using WebSocket (SHM disabled)")
			_ws_notice_printed = true
	# On Web, flush queued Type 11 packets once WASM is ready
	if OS.has_feature("web") and WASMDecoder.is_wasm_ready() and _pending_type11.size() > 0:
		# Process all queued before polling socket
		for i in range(_pending_type11.size()):
			var qbytes: PackedByteArray = _pending_type11[i]
			var decoded_result: Dictionary = WASMDecoder.decode_type_11(qbytes)
			if decoded_result and decoded_result.has("success") and decoded_result.success == true:
				for cortical_id in decoded_result.areas.keys():
					# Filter out core areas (_death, _power) that can't be visualized
					if cortical_id == "_death" or cortical_id == "_power":
						continue
					var area_data = decoded_result.areas[cortical_id]
					var x_array: PackedInt32Array = PackedInt32Array(area_data.x_array)
					var y_array: PackedInt32Array = PackedInt32Array(area_data.y_array)
					var z_array: PackedInt32Array = PackedInt32Array(area_data.z_array)
					var p_array: PackedFloat32Array = PackedFloat32Array(area_data.p_array)
					FEAGI_sent_direct_neural_points_bulk.emit(cortical_id, x_array, y_array, z_array, p_array)
					var area: AbstractCorticalArea = _get_cortical_area_case_insensitive(cortical_id)
					if area:
						area.FEAGI_set_direct_points_bulk_data(x_array, y_array, z_array, p_array)
					else:
						_handle_missing_cortical_area(cortical_id)
	# Clear queue after processing
	if OS.has_feature("web") and WASMDecoder.is_wasm_ready():
		_pending_type11.clear()

	# 𒓉 Guard: If socket is null (e.g. never connected when using SHM), skip WebSocket polling but continue to SHM polling below
	if not _socket:
		# SHM polling for neuron visualization happens at end of _process()
		# But if we also use SHM for video, that's handled by WindowViewPreviews directly
		return

	_socket.poll()
	match(_socket.get_ready_state()):
		WebSocketPeer.State.STATE_CONNECTING:
			# Currently connecting to feagi, waiting for FEAGI to confirm
			pass
		WebSocketPeer.State.STATE_OPEN:
			# Connection active with FEAGI
			if _socket_health != WEBSOCKET_HEALTH.CONNECTED:
				if _retry_count != 0:
					print("[%s] ✅ [WS] Recovered from retrying state after %d attempts!" % [_get_timestamp(), _retry_count])
					_retry_count = 0
				print("[%s] ✅ [WS] STATE_OPEN detected - current _socket_health: %s" % [_get_timestamp(), WEBSOCKET_HEALTH.keys()[_socket_health]])
				print("[%s] ✅ [WS] Transitioning to CONNECTED state - notifying network layer" % _get_timestamp())
				_set_socket_health(WEBSOCKET_HEALTH.CONNECTED)
			
			while _socket.get_available_packet_count():
				var raw_packet = _socket.get_packet()
				var retrieved_ws_data: PackedByteArray
				var raw_len := raw_packet.size()
				# Detect small text frames (e.g., 'updated', 'ping') and handle without decompress to avoid errors
				if _is_probably_text(raw_packet):
					var text_payload := raw_packet.get_string_from_ascii().strip_edges()
					print("[WS] Text frame: \"", text_payload, "\" len=", raw_len)
					if text_payload == SOCKET_GENOME_UPDATE_FLAG:
						print("[WS] Received genome update flag; emitting reset request")
						feagi_requesting_reset.emit()
						continue
					if text_payload.to_lower() == "ping" or text_payload.to_lower() == "pong":
						# Ignore keepalive pings
						continue
					# Unknown small text message - ignore after logging
					continue
				# Try DEFLATE first (legacy)
				var decompressed := raw_packet.decompress(DEF_SOCKET_BUFFER_SIZE, 1)
				if decompressed.size() > 0:
					retrieved_ws_data = decompressed
					print("[WS] Decompressed packet: raw_len=", raw_len, " -> dec_len=", retrieved_ws_data.size())
				else:
					# Fallback: some FEAGI builds may send uncompressed data over WS
					# Heuristic: treat as uncompressed if it looks like a FEAGI payload (type 1/8/9/10/11)
					if _looks_like_feagi_ws_payload(raw_packet):
						var first_b := -1
						if raw_len > 0:
							first_b = int(raw_packet[0])
						print("[WS] Fallback: treating packet as UNCOMPRESSED. raw_len=", raw_len, ", first_byte=", first_b)
						retrieved_ws_data = raw_packet
					else:
						push_error("FEAGI WebSocket: Decompression failed - received empty or unknown data! raw_len=" + str(raw_len))
						continue
				_process_wrapped_byte_structure(retrieved_ws_data)
				
		WebSocketPeer.State.STATE_CLOSING:
			# Closing connection to FEAGI, waiting for FEAGI to respond to close request
			pass
		WebSocketPeer.State.STATE_CLOSED:
			# Closed Connection to FEAGI
			var current_time = Time.get_ticks_msec()
			var connection_duration = current_time - _last_connect_time
			var is_immediate_failure = connection_duration < 2000  # Less than 2 seconds
			
			# Prevent rapid processing of the same disconnection event
			if current_time - _last_disconnect_time < 1000:  # Less than 1 second since last disconnect
				# Don't spam logs for the same disconnection
				return
			_last_disconnect_time = current_time
			
			print("[%s] 🔌 [WS] STATE_CLOSED detected - purposeful_disconnect: %s, retry_count: %d, duration: %dms, immediate_failure: %s" % 
				[_get_timestamp(), _is_purposfully_disconnecting, _retry_count, connection_duration, is_immediate_failure])
			
			if  _socket.get_available_packet_count() > 0:
				# There was some remenant data
				_socket.get_packet().decompress(DEF_SOCKET_BUFFER_SIZE, 1)
			#TODO FeagiEvents.retrieved_visualization_data.emit(str_to_var(_cache_websocket_data.get_string_from_ascii())) # Add to erase neurons
			if _is_purposfully_disconnecting:
				print("[%s] 🔌 [WS] Purposeful disconnect - stopping process" % _get_timestamp())
				_is_purposfully_disconnecting = false
				set_process(false)
				return
			
			# If we've had too many immediate failures, give up faster
			if is_immediate_failure and _retry_count > 10:
				print("[%s] ❌ [WS] Too many immediate failures - FEAGI websocket likely not available" % _get_timestamp())
				print("[%s] 🔌 [WS] Notifying network layer about websocket failure" % _get_timestamp())
				push_error("FEAGI Websocket: Repeated immediate failures - websocket service may be down!")
				_set_socket_health(WEBSOCKET_HEALTH.NO_CONNECTION)
				set_process(false)
				return
			
			# Try to retry the WS connection to save it
			if _retry_count < FeagiCore.feagi_settings.number_of_times_to_retry_WS_connections:
				print("[%s] 🔄 [WS] Attempting retry %d / %d" % [_get_timestamp(), _retry_count + 1, FeagiCore.feagi_settings.number_of_times_to_retry_WS_connections])
				if _socket_health != WEBSOCKET_HEALTH.RETRYING:
					print("[%s] 🔄 [WS] Transitioning to RETRYING state - notifying network layer" % _get_timestamp())
					_set_socket_health(WEBSOCKET_HEALTH.RETRYING)
				FEAGI_socket_retrying_connection.emit(_retry_count, FeagiCore.feagi_settings.number_of_times_to_retry_WS_connections)
				
				# Don't create multiple timers
				if _retry_timer_active:
					print("[%s] ⚠️ [WS] Retry timer already active - not creating another one" % _get_timestamp())
					return
				
				# Fixed 2-second retry interval
				var retry_delay = 2.0
				print("[%s] 🔄 [WS] Retrying in %.1f seconds..." % [_get_timestamp(), retry_delay])
				_retry_timer_active = true
				get_tree().create_timer(retry_delay).timeout.connect(func():
					_retry_timer_active = false
					_reconnect_websocket()
				)
				push_warning("FEAGI Websocket: Recovered from the retrying state! Retry %d / %d" % [_retry_count, FeagiCore.feagi_settings.number_of_times_to_retry_WS_connections]) # using warning to make things easier to read
				_retry_count += 1
				return
			else:
				# Ran out of retries
				print("[%s] ❌ [WS] Exhausted all retry attempts - giving up" % _get_timestamp())
				print("[%s] 🔌 [WS] Notifying network layer about websocket failure (exhausted retries)" % _get_timestamp())
				push_error("FEAGI Websocket: Websocket failed to recover!")
				_set_socket_health(WEBSOCKET_HEALTH.NO_CONNECTION)
				set_process(false)

## Inits address needed to connect
func setup(feagi_socket_address: StringName) -> void:
	_socket_web_address = feagi_socket_address

## Starts a connection
func connect_websocket() -> void:
	if _socket_web_address == "":
		push_error("FEAGI WS: No address specified!")
		return
		
	print("[%s] 🔌 [WS] connect_websocket() called - resetting state" % _get_timestamp())
	_is_purposfully_disconnecting = false
	_retry_count = 0
	_retry_timer_active = false  # Reset timer flag
	_last_disconnect_time = 0  # Reset disconnect tracking
	_set_socket_health(WEBSOCKET_HEALTH.NO_CONNECTION)  # Reset health
	
	# On Web, ensure WASM is initialized before opening the socket to avoid early packets
	if OS.has_feature("web") and not WASMDecoder.is_wasm_ready():
		WASMDecoder.ensure_wasm_loaded()
		if not _waiting_for_wasm:
			_waiting_for_wasm = true
			var timer := get_tree().create_timer(0.1)
			timer.timeout.connect(func():
				_waiting_for_wasm = false
				connect_websocket()
			)
		return
	set_process(true)
	_reconnect_websocket()

## Force closes the socket. This does not cause 'FEAGI_socket_health_changed' to fire
func disconnect_websocket() -> void:
	if _socket == null:
		return
	# this is purposeful, we dont want to emit anything
	_socket_health = WEBSOCKET_HEALTH.NO_CONNECTION
	_is_purposfully_disconnecting = true
	_socket.close()
	

## attempts to send data over websocket
func websocket_send(data: Variant) -> void:
	if _socket_health != WEBSOCKET_HEALTH.CONNECTED:
		push_warning("FEAGI Websocket: Unable to send data to closed socket!")
		return
	_socket.send((data.to_ascii_buffer()).compress(1)) # for some reason, using the enum instead of the number causes this break

func _process_wrapped_byte_structure(bytes: PackedByteArray) -> void:
	# DEBUG: Log the structure ID detection
	var structure_id = bytes[0] if bytes.size() > 0 else -1

	# 𒓉 If SHM is active, ignore WS-delivered neuron visualization (Type 11) to avoid duplicates
	if _use_shared_mem and structure_id == 11:
		return
	
	# SAFETY CHECK: Ensure we have data before processing
	if bytes.size() == 0:
		push_error("FEAGI: Cannot process empty byte array!")
		return
	
	## respond as per type
	match(bytes[0]):
		1: # JSON wrapper (may be legacy status OR SHM JSON Type 11)
			bytes = bytes.slice(2)
			var text := bytes.get_string_from_ascii()
			var dict_any: Variant = str_to_var(text)
			var dict: Dictionary = {}
			if typeof(dict_any) == TYPE_DICTIONARY:
				dict = dict_any
			else:
				var json_parsed = JSON.parse_string(text)
				if typeof(json_parsed) == TYPE_DICTIONARY:
					dict = json_parsed
				else:
					push_error("FEAGI: Unable to parse WS Data (neither var nor json)!")
					return
			# SHM JSON Type 11 passthrough
			if dict.has("type") and int(dict.get("type", -1)) == 11 and dict.has("areas") and typeof(dict["areas"]) == TYPE_DICTIONARY:
				var areas: Dictionary = dict["areas"]
				var total_points := 0
				for cortical_id in areas.keys():
					# Filter out core areas (_death, _power) that can't be visualized
					if cortical_id == "_death" or cortical_id == "_power":
						continue
					var a = areas[cortical_id]
					if typeof(a) != TYPE_DICTIONARY:
						continue
					var x_arr := PackedInt32Array(a.get("x", []))
					var y_arr := PackedInt32Array(a.get("y", []))
					var z_arr := PackedInt32Array(a.get("z", []))
					var p_arr := PackedFloat32Array(a.get("p", []))
					total_points += x_arr.size()
					FEAGI_sent_direct_neural_points_bulk.emit(cortical_id, x_arr, y_arr, z_arr, p_arr)
					var area: AbstractCorticalArea = _get_cortical_area_case_insensitive(cortical_id)
					if area:
						area.FEAGI_set_direct_points_bulk_data(x_arr, y_arr, z_arr, p_arr)
					else:
						_handle_missing_cortical_area(cortical_id)
				if _shm_debug_logs:
					print("𒓉 [WS] Processed SHM JSON Type 11: areas=", areas.size(), " points=", total_points)
				# Throttle logging but keep processing subsequent frames without suppression
				_shm_notice_printed = true
				return
			if dict.has("status"):
				var dict_status = dict["status"]
				FeagiCore.feagi_local_cache.update_health_from_FEAGI_dict(dict_status)
				
				# DEPRECATED: Old websocket-based genome change detection (replaced by health check detection)
				# This is disabled in favor of more reliable HTTP health check-based detection
				# using feagi_session + genome_num in FEAGILocalCache.update_health_from_FEAGI_dict()
				
				# Keep the genome tracking variables for potential future use, but don't trigger reloads
				if dict_status.has("genome_timestamp"):
					_temp_genome_ID = dict_status["genome_timestamp"]
				if dict_status.has("genome_num"):
					_temp_genome_num = dict_status["genome_num"]
						
					
		7: # ActivatedNeuronLocation
			# ignore version for now
			push_warning("ActivatedNeuronLocation data type is deprecated!")
		8: # SingleRawImage
			# ignore version for now
			feagi_return_visual_data.emit(bytes)
		9: # multi structure
			# ignore version for now
			var number_contained_structures: int = bytes[2]
			var structure_start_index: int = 0 # cached
			var structure_length: int = 0 # cached
			var header_offset: int = 3 # cached, lets us know where to read from the subheader
			for structure_index in range(number_contained_structures):
				structure_start_index = bytes.decode_u32(header_offset)        # Little Endian by default
				structure_length = bytes.decode_u32(header_offset + 4)        # Little Endian by default
				_process_wrapped_byte_structure(bytes.slice(structure_start_index, structure_start_index + structure_length))
				header_offset += 8
		10: # SVO neuron activations (legacy support)
			var cortical_ID: StringName = bytes.slice(2,8).get_string_from_ascii()
			var SVO_data: PackedByteArray = bytes.slice(8) # TODO this is not efficient at all
			FEAGI_sent_SVO_data.emit(cortical_ID, SVO_data)
			
			# TODO I dont like this
			var area: AbstractCorticalArea = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.get(cortical_ID)
			if area:
				area.FEAGI_set_SVO_visualization_data(SVO_data)
		
		11: # Direct Neural Points (NEW - feagi-data-processing format with bulk arrays)
			# Type 11 structure: [Type:1][Version:1][NumAreas:2][AreaHeaders][NeuronData]
			# AreaHeaders: [CorticalID:6][DataOffset:4][DataLength:4] per area = 14 bytes per area
			# NeuronData: [X array][Y array][Z array][P array] per area
			
			if OS.has_feature("web"):
				if not WASMDecoder.is_wasm_ready():
					# Queue until WASM is ready and return early
					_pending_type11.append(bytes.duplicate())
					return
				var decoded_result: Dictionary = WASMDecoder.decode_type_11(bytes)
				if !decoded_result or !decoded_result.has("success") or decoded_result.success != true:
					var err = decoded_result.get("error", "unknown")
					# Suppress noisy logs while WASM is still loading
					if err == "WASM not ready" or err == "WASM not initialized":
						return
					print("   ❌ ERROR: Type 11 WASM decode failed: ", err)
					return
				# Process each decoded cortical area with DIRECT bulk arrays
				for cortical_id in decoded_result.areas.keys():
					# Filter out core areas (_death, _power) that can't be visualized
					if cortical_id == "_death" or cortical_id == "_power":
						continue
					var area_data = decoded_result.areas[cortical_id]
					var x_array: PackedInt32Array = PackedInt32Array(area_data.x_array)
					var y_array: PackedInt32Array = PackedInt32Array(area_data.y_array)
					var z_array: PackedInt32Array = PackedInt32Array(area_data.z_array)
					var p_array: PackedFloat32Array = PackedFloat32Array(area_data.p_array)
					FEAGI_sent_direct_neural_points_bulk.emit(cortical_id, x_array, y_array, z_array, p_array)
					var area: AbstractCorticalArea = _get_cortical_area_case_insensitive(cortical_id)
					if area:
						area.FEAGI_set_direct_points_bulk_data(x_array, y_array, z_array, p_array)
					else:
						_handle_missing_cortical_area(cortical_id)
			else:
				# Use Rust-based high-performance deserializer (REQUIRED on desktop)
				if _rust_deserializer == null:
					push_error("🦀 CRITICAL: Rust deserializer is null! Cannot process Type 11 data.")
					return
				var decoded_result: Dictionary = _rust_deserializer.decode_type_11_data(bytes)
				if !decoded_result.success:
					print("   ❌ ERROR: Type 11 decode failed: ", decoded_result.error)
					return
				# Process each decoded cortical area with DIRECT bulk arrays (no conversion loops!)
				for cortical_id in decoded_result.areas.keys():
					# Filter out core areas (_death, _power) that can't be visualized
					if cortical_id == "_death" or cortical_id == "_power":
						continue
					var area_data = decoded_result.areas[cortical_id]
					FEAGI_sent_direct_neural_points_bulk.emit(
						cortical_id,
						area_data.x_array,
						area_data.y_array,
						area_data.z_array,
						area_data.p_array
					)
					var area: AbstractCorticalArea = _get_cortical_area_case_insensitive(cortical_id)
					if area:
						area.FEAGI_set_direct_points_bulk_data(area_data.x_array, area_data.y_array, area_data.z_array, area_data.p_array)
					else:
						_handle_missing_cortical_area(cortical_id)

		_: # Unknown
			print("   ❌ ROUTING: UNKNOWN structure type ", structure_id, " - ERROR!")
			push_error("Unknown data type %d recieved!" % bytes[0])

func _get_timestamp() -> String:
	var time = Time.get_time_dict_from_system()
	return "%02d:%02d:%02d.%03d" % [time.hour, time.minute, time.second, Time.get_ticks_msec() % 1000]

func _reconnect_websocket() -> void:
	# Debug call stack to see what's triggering multiple calls
	var stack = get_stack()
	var caller = "unknown"
	if stack.size() > 1:
		caller = stack[1].get("source", "unknown") + ":" + str(stack[1].get("line", 0))
	
	print("[%s] 🔌 [WS] _reconnect_websocket() called - retry_count: %d, health: %s, caller: %s" % [_get_timestamp(), _retry_count, WEBSOCKET_HEALTH.keys()[_socket_health], caller])
	
	# Don't reconnect if we're already connected, or if we've given up completely
	if _socket_health == WEBSOCKET_HEALTH.CONNECTED:
		print("[%s] ⚠️ [WS] Already connected - ignoring reconnect request" % _get_timestamp())
		return
	if _socket_health == WEBSOCKET_HEALTH.NO_CONNECTION and _retry_count > 10:
		print("[%s] ⚠️ [WS] Already gave up after immediate failures - ignoring reconnect request (retry_count: %d)" % [_get_timestamp(), _retry_count])
		return
		
	_socket = null # enforce dereference
	_socket =  WebSocketPeer.new()
	_socket.inbound_buffer_size = DEF_SOCKET_INBOUND_BUFFER_SIZE
	_last_connect_time = Time.get_ticks_msec()
	_socket.connect_to_url(_socket_web_address)
	print("[%s] [WS] connect_to_url(%s) inbound_buffer_size=%d" % [_get_timestamp(), _socket_web_address, DEF_SOCKET_INBOUND_BUFFER_SIZE])

func _looks_like_feagi_ws_payload(bytes: PackedByteArray) -> bool:
	# FEAGI payload types we handle: 1(JSON),8(img),9(multi),10(SVO),11(neurons)
	if bytes.size() == 0:
		return false
	var t := int(bytes[0])
	return t == 1 or t == 8 or t == 9 or t == 10 or t == 11

func _is_probably_text(bytes: PackedByteArray) -> bool:
	# Heuristic: small (<= 256) and all ASCII/whitespace
	var n := bytes.size()
	if n == 0 or n > 256:
		return false
	for i in range(n):
		var b := int(bytes[i])
		if b == 9 or b == 10 or b == 13:
			continue
		if b < 32 or b > 126:
			return false
	return true

# 𒓉 -------- Shared Memory Visualization Support --------
func _init_shm_visualization() -> void:
	# Prefer explicit neuron viz SHM; fallback to generic viz SHM
	var p := OS.get_environment("FEAGI_VIZ_NEURONS_SHM")
	if p == "":
		p = OS.get_environment("FEAGI_VIZ_SHM")
	if p == "":
		return
	_pending_shm_path = p
	_shm_init_attempts = 0
	_shm_last_error = ""
	_shm_attempting = true
	# Start retry loop to wait for file/header to be ready without spamming WS fallback
	_ws_notice_printed = false
	_ws_notice_deadline_ms = Time.get_ticks_msec() + 2500
	print("𒓉 [WS] Awaiting SHM neuron visualization path: ", p)
	_try_open_shm_path()

func _try_open_shm_path() -> void:
	if _pending_shm_path == "":
		return
	var p := _pending_shm_path
	if not FileAccess.file_exists(p):
		# Retry later; file will be created by FEAGI
		if _shm_init_attempts < _shm_init_max_attempts:
			_shm_init_attempts += 1
			_shm_last_error = "file not found"
			print("𒓉 [WS] SHM try ", _shm_init_attempts, "/", _shm_init_max_attempts, ": waiting for file: ", p)
			get_tree().create_timer(0.25).timeout.connect(_try_open_shm_path)
			return
		else:
			print("𒓉 [WS] SHM activation failed: file never appeared: ", p)
			_shm_attempting = false
			_pending_shm_path = ""
			_ws_notice_deadline_ms = Time.get_ticks_msec() + 10
			return
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		if _shm_init_attempts < _shm_init_max_attempts:
			_shm_init_attempts += 1
			var err := FileAccess.get_open_error()
			_shm_last_error = "open failed error=" + str(err)
			print("𒓉 [WS] SHM try ", _shm_init_attempts, "/", _shm_init_max_attempts, ": open failed. error=", err)
			get_tree().create_timer(0.25).timeout.connect(_try_open_shm_path)
			return
		else:
			var err2 := FileAccess.get_open_error()
			print("𒓉 [WS] SHM activation failed after ", _shm_init_attempts, " attempts; last_error=open failed error=", err2)
			_shm_attempting = false
			_pending_shm_path = ""
			_ws_notice_deadline_ms = Time.get_ticks_msec() + 10
			return
	# Read header once to initialize
	f.seek(0)
	var h := f.get_buffer(_shm_header_size)
	if h.size() < 32:
		if _shm_init_attempts < _shm_init_max_attempts:
			_shm_init_attempts += 1
			_shm_last_error = "header too small size=" + str(h.size())
			print("𒓉 [WS] SHM try ", _shm_init_attempts, "/", _shm_init_max_attempts, ": header too small (", h.size(), ")")
			get_tree().create_timer(0.25).timeout.connect(_try_open_shm_path)
			return
		else:
			print("𒓉 [WS] SHM activation failed after ", _shm_init_attempts, " attempts; last_error=header too small size=", h.size())
			_shm_attempting = false
			_pending_shm_path = ""
			_ws_notice_deadline_ms = Time.get_ticks_msec() + 10
			return
	var magic := ""
	for i in range(8):
		magic += char(h[i])
	if magic != "FEAGIVIS" and magic != "FEAGIBIN" and magic != "FEAGIMOT":
		if _shm_init_attempts < _shm_init_max_attempts:
			_shm_init_attempts += 1
			_shm_last_error = "invalid magic=" + magic
			print("𒓉 [WS] SHM try ", _shm_init_attempts, "/", _shm_init_max_attempts, ": invalid magic '", magic, "' (expect FEAGIVIS/FEAGIBIN/FEAGIMOT)")
			get_tree().create_timer(0.25).timeout.connect(_try_open_shm_path)
			return
		else:
			print("𒓉 [WS] SHM activation failed after ", _shm_init_attempts, " attempts; last_error=invalid magic '", magic, "'")
			_shm_attempting = false
			_pending_shm_path = ""
			_ws_notice_deadline_ms = Time.get_ticks_msec() + 10
			return
	var num_slots := h.decode_u32(12)
	var slot_size := h.decode_u32(16)
	var first_seq := _decode_u64_le(h, 20)
	if num_slots <= 0 or slot_size <= 0:
		if _shm_init_attempts < _shm_init_max_attempts:
			_shm_init_attempts += 1
			_shm_last_error = "invalid header values slots=" + str(num_slots) + ", slot_size=" + str(slot_size)
			print("𒓉 [WS] SHM try ", _shm_init_attempts, "/", _shm_init_max_attempts, ": invalid header values slots=", num_slots, " slot_size=", slot_size)
			get_tree().create_timer(0.25).timeout.connect(_try_open_shm_path)
			return
		else:
			print("𒓉 [WS] SHM activation failed after ", _shm_init_attempts, " attempts; last_error=invalid header values slots=", num_slots, " slot_size=", slot_size)
			_shm_attempting = false
			_pending_shm_path = ""
			_ws_notice_deadline_ms = Time.get_ticks_msec() + 10
			return
	_shm_num_slots = num_slots
	_shm_slot_size = slot_size
	_shm_last_seq = first_seq - 1
	_shm_file = f
	_shm_path = p
	_use_shared_mem = true
	_pending_shm_path = ""
	_shm_attempting = false
	
	# Initialize rate tracking
	_shm_updates_received = 0
	_shm_last_rate_log_time = Time.get_ticks_msec() / 1000.0
	
	print("𒓉 [WS] Using SHM neuron visualization: ", p, " magic=", magic, " slots=", _shm_num_slots, " slot_size=", _shm_slot_size, " first_seq=", first_seq)
	# Reset path notices to show SHM active on next _process tick
	_shm_notice_printed = false
	_ws_notice_printed = true

func _poll_shm_once() -> void:
	if _shm_file == null:
		return
	# Re-read header to get write_index and frame_seq
	_shm_file.seek(0)
	var h := _shm_file.get_buffer(_shm_header_size)
	if h.size() < 32:
		return
	var frame_seq := _decode_u64_le(h, 20)
	if frame_seq <= _shm_last_seq:
		_shm_missed_cycles += 1
		# Quiet repetitive logs; only print once per staleness streak
		if _shm_debug_logs and not _shm_no_new_reported:
			var wi := int(h.decode_u32(28))
			print("𒓉 [WS] SHM no new frame: head=", frame_seq, " last=", _shm_last_seq, " write_index=", wi)
			_shm_no_new_reported = true
		# If we miss enough cycles, reopen the file to avoid stale cache (quiet)
		if _shm_missed_cycles >= _shm_reopen_threshold:
			# Close and reopen
			_shm_file = null
			var f2 := FileAccess.open(_shm_path, FileAccess.READ)
			if f2 != null:
				_shm_file = f2
				_shm_missed_cycles = 0
				_shm_no_new_reported = false
				# Force re-read header next tick
				return
		return
	var write_index := int(h.decode_u32(28))
	if _shm_num_slots <= 0 or _shm_slot_size <= 0:
		return
	var idx := (write_index - 1) % _shm_num_slots
	if idx < 0:
		idx += _shm_num_slots
	var slot_off := _shm_header_size + idx * _shm_slot_size
	_shm_file.seek(slot_off)
	var len_bytes := _shm_file.get_buffer(4)
	if len_bytes.size() < 4:
		return
	var payload_len := len_bytes.decode_u32(0)
	if payload_len <= 0 or payload_len > (_shm_slot_size - 4):
		_shm_last_seq = frame_seq
		return
	var payload := _shm_file.get_buffer(payload_len)
	_shm_last_seq = frame_seq
	_shm_no_new_reported = false
	_shm_missed_cycles = 0
	
	# Track update rate
	_shm_updates_received += 1
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - _shm_last_rate_log_time >= _shm_rate_log_interval:
		var elapsed = current_time - _shm_last_rate_log_time
		var update_rate = _shm_updates_received / elapsed
		print("𒓉 [WS] SHM receiving updates at %.1f Hz (%d updates in %.1f sec)" % [update_rate, _shm_updates_received, elapsed])
		_shm_updates_received = 0
		_shm_last_rate_log_time = current_time
	
	if _shm_debug_logs:
		print("𒓉 [WS] SHM frame ", frame_seq, " idx=", idx, " bytes=", payload_len)
	_process_wrapped_byte_structure(payload)

func enable_shared_memory_visualization(p: String) -> void:
	# Public API to switch to SHM immediately using a provided path
	if p == "":
		return
	OS.set_environment("FEAGI_VIZ_NEURONS_SHM", p)
	_pending_shm_path = p
	_shm_init_attempts = 0
	_shm_last_error = ""
	_shm_attempting = true
	# Give time for FEAGI to create and initialize the file header
	_ws_notice_printed = false
	_ws_notice_deadline_ms = Time.get_ticks_msec() + 2500
	print("𒓉 [WS] Enabling SHM neuron visualization via register; will retry: ", p)
	_try_open_shm_path()

func _decode_u64_le(bytes: PackedByteArray, offset: int) -> int:
	# Godot GDScript lacks decode_u64 on some versions; compose from two u32
	var lo := int(bytes.decode_u32(offset))
	var hi := int(bytes.decode_u32(offset + 4))
	return (hi << 32) | (lo & 0xFFFFFFFF)

func _handle_missing_cortical_area(cortical_id: StringName) -> void:
	# FILTER CORE AREAS FIRST - before any logging or processing
	# Convert to String for robust comparison (StringName may have different comparison semantics)
	var cortical_id_str := String(cortical_id)
	
	# Handle both quoted and unquoted versions (cortical ID may come with quotes)
	var clean_id := cortical_id_str.strip_edges().replace("'", "").replace('"', "")
	
	if clean_id == "_death" or clean_id == "_power":
		# Core system areas cannot be visualized - silently ignore
		return
	
	# Skip handling missing areas during genome reload/processing to avoid spam
	var genome_state = FeagiCore.genome_load_state
	if genome_state == FeagiCore.GENOME_LOAD_STATE.GENOME_RELOADING or genome_state == FeagiCore.GENOME_LOAD_STATE.GENOME_PROCESSING:
		# Suppress debug output during genome reload - this is expected behavior
		return
	
	# Also skip if cache is empty (genome hasn't loaded yet)
	var cache_size = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.size()
	if cache_size == 0:
		# Suppress debug output when cache is empty - genome is still loading
		return
	
	# If the cleaned ID is in cache, it's not actually missing - just had quotes
	if clean_id in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas:
		return
	
	# DEBUG: Uncomment to trace missing area lookups (disabled to reduce log spam)
	# print("🔍 DEBUG: _handle_missing_cortical_area() called for '%s'" % cortical_id)
	var current_time = Time.get_time_dict_from_system()
	var current_timestamp = current_time.hour * 3600 + current_time.minute * 60 + current_time.second
	
	# Initialize tracking for this cortical area if not seen before (use clean_id for tracking)
	if clean_id not in _missing_cortical_areas:
		_missing_cortical_areas[clean_id] = {
			"last_warning_time": 0.0,
			"fetch_attempted": false
		}
	
	var area_info = _missing_cortical_areas[clean_id]
	var time_since_last_warning = current_timestamp - area_info.last_warning_time
	
	# Only show warning if enough time has passed
	if time_since_last_warning >= MISSING_AREA_WARNING_INTERVAL:
		print("   ⚠️  WARNING: Cortical area '", clean_id, "' not found in cache (will retry fetching) - cache size: ", cache_size)
		area_info.last_warning_time = current_timestamp
		
		# Attempt to fetch the missing cortical area from FEAGI (only once per area)
		if not area_info.fetch_attempted and FeagiCore.can_interact_with_feagi():
			area_info.fetch_attempted = true
			print("   🔄 Attempting to fetch missing cortical area '", clean_id, "' from FEAGI...")
			_fetch_missing_cortical_area_async(clean_id)

func _fetch_missing_cortical_area_async(cortical_id: StringName) -> void:
	# Clean cortical ID (remove quotes that may come from Rust deserializer)
	var clean_id := String(cortical_id).strip_edges().replace("'", "").replace('"', "")
	
	print("🔍 DEBUG: _fetch_missing_cortical_area_async() called for '%s' (cleaned: '%s')" % [cortical_id, clean_id])
	# Double-check if the area is actually missing before fetching
	if clean_id in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas:
		print("   ℹ️ Cortical area '", clean_id, "' is already in cache, skipping fetch")
		_missing_cortical_areas.erase(clean_id)
		return
	
	# Fetch the cortical area details from FEAGI using cleaned ID
	var result = await FeagiCore.requests.get_cortical_area(clean_id)
	if not result.has_errored:
		print("   ✅ Successfully fetched missing cortical area '", clean_id, "' from FEAGI")
		
		# Verify it's actually in the cache now
		await get_tree().process_frame  # Wait one frame for any pending operations
		if clean_id in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas:
			print("   ✅ Confirmed: '", clean_id, "' is now in cache")
			_missing_cortical_areas.erase(clean_id)
		else:
			push_error("   ❌ CRITICAL: '", clean_id, "' was fetched but is NOT in cache! Cache size: ", FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.size())
			# Don't erase from tracking so it can be retried
	else:
		print("   ❌ Failed to fetch cortical area '", clean_id, "' from FEAGI - this may be expected if the area doesn't exist")
		# Don't retry immediately for areas that return 400 errors
		_missing_cortical_areas.erase(clean_id)

func _get_cortical_area_case_insensitive(cortical_id: StringName) -> AbstractCorticalArea:
	# First try exact match (most common case)
	var area: AbstractCorticalArea = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.get(cortical_id)
	if area:
		return area
	
	# Check case mapping cache
	var lowercase_id = cortical_id.to_lower()
	if lowercase_id in _case_mapping_cache:
		var cached_id = _case_mapping_cache[lowercase_id]
		area = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.get(cached_id)
		if area:
			return area
		else:
			# Cached mapping is stale, remove it
			_case_mapping_cache.erase(lowercase_id)
	
	# Do case-insensitive search and cache the result
	for cached_id in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.keys():
		if cached_id.to_lower() == lowercase_id:
			_case_mapping_cache[lowercase_id] = cached_id
			area = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas[cached_id]
			# Only log the first time we discover a case mismatch
			if cortical_id != cached_id:
				print("   🔄 Case mismatch detected: neuron data '%s' → cached area '%s' (cached for future lookups)" % [cortical_id, cached_id])
			return area
	
	return null

func _on_genome_reloaded() -> void:
	# Reset missing cortical area tracking when genome reloads
	# This allows areas to be fetched again if they're still missing after reload
	print("   🔄 Genome reloaded - resetting missing cortical area tracking")
	_missing_cortical_areas.clear()
	_case_mapping_cache.clear()  # Clear case mapping cache too

func _set_socket_health(new_health: WEBSOCKET_HEALTH) -> void:
	var prev_health: WEBSOCKET_HEALTH = _socket_health
	_socket_health = new_health
	print("[%s] 🔌 [WS] _set_socket_health: %s → %s" % [_get_timestamp(), WEBSOCKET_HEALTH.keys()[prev_health], WEBSOCKET_HEALTH.keys()[new_health]])
	print("[%s] 📡 [WS] Emitting FEAGI_socket_health_changed signal (connected listeners: %d)" % [_get_timestamp(), FEAGI_socket_health_changed.get_connections().size()])
	FEAGI_socket_health_changed.emit(prev_health, new_health)

# All deserialization is now handled by the Rust extension
# The _decode_type_11_optimized function has been removed as it's no longer needed
