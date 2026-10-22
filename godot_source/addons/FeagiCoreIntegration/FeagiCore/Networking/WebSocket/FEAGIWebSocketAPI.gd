extends Node
class_name FEAGIWebSocketAPI

enum WEBSOCKET_HEALTH {
	NO_CONNECTION,
	CONNECTED,
	RETRYING
}

# Must accommodate large visualization frames (e.g., MRI/NIFTI payloads).
# Keep this comfortably above expected max frame size to avoid immediate disconnects.
const DEF_SOCKET_INBOUND_BUFFER_SIZE: int = 67108864 # 64 MiB
const DEF_SOCKET_BUFFER_SIZE: int = 67108864 # 64 MiB
const DEF_PING_INTERVAL_SECONDS: float = 2.0
const DEF_CONNECT_TIMEOUT_SECONDS: float = 5.0
const SOCKET_GENOME_UPDATE_FLAG: String = "updated" # FEAGI sends this string via websocket if genome is reloaded / changed
const SOCKET_GENEOME_UPDATE_LATENCY: String = "ping" # TODO DELETE

signal FEAGI_socket_health_changed(previous_health: WEBSOCKET_HEALTH, current_health: WEBSOCKET_HEALTH)
signal FEAGI_socket_retrying_connection(retry_count: int, max_retry_count: int)
signal FEAGI_sent_SVO_data(cortical_ID: StringName, SVO_data: PackedByteArray)
signal FEAGI_sent_direct_neural_points(cortical_ID: StringName, points_data: PackedByteArray)
signal feagi_requesting_reset()
signal feagi_return_visual_data(SingleRawImage: PackedByteArray)
signal shm_visualization_enabled(shm_path: String)


var socket_health: WEBSOCKET_HEALTH:
	get: return _socket_health

## Receives every Type 11 visualization packet this transport delivers. Set by [FEAGINetworking].
var visualization_sink: FEAGIVisualizationSink = null

#var _cache_websocket_data: PackedByteArray # outside to try to avoid reallocation penalties # NOTE: Godot doesnt seem to care and reallocates anyways lol
var _socket_web_address: StringName = ""
var _socket: WebSocketPeer
var _socket_health: WEBSOCKET_HEALTH = WEBSOCKET_HEALTH.NO_CONNECTION
var _retry_count: int = 0
var _is_purposfully_disconnecting: bool = false
var _last_connect_time: int = 0  # Track when we last attempted to connect
var _retry_timer_active: bool = false  # Track if a retry timer is already running
var _last_disconnect_time: int = 0  # Track last disconnect to prevent rapid processing

const WASMDecoder = preload("res://Utils/WASMDecoder.gd")
var _waiting_for_wasm: bool = false

# [FEAGI] Shared memory neuron visualization (FEAGI -> Brain Visualizer)
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

# Rate-limited WS backlog diagnostics (logging only)
var _ws_last_backlog_log_ms: int = 0
# Rate-limited retry/reconnect logs (avoid spam when FEAGI is down)
var _ws_last_retry_log_ms: int = 0
const _WS_RETRY_LOG_INTERVAL_MS: int = 10000
var _ws_disabled_by_shm_notice_printed: bool = false

# WS receive diagnostics (rate-limited)
var _ws_last_rx_log_ms: int = 0
const _WS_RX_LOG_INTERVAL_MS: int = 1000
const _WS_DIAGNOSTICS_ENABLED: bool = false

# SHM update rate tracking
var _shm_updates_received: int = 0
var _shm_last_rate_log_time: float = 0.0
var _shm_rate_log_interval: float = 5.0  # Log rate every 5 seconds
var _shm_last_frame_time: float = 0.0  # Track time between frames for instantaneous FPS
var _shm_frame_times: Array = []  # Rolling window of last 10 frame times
const _SHM_FRAME_WINDOW_SIZE: int = 10

# SHM polling throttle (to match negotiated rate)
var _shm_last_poll_time: float = 0.0
var _shm_poll_interval: float = 0.0  # Calculated from negotiated rate

# SHM diagnostics (rate-limited)
var _shm_last_rx_log_ms: int = 0
const _SHM_RX_LOG_INTERVAL_MS: int = 1000


func _ready():
	# [FEAGI] Try to initialize shared memory visualization (env-provided path)
	_init_shm_visualization()
	# Defer WS fallback notice to allow registration to provide SHM path
	_ws_notice_deadline_ms = Time.get_ticks_msec() + 3000

func _process(_delta: float):
	# [FEAGI] Poll SHM for neuron visualization bytes if enabled
	if _use_shared_mem:
		# Throttle polling to negotiated rate (not every frame!)
		var current_time = Time.get_ticks_msec() / 1000.0
		
		# Update poll interval from negotiated rate if available
		if _shm_poll_interval == 0.0:
			# Try to get negotiated rate from parent FEAGINetworking
			var feagi_networking = get_parent()
			if feagi_networking and feagi_networking.has_meta("_negotiated_viz_hz"):
				var negotiated_hz = feagi_networking.get_meta("_negotiated_viz_hz")
				_shm_poll_interval = 1.0 / negotiated_hz
				print("[FEAGI] [WS] SHM polling throttled to %.1f Hz (%.1f ms interval); path=%s" % [negotiated_hz, _shm_poll_interval * 1000.0, _shm_path])
			else:
				# Fallback: use 60 Hz (backwards compat)
				_shm_poll_interval = 1.0 / 60.0
				print("[FEAGI] [WS] WARN: No negotiated rate found, defaulting to 60 Hz polling")
		
		# Only poll if enough time has elapsed
		if current_time - _shm_last_poll_time >= _shm_poll_interval:
			_poll_shm_once()
			_shm_last_poll_time = current_time
			
			if not _shm_notice_printed:
				var rate_hz = 1.0 / _shm_poll_interval if _shm_poll_interval > 0.0 else 60.0
				print("[FEAGI] [WS] SHM polling active at %.1f Hz (throttled); path=%s" % [rate_hz, _shm_path])
				_shm_notice_printed = true
	else:
		# Print once to make it obvious we're on WS path, but only after a brief delay
		# and not while we are actively trying to initialize SHM
		if not _ws_notice_printed and _pending_shm_path == "" and not _shm_attempting and Time.get_ticks_msec() >= _ws_notice_deadline_ms:
			_ws_notice_printed = true

	# [FEAGI] Guard: If socket is null (e.g. never connected when using SHM), skip WebSocket polling but continue to SHM polling below
	if not _socket:
		# SHM polling for neuron visualization happens at end of _process()
		# But if we also use SHM for video, that's handled by WindowViewPreviews directly
		return

	_socket.poll()
	match(_socket.get_ready_state()):
		WebSocketPeer.State.STATE_CONNECTING:
			# Currently connecting to FEAGI. Guard against indefinite CONNECTING stalls.
			var connect_elapsed_ms: int = Time.get_ticks_msec() - _last_connect_time
			if connect_elapsed_ms > int(DEF_CONNECT_TIMEOUT_SECONDS * 1000.0):
				print("[%s] ⚠️ [WS] STATE_CONNECTING timed out after %dms - forcing reconnect path" % [_get_timestamp(), connect_elapsed_ms])
				if _socket:
					_socket.close()
				if _retry_count < FeagiCore.feagi_settings.number_of_times_to_retry_WS_connections:
					if _socket_health != WEBSOCKET_HEALTH.RETRYING:
						_set_socket_health(WEBSOCKET_HEALTH.RETRYING)
					FEAGI_socket_retrying_connection.emit(_retry_count, FeagiCore.feagi_settings.number_of_times_to_retry_WS_connections)
					if not _retry_timer_active:
						_retry_timer_active = true
						get_tree().create_timer(2.0).timeout.connect(func():
							_retry_timer_active = false
							_reconnect_websocket()
						)
					_retry_count += 1
				else:
					print("[%s] ❌ [WS] Exhausted retries while stuck in CONNECTING" % _get_timestamp())
					_set_socket_health(WEBSOCKET_HEALTH.NO_CONNECTION)
					set_process(false)
		WebSocketPeer.State.STATE_OPEN:
			# Connection active with FEAGI
			if _socket_health != WEBSOCKET_HEALTH.CONNECTED:
				if _retry_count != 0:
					print("[%s] ✅ [WS] Recovered from retrying state after %d attempts!" % [_get_timestamp(), _retry_count])
					_retry_count = 0
				_set_socket_health(WEBSOCKET_HEALTH.CONNECTED)
			
			var backlog_start := _socket.get_available_packet_count()
			var drained_packets := 0
			var drained_bytes := 0

			# REAL-TIME SEMANTICS:
			# Drain backlog but only decode the newest *binary* visualization packet.
			# This prevents drift when decode/render can't keep up with publish rate.
			var newest_binary: PackedByteArray = PackedByteArray()
			var newest_binary_len := 0

			while _socket.get_available_packet_count():
				var raw_packet: PackedByteArray = _socket.get_packet()
				var raw_len := raw_packet.size()
				drained_packets += 1
				drained_bytes += raw_len
				
				# 🐛 DEBUG: Log all received packets
				# print("🔍 [WS-DEBUG] Received packet: %d bytes, first byte: 0x%02x" % [raw_len, raw_packet[0] if raw_len > 0 else 0])
				
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
				
				# ARCHITECTURE: FEAGI PNS → ZMQ → Bridge PASSTHROUGH → WebSocket → BV process
				# Data format: Raw FeagiByteContainer containing Type 11 neuron data (may be LZ4 compressed)
				
				# Keep only the newest binary packet; we'll decode once after draining.
				if raw_len > 0:
					newest_binary = raw_packet
					newest_binary_len = raw_len
				continue

			# Decode newest binary packet (if any)
			# Rate-limited WS receive diagnostics (high-signal for "BV shows no power" debugging):
			# - Confirms BV is receiving frames at all
			# - Shows payload size and first byte (2 = FeagiByteContainer v2, 11 = raw Type 11)
			# - Avoids log spam by printing at most once per second
			var now_ms_rx := Time.get_ticks_msec()
			if _WS_DIAGNOSTICS_ENABLED and drained_packets > 0 and now_ms_rx - _ws_last_rx_log_ms >= _WS_RX_LOG_INTERVAL_MS:
				_ws_last_rx_log_ms = now_ms_rx
				if newest_binary_len > 0:
					var fb := int(newest_binary[0])
					print("[WS-RX] packets=%d bytes=%d newest_len=%d first_byte=%d backlog_start=%d" % [
						drained_packets, drained_bytes, newest_binary_len, fb, backlog_start
					])
				else:
					print("[WS-RX] packets=%d bytes=%d (no binary payload; likely text-only frames) backlog_start=%d" % [
						drained_packets, drained_bytes, backlog_start
					])

			if newest_binary_len > 0 and visualization_sink != null:
				visualization_sink.ingest_type11(newest_binary)
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
			
			if  _socket.get_available_packet_count() > 0:
				# There was some remenant data
				_socket.get_packet().decompress(DEF_SOCKET_BUFFER_SIZE, 1)
			#TODO FeagiEvents.retrieved_visualization_data.emit(str_to_var(_cache_websocket_data.get_string_from_ascii())) # Add to erase neurons
			if _is_purposfully_disconnecting:
				_is_purposfully_disconnecting = false
				set_process(false)
				return
			
			# If we've had too many immediate failures, give up faster
			if is_immediate_failure and _retry_count > 10:
				push_warning(
					"FEAGI Websocket: Repeated immediate failures while reconnecting. "
					+ "This may occur during FEAGI restart; waiting for normal recovery."
				)
				_set_socket_health(WEBSOCKET_HEALTH.NO_CONNECTION)
				set_process(false)
				return
			
			# Try to retry the WS connection to save it
			if _retry_count < FeagiCore.feagi_settings.number_of_times_to_retry_WS_connections:
				if _socket_health != WEBSOCKET_HEALTH.RETRYING:
					_set_socket_health(WEBSOCKET_HEALTH.RETRYING)
				FEAGI_socket_retrying_connection.emit(_retry_count, FeagiCore.feagi_settings.number_of_times_to_retry_WS_connections)
				# Rate-limited retry log (once per interval)
				var now_retry := Time.get_ticks_msec()
				if now_retry - _ws_last_retry_log_ms >= _WS_RETRY_LOG_INTERVAL_MS:
					_ws_last_retry_log_ms = now_retry
					push_warning("FEAGI Websocket: Retrying connection %d / %d" % [_retry_count + 1, FeagiCore.feagi_settings.number_of_times_to_retry_WS_connections])
				# Don't create multiple timers
				if _retry_timer_active:
					return
				# Fixed 2-second retry interval
				var retry_delay = 2.0
				_retry_timer_active = true
				get_tree().create_timer(retry_delay).timeout.connect(func():
					_retry_timer_active = false
					_reconnect_websocket()
				)
				_retry_count += 1
				return
			else:
				# Ran out of retries
				push_error("FEAGI Websocket: Websocket failed to recover!")
				_set_socket_health(WEBSOCKET_HEALTH.NO_CONNECTION)
				set_process(false)

## Inits address needed to connect
func setup(feagi_socket_address: StringName) -> void:
	_socket_web_address = feagi_socket_address

## Starts a connection
func connect_websocket() -> void:
	# If SHM neuron visualization is active, we do not require a WebSocket connection.
	# Keep SHM polling active, but skip WS connect attempts (prevents noisy retry spam).
	if _use_shared_mem:
		if not _ws_disabled_by_shm_notice_printed:
			_ws_disabled_by_shm_notice_printed = true
			print("[%s] [WS] WebSocket connect suppressed (SHM active)" % _get_timestamp())
		return
	if _socket_web_address == "":
		push_error("FEAGI WS: No address specified!")
		return
		
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

func _process_wrapped_byte_structure(bytes: PackedByteArray, from_shm: bool = false) -> void:
	# DEBUG: Log the structure ID detection
	var structure_id = bytes[0] if bytes.size() > 0 else -1
	
	# 🔍 TEMP DEBUG: Log what type we're receiving (first 20 packets)
	if not has_meta("_type_log_count"):
		set_meta("_type_log_count", 0)
	var type_count = get_meta("_type_log_count")
	if type_count < 20:
		print("🦀 [WS] RECEIVED TYPE %d: %d bytes, first 20 bytes: %s" % [structure_id, bytes.size(), bytes.slice(0, min(20, bytes.size())).hex_encode()])
		set_meta("_type_log_count", type_count + 1)

	# [FEAGI] If SHM is active, ignore WS-delivered (but NOT SHM-delivered) Type 11 to avoid duplicates
	if _use_shared_mem and structure_id == 11 and not from_shm:
		return
	
	# SAFETY CHECK: Ensure we have data before processing
	if bytes.size() == 0:
		push_error("FEAGI: Cannot process empty byte array!")
		return

	# Current FeagiByteContainer versions (3, 4) wrap Type 11; the Rust/WASM decoders parse the container.
	if bytes[0] == 3 or bytes[0] == 4:
		if visualization_sink != null:
			visualization_sink.ingest_type11(bytes)
		return

	# FEAGI Byte Container v2 (first byte == 2)
	# This is a wrapper format used by FEAGI (SHM/WS) that can contain one or more structures.
	# Format (from feagi-serialization::FeagiByteContainer):
	# - [0]   version (u8) == 2
	# - [1:3] increment_counter (u16 LE)
	# - [3]   struct_count (u8)
	# - then struct_count * u32 LE lengths
	# - then each structure payload (each payload begins with structure type, e.g., 1 or 11)
	if bytes[0] == 2:
		if bytes.size() < 4:
			push_error("FEAGI: Invalid ByteContainer v2 (too short)")
			return
		var struct_count := int(bytes[3])
		if struct_count <= 0:
			# Valid empty container
			return
		var lookup_len := 4 * struct_count
		var header_total := 4 + lookup_len
		if bytes.size() < header_total:
			push_error("FEAGI: Invalid ByteContainer v2 (header truncated)")
			return
		var data_off := header_total
		for i in range(struct_count):
			var len_off := 4 + i * 4
			var struct_len := int(bytes.decode_u32(len_off))
			if struct_len <= 0:
				continue
			if data_off + struct_len > bytes.size():
				push_error("FEAGI: Invalid ByteContainer v2 (structure out of bounds)")
				return
			var struct_bytes := bytes.slice(data_off, data_off + struct_len)
			_process_wrapped_byte_structure(struct_bytes, from_shm)
			data_off += struct_len
		return
	
	## respond as per type
	match(bytes[0]):
		1: # JSON wrapper (may be legacy status OR SHM JSON Type 11)
			bytes = bytes.slice(2)
			var text := bytes.get_string_from_ascii()
			# 🔍 TEMP DEBUG: Log JSON parsing (first 3)
			if not has_meta("_json_parse_count"):
				set_meta("_json_parse_count", 0)
			var json_count = get_meta("_json_parse_count")
			if json_count < 3:
				print("🦀 [WS] TYPE 1 JSON PARSE #%d: %d chars, first 80: %s" % [json_count + 1, text.length(), text.substr(0, 80)])
				set_meta("_json_parse_count", json_count + 1)
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
			# 🔍 TEMP DEBUG: Log what keys we have
			if json_count < 3:
				print("🦀 [WS] TYPE 1 PARSED: has_status=%s, keys=%s" % [dict.has("status"), dict.keys()])
			# SHM JSON Type 11 passthrough
			if dict.has("type") and int(dict.get("type", -1)) == 11 and dict.has("areas") and typeof(dict["areas"]) == TYPE_DICTIONARY:
				var areas: Dictionary = dict["areas"]
				var decoded_areas: Dictionary = {}
				var total_points := 0
				for cortical_id in areas.keys():
					var a = areas[cortical_id]
					if typeof(a) != TYPE_DICTIONARY:
						continue
					var x_arr := PackedInt32Array(a.get("x", []))
					total_points += x_arr.size()
					decoded_areas[cortical_id] = {
						"x_array": x_arr,
						"y_array": PackedInt32Array(a.get("y", [])),
						"z_array": PackedInt32Array(a.get("z", [])),
						"p_array": PackedFloat32Array(a.get("p", [])),
					}
				if visualization_sink != null:
					visualization_sink.apply_decoded_areas(decoded_areas)
				if _shm_debug_logs:
					print("[FEAGI] [WS] Processed SHM JSON Type 11: areas=", areas.size(), " points=", total_points)
				# Throttle logging but keep processing subsequent frames without suppression
				_shm_notice_printed = true
				return
			if dict.has("status"):
				var dict_status = dict["status"]
				# 🔍 TEMP DEBUG: Log health data updates (first 5)
				if not has_meta("_health_update_count"):
					set_meta("_health_update_count", 0)
				var health_count = get_meta("_health_update_count")
				if health_count < 5:
					print("🦀 [WS] TYPE 1 HEALTH UPDATE #%d:" % [health_count + 1])
					print("  - connected: %s" % [dict_status.get("connected", "missing")])
					print("  - brain_readiness: %s" % [dict_status.get("brain_readiness", "missing")])
					print("  - genome_availability: %s" % [dict_status.get("genome_availability", "missing")])
					print("  - genome_timestamp: %s" % [dict_status.get("genome_timestamp", "missing")])
					set_meta("_health_update_count", health_count + 1)
				FeagiCore.feagi_local_cache.update_health_from_FEAGI_dict(dict_status)
					
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
			# 🔍 TEMP DEBUG: Log Type 9 processing (first 10)
			if not has_meta("_type9_log_count"):
				set_meta("_type9_log_count", 0)
			var type9_count = get_meta("_type9_log_count")
			if type9_count < 10:
				print("🦀 [WS] TYPE 9 RECEIVED: %d structures, total %d bytes" % [number_contained_structures, bytes.size()])
				set_meta("_type9_log_count", type9_count + 1)
			for structure_index in range(number_contained_structures):
				structure_start_index = bytes.decode_u32(header_offset)        # Little Endian by default
				structure_length = bytes.decode_u32(header_offset + 4)        # Little Endian by default
				var structure_data = bytes.slice(structure_start_index, structure_start_index + structure_length)
				if type9_count < 10 and structure_data.size() > 0:
					print("   - Structure %d: type=%d, offset=%d, length=%d" % [structure_index, structure_data[0], structure_start_index, structure_length])
				_process_wrapped_byte_structure(structure_data)
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
			if visualization_sink != null:
				visualization_sink.ingest_type11(bytes)

		_: # Unknown
			print("   ❌ ROUTING: UNKNOWN structure type ", structure_id, " - ERROR!")
			push_error("Unknown data type %d recieved!" % bytes[0])

func _get_timestamp() -> String:
	var time = Time.get_time_dict_from_system()
	return "%02d:%02d:%02d.%03d" % [time.hour, time.minute, time.second, Time.get_ticks_msec() % 1000]

func _reconnect_websocket() -> void:
	# If SHM neuron visualization is active, do not attempt WS reconnects.
	if _use_shared_mem:
		return
	# Don't reconnect if we're already connected, or if we've given up completely
	if _socket_health == WEBSOCKET_HEALTH.CONNECTED:
		return
	if _socket_health == WEBSOCKET_HEALTH.NO_CONNECTION and _retry_count > 10:
		return
		
	_socket = null # enforce dereference
	_socket =  WebSocketPeer.new()
	_socket.inbound_buffer_size = DEF_SOCKET_INBOUND_BUFFER_SIZE
	_last_connect_time = Time.get_ticks_msec()
	_socket.connect_to_url(_socket_web_address)

func _looks_like_feagi_ws_payload(bytes: PackedByteArray) -> bool:
	# FEAGI payload types we handle: 1(JSON),8(img),9(multi),10(SVO),11(neurons)
	if bytes.size() == 0:
		return false
	var t := int(bytes[0])
	# 2 is FeagiByteContainer v2 wrapper (contains 1/11 internally)
	return t == 1 or t == 2 or t == 8 or t == 9 or t == 10 or t == 11

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

# [FEAGI] -------- Shared Memory Visualization Support --------
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
	print("[FEAGI] [WS] Awaiting SHM neuron visualization path: ", p)
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
			print("[FEAGI] [WS] SHM try ", _shm_init_attempts, "/", _shm_init_max_attempts, ": waiting for file: ", p)
			get_tree().create_timer(0.25).timeout.connect(_try_open_shm_path)
			return
		else:
			print("[FEAGI] [WS] SHM activation failed: file never appeared: ", p)
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
			print("[FEAGI] [WS] SHM try ", _shm_init_attempts, "/", _shm_init_max_attempts, ": open failed. error=", err)
			get_tree().create_timer(0.25).timeout.connect(_try_open_shm_path)
			return
		else:
			var err2 := FileAccess.get_open_error()
			print("[FEAGI] [WS] SHM activation failed after ", _shm_init_attempts, " attempts; last_error=open failed error=", err2)
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
			print("[FEAGI] [WS] SHM try ", _shm_init_attempts, "/", _shm_init_max_attempts, ": header too small (", h.size(), ")")
			get_tree().create_timer(0.25).timeout.connect(_try_open_shm_path)
			return
		else:
			print("[FEAGI] [WS] SHM activation failed after ", _shm_init_attempts, " attempts; last_error=header too small size=", h.size())
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
			print("[FEAGI] [WS] SHM try ", _shm_init_attempts, "/", _shm_init_max_attempts, ": invalid magic '", magic, "' (expect FEAGIVIS/FEAGIBIN/FEAGIMOT)")
			get_tree().create_timer(0.25).timeout.connect(_try_open_shm_path)
			return
		else:
			print("[FEAGI] [WS] SHM activation failed after ", _shm_init_attempts, " attempts; last_error=invalid magic '", magic, "'")
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
			print("[FEAGI] [WS] SHM try ", _shm_init_attempts, "/", _shm_init_max_attempts, ": invalid header values slots=", num_slots, " slot_size=", slot_size)
			get_tree().create_timer(0.25).timeout.connect(_try_open_shm_path)
			return
		else:
			print("[FEAGI] [WS] SHM activation failed after ", _shm_init_attempts, " attempts; last_error=invalid header values slots=", num_slots, " slot_size=", slot_size)
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
	
	print("[FEAGI] [WS] Using SHM neuron visualization: ", p, " magic=", magic, " slots=", _shm_num_slots, " slot_size=", _shm_slot_size, " first_seq=", first_seq)
	shm_visualization_enabled.emit(p)
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
	# Detect SHM layout changes (e.g., FEAGI auto-resized slot size for large frames).
	# If FEAGI recreates the SHM file with a new slot_size/num_slots, we MUST reopen and
	# reinitialize offsets; otherwise we will seek into the wrong positions and decode garbage.
	var hdr_num_slots := int(h.decode_u32(12))
	var hdr_slot_size := int(h.decode_u32(16))
	if hdr_num_slots > 0 and hdr_slot_size > 0:
		if hdr_num_slots != _shm_num_slots or hdr_slot_size != _shm_slot_size:
			print("[SHM] Detected SHM layout change: slots %d→%d slot_size %d→%d. Reopening %s" % [
				_shm_num_slots, hdr_num_slots, _shm_slot_size, hdr_slot_size, _shm_path
			])
			_shm_file = null
			var f2 := FileAccess.open(_shm_path, FileAccess.READ)
			if f2 != null:
				_shm_file = f2
				_shm_num_slots = hdr_num_slots
				_shm_slot_size = hdr_slot_size
				_shm_last_seq = _decode_u64_le(h, 20) - 1
				_shm_missed_cycles = 0
				_shm_no_new_reported = false
			return
	var frame_seq := _decode_u64_le(h, 20)
	if frame_seq <= _shm_last_seq:
		_shm_missed_cycles += 1
		# Quiet repetitive logs; only print once per staleness streak
		if _shm_debug_logs and not _shm_no_new_reported:
			var wi := int(h.decode_u32(28))
			print("[FEAGI] [WS] SHM no new frame: head=", frame_seq, " last=", _shm_last_seq, " write_index=", wi)
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

	# Rate-limited SHM receive diagnostics for large payloads (e.g., MRI/NIFTI frames).
	# Confirms we received a payload and shows first byte (2=v2 container, 11=raw Type11).
	var now_ms_shm_rx := Time.get_ticks_msec()
	if now_ms_shm_rx - _shm_last_rx_log_ms >= _SHM_RX_LOG_INTERVAL_MS:
		_shm_last_rx_log_ms = now_ms_shm_rx
		var fb := int(payload[0]) if payload.size() > 0 else -1
		print("[SHM-RX] seq=%d payload_len=%d first_byte=%d slot_size=%d" % [
			frame_seq, payload_len, fb, _shm_slot_size
		])
	
	# Track update rate with timestamps and instantaneous FPS
	_shm_updates_received += 1
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Calculate instantaneous FPS from time between frames
	var frame_delta = 0.0
	var instant_fps = 0.0
	if _shm_last_frame_time > 0.0:
		frame_delta = current_time - _shm_last_frame_time
		if frame_delta > 0.0:
			instant_fps = 1.0 / frame_delta
			_shm_frame_times.append(instant_fps)
			if _shm_frame_times.size() > _SHM_FRAME_WINDOW_SIZE:
				_shm_frame_times.pop_front()
	_shm_last_frame_time = current_time
	
	# Log average rate every 5 seconds + instantaneous FPS
	if current_time - _shm_last_rate_log_time >= _shm_rate_log_interval:
		var elapsed = current_time - _shm_last_rate_log_time
		var avg_rate = _shm_updates_received / elapsed
		
		# Calculate rolling average FPS
		var avg_fps = 0.0
		if _shm_frame_times.size() > 0:
			var sum_fps = 0.0
			for fps in _shm_frame_times:
				sum_fps += fps
			avg_fps = sum_fps / _shm_frame_times.size()
		
		var timestamp = Time.get_datetime_string_from_system()
		print("[%s] [FEAGI] [BV-SHM] Receiving at %.1f Hz avg (%.1f Hz rolling, %d updates in %.1f sec) | Last frame: %.1f Hz (%.0f ms ago)" % [
			timestamp, avg_rate, avg_fps, _shm_updates_received, elapsed, instant_fps, frame_delta * 1000.0
		])
		_shm_updates_received = 0
		_shm_last_rate_log_time = current_time
	
	if _shm_debug_logs:
		print("[FEAGI] [WS] SHM frame ", frame_seq, " idx=", idx, " bytes=", payload_len)
	_process_wrapped_byte_structure(payload, true)  # from_shm=true

func enable_shared_memory_visualization(p: String) -> void:
	# Public API to switch to SHM immediately using a provided path
	if p == "":
		return
	OS.set_environment("FEAGI_VIZ_NEURONS_SHM", p)
	_pending_shm_path = p
	_shm_init_attempts = 0
	_shm_last_error = ""
	_shm_attempting = true
	# Reset polling throttle to recalculate from negotiated rate
	_shm_poll_interval = 0.0
	_shm_last_poll_time = 0.0
	# Give time for FEAGI to create and initialize the file header
	_ws_notice_printed = false
	_ws_notice_deadline_ms = Time.get_ticks_msec() + 2500
	print("[FEAGI] [WS] Enabling SHM neuron visualization via register; will retry: ", p)
	_try_open_shm_path()

func _decode_u64_le(bytes: PackedByteArray, offset: int) -> int:
	# Godot GDScript lacks decode_u64 on some versions; compose from two u32
	var lo := int(bytes.decode_u32(offset))
	var hi := int(bytes.decode_u32(offset + 4))
	return (hi << 32) | (lo & 0xFFFFFFFF)

func _bytes_to_hex(data: PackedByteArray, max_bytes: int = 20) -> String:
	"""Convert byte array to hex string for debugging"""
	var hex_str: String = ""
	var count: int = min(data.size(), max_bytes)
	for i in range(count):
		hex_str += "%02x " % data[i]
	if data.size() > max_bytes:
		hex_str += "... (%d more bytes)" % (data.size() - max_bytes)
	return hex_str

func _set_socket_health(new_health: WEBSOCKET_HEALTH) -> void:
	var prev_health: WEBSOCKET_HEALTH = _socket_health
	# Avoid no-op emissions to reduce downstream duplicate state handling.
	if prev_health == new_health:
		return
	_socket_health = new_health
	FEAGI_socket_health_changed.emit(prev_health, new_health)

# All deserialization is now handled by the Rust extension
# The _decode_type_11_optimized function has been removed as it's no longer needed
