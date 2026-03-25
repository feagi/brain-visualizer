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
signal FEAGI_sent_direct_neural_points_bulk(cortical_ID: StringName, x_array: PackedInt32Array, y_array: PackedInt32Array, z_array: PackedInt32Array, p_array: PackedFloat32Array)
signal feagi_requesting_reset()
signal feagi_return_visual_data(SingleRawImage: PackedByteArray)
signal shm_visualization_enabled(shm_path: String)


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

# Missing cortical area handling
var _missing_cortical_areas: Dictionary = {}  # cortical_id -> {last_warning_time, fetch_attempted}
const MISSING_AREA_WARNING_INTERVAL: float = 10.0  # Only warn every 10 seconds per area

# Case-insensitive cortical area mapping cache
var _case_mapping_cache: Dictionary = {}  # lowercase_id -> actual_cached_id

# Rust-based high-performance deserializer
var _rust_deserializer = null
const WASMDecoder = preload("res://Utils/WASMDecoder.gd")

# Desktop-only WS fast-path: apply Type 11 packets directly to MultiMesh via Rust (no per-area arrays/signal dispatch).
const _USE_DESKTOP_TYPE11_FASTPATH: bool = true
var _bv_fast_multimeshes_by_id: Dictionary = {}
var _bv_fast_dimensions_by_id: Dictionary = {}
var _bv_fast_cache_last_refresh_ms: int = 0
const _BV_FAST_CACHE_REFRESH_INTERVAL_MS: int = 1000

# Queue Type 11 messages on Web until WASM is ready
var _pending_type11: Array = []
var _waiting_for_wasm: bool = false
var _rust_init_attempts: int = 0
const MAX_RUST_INIT_ATTEMPTS := 5

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
# One-time warning when Type 11 is skipped due to missing Rust deserializer (no silent drop)
var _ws_deserializer_missing_warned: bool = false

# WS receive diagnostics (rate-limited)
var _ws_last_rx_log_ms: int = 0
const _WS_RX_LOG_INTERVAL_MS: int = 1000
var _ws_last_apply_log_ms: int = 0
const _WS_APPLY_LOG_INTERVAL_MS: int = 1000

# Opt-in Type 11 root-cause: set env BV_TYPE11_ROOTCAUSE=1 (see RECONNECTION_FIX.md)
const _TYPE11_ROOTCAUSE_LOG_INTERVAL_MS: int = 2000
const _TYPE11_ROOTCAUSE_REBUILD_LOG_MS: int = 3000
var _type11_rootcause_last_packet_log_ms: int = 0
var _type11_rootcause_last_rebuild_log_ms: int = 0
var _type11_rootcause_banner_printed: bool = false
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
var _shm_last_apply_log_ms: int = 0
const _SHM_APPLY_LOG_INTERVAL_MS: int = 1000


func _ready():
	# Initialize platform-specific decoding path
	if OS.has_feature("web"):
		print("🌐 Web build detected: using WASM decoder; native GDExtension is unavailable on Web.")
		# Kick off WASM loader early so it's ready by the time data arrives
		WASMDecoder.ensure_wasm_loaded()
	else:
		# Initialize Rust-based high-performance deserializer (REQUIRED on desktop)
		_init_rust_deserializer()

	# [FEAGI] Try to initialize shared memory visualization (env-provided path)
	_init_shm_visualization()
	# Defer WS fallback notice to allow registration to provide SHM path
	_ws_notice_deadline_ms = Time.get_ticks_msec() + 3000
	
	# Reset missing area tracking when genome reloads
	if FeagiCore.feagi_local_cache:
		FeagiCore.feagi_local_cache.genome_cache_replaced.connect(_on_genome_reloaded)
		FeagiCore.feagi_local_cache.cortical_areas_reloaded.connect(_on_genome_reloaded)

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
			if _shm_last_error != "":
				print("[FEAGI] [WS] Neuron visualization using WebSocket (SHM disabled); last_shm_error=", _shm_last_error)
			else:
				print("[FEAGI] [WS] Neuron visualization using WebSocket (SHM disabled)")
			_ws_notice_printed = true
	# On Web, flush queued Type 11 packets once WASM is ready
	if OS.has_feature("web") and WASMDecoder.is_wasm_ready() and _pending_type11.size() > 0:
		# Process all queued before polling socket
		for i in range(_pending_type11.size()):
			var qbytes: PackedByteArray = _pending_type11[i]
			var decoded_result: Dictionary = WASMDecoder.decode_type_11(qbytes)
			if decoded_result and decoded_result.has("success") and decoded_result.success == true:
				for cortical_id in decoded_result.areas.keys():
					# Filter out _death area (non-visualizable), but allow _power (has custom cone animation)
					if AbstractCorticalArea.is_death_area(cortical_id):
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
				print("[%s] ✅ [WS] STATE_OPEN detected - current _socket_health: %s" % [_get_timestamp(), WEBSOCKET_HEALTH.keys()[_socket_health]])
				print("[%s] ✅ [WS] Transitioning to CONNECTED state - notifying network layer" % _get_timestamp())
				_set_socket_health(WEBSOCKET_HEALTH.CONNECTED)
			
			var backlog_start := _socket.get_available_packet_count()
			var drained_packets := 0
			var drained_bytes := 0
			var t_start_us := Time.get_ticks_usec()

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

			if newest_binary_len > 0:
				if not _rust_deserializer:
					# Deserializer GDExtension not loaded: Type 11 WebSocket data is dropped; neural activity will not render until it is available.
					if not _ws_deserializer_missing_warned:
						_ws_deserializer_missing_warned = true
						push_warning("[WS] Rust deserializer (FeagiDataDeserializer) not available. WebSocket Type 11 neural data is not being processed; build/enable rust_extensions/feagi_data_deserializer for neural activity.")
				else:
					if _USE_DESKTOP_TYPE11_FASTPATH and not OS.has_feature("web"):
						_refresh_bv_fastpath_cache_if_needed()
						var perf: Dictionary = _rust_deserializer.apply_type11_packet_to_multimeshes(
							newest_binary,
							_bv_fast_multimeshes_by_id,
							_bv_fast_dimensions_by_id,
							true # clear_all_before_apply
						)
						# Rate-limited decode/apply diagnostics to pinpoint "receiving but not rendering".
						# This will tell us if Rust decoded/applied any areas at all (and if it errored).
						var now_ms_apply := Time.get_ticks_msec()
						if _WS_DIAGNOSTICS_ENABLED and now_ms_apply - _ws_last_apply_log_ms >= _WS_APPLY_LOG_INTERVAL_MS:
							_ws_last_apply_log_ms = now_ms_apply
							var ok_apply := bool(perf.get("success", false))
							var err_apply := String(perf.get("error", ""))
							var areas_applied := int(perf.get("areas_applied", 0))
							var neurons_applied := int(perf.get("neurons_applied", 0))
							print("[WS-APPLY] ok=%s areas_applied=%d neurons_applied=%d err='%s'" % [
								str(ok_apply), areas_applied, neurons_applied, err_apply
							])
						# Memory areas may not have a registered MultiMesh in the desktop fast-path cache.
						# Areas with multiple BV renderers cannot rely on the single-MultiMesh fast-path either.
						# Route those areas through the standard bulk-array path using decoded Type11 data.
						var decoded: Dictionary = _rust_deserializer.decode_type_11_data(newest_binary)
						var ok: bool = bool(decoded.get("success", false))
						var areas_any: Variant = decoded.get("areas", null)
						var areas: Dictionary = {}
						if areas_any is Dictionary:
							areas = areas_any
						if ok and areas_any is Dictionary:
							for cortical_id in areas.keys():
								var clean_id := String(cortical_id).strip_edges().replace("'", "").replace('"', "")
								var area_obj: AbstractCorticalArea = _get_cortical_area_case_insensitive(clean_id)
								if area_obj == null:
									continue
								var requires_bulk := area_obj.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY
								requires_bulk = requires_bulk or area_obj.BV_requires_bulk_directpoints_updates()
								if not requires_bulk:
									continue
								var area_any: Variant = areas.get(cortical_id, null)
								var area_data: Dictionary = area_any as Dictionary
								var x_array: PackedInt32Array = area_data.get("x_array", PackedInt32Array())
								var y_array: PackedInt32Array = area_data.get("y_array", PackedInt32Array())
								var z_array: PackedInt32Array = area_data.get("z_array", PackedInt32Array())
								var p_array: PackedFloat32Array = area_data.get("p_array", PackedFloat32Array())
								var n := x_array.size()
								if n > 0:
									area_obj.FEAGI_set_direct_points_bulk_data(x_array, y_array, z_array, p_array)
									area_obj.BV_notify_directpoints_activity(n)
						# Optional: preserve side-effects (timers/animations) without moving arrays through signals.
						if perf and perf.has("area_counts"):
							for cortical_id in perf.area_counts.keys():
								var count: int = int(perf.area_counts[cortical_id])
								var clean_id := String(cortical_id).strip_edges().replace("'", "").replace('"', "")
								var area: AbstractCorticalArea = _get_cortical_area_case_insensitive(clean_id)
								if area:
									area.BV_notify_directpoints_activity(count)
						# Extend existing diag with stage timings (rate-limited below).
						if perf:
							set_meta("_ws_last_perf", perf)
						_type11_rootcause_log_packet_vs_fastpath(areas, perf)
					else:
						# Legacy desktop path (kept for parity/testing); web uses WASM decoder above.
						var decoded_result: Dictionary = _rust_deserializer.decode_type_11_data(newest_binary)
						if not decoded_result or not decoded_result.has("success"):
							push_error("❌ [WS] Decode failed - no result returned")
						elif not decoded_result.success:
							var error_msg := decoded_result.get("error", "unknown error")
							push_error("❌ [WS] Decode failed: %s" % error_msg)
						else:
							for cortical_id in decoded_result.areas.keys():
								var area_data = decoded_result.areas[cortical_id]
								# Perf: Rust deserializer already returns PackedArrays; avoid repacking/copying here.
								var x_array := area_data.get("x_array") as PackedInt32Array
								var y_array := area_data.get("y_array") as PackedInt32Array
								var z_array := area_data.get("z_array") as PackedInt32Array
								var p_array := area_data.get("p_array") as PackedFloat32Array
								
								FEAGI_sent_direct_neural_points_bulk.emit(cortical_id, x_array, y_array, z_array, p_array)
								var area: AbstractCorticalArea = _get_cortical_area_case_insensitive(cortical_id)
								if area:
									area.FEAGI_set_direct_points_bulk_data(x_array, y_array, z_array, p_array)
								else:
									_handle_missing_cortical_area(cortical_id)

			var now_ms := Time.get_ticks_msec()
			if now_ms - _ws_last_backlog_log_ms >= 5000:
				_ws_last_backlog_log_ms = now_ms
				var elapsed_ms := float(Time.get_ticks_usec() - t_start_us) / 1000.0
				var perf_tail := ""
				if has_meta("_ws_last_perf"):
					var perf = get_meta("_ws_last_perf")
					if perf and perf.has("total_ms"):
						perf_tail = " | lz4_ms=%.2f parse_ms=%.2f clear_ms=%.2f apply_ms=%.2f areas=%d neurons=%d" % [
							float(perf.get("lz4_ms", 0.0)),
							float(perf.get("container_parse_ms", 0.0)),
							float(perf.get("clear_ms", 0.0)),
							float(perf.get("multimesh_apply_ms", 0.0)),
							int(perf.get("areas_applied", 0)),
							int(perf.get("neurons_applied", 0)),
						]
				# (Log removed) Periodic WS backlog/perf diagnostics can be noisy in normal operation.
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
				var total_points := 0
				for cortical_id in areas.keys():
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
				# Use Rust-based high-performance deserializer (required on desktop; optional when GDExtension disabled)
				if _rust_deserializer == null:
					if not _ws_deserializer_missing_warned:
						_ws_deserializer_missing_warned = true
						push_warning("[WS] Rust deserializer (FeagiDataDeserializer) not available. Type 11 neural data is not being processed; build/enable rust_extensions/feagi_data_deserializer for neural activity.")
					return
				var decoded_result: Dictionary = _rust_deserializer.decode_type_11_data(bytes)
				if !decoded_result.success:
					print("   ❌ ERROR: Type 11 decode failed: ", decoded_result.error)
					return

				# Rate-limited SHM decode diagnostics (high-signal for "large scale shows nothing").
				# Only logs when the packet came from SHM.
				if from_shm:
					var now_ms_shm_apply := Time.get_ticks_msec()
					if now_ms_shm_apply - _shm_last_apply_log_ms >= _SHM_APPLY_LOG_INTERVAL_MS:
						_shm_last_apply_log_ms = now_ms_shm_apply
						var areas_dict: Dictionary = decoded_result.get("areas", {})
						var area_count := areas_dict.size() if typeof(areas_dict) == TYPE_DICTIONARY else 0
						var power_points := 0
						if typeof(areas_dict) == TYPE_DICTIONARY:
							for k in areas_dict.keys():
								var clean_id := String(k).strip_edges().replace("'", "").replace('"', "")
								if AbstractCorticalArea.is_power_area(clean_id):
									var a_any: Variant = areas_dict.get(k)
									var a: Dictionary = a_any as Dictionary
									var x_arr: PackedInt32Array = a.get("x_array", PackedInt32Array())
									power_points = x_arr.size()
									break
						print("[SHM-APPLY] ok=true areas=%d power_points=%d" % [area_count, power_points])

				# Process each decoded cortical area with DIRECT bulk arrays (no conversion loops!)
				for cortical_id in decoded_result.areas.keys():
					var area_data = decoded_result.areas[cortical_id]
					# Strip quotes that Rust may add
					var clean_id := String(cortical_id).strip_edges().replace("'", "").replace('"', "")
					FEAGI_sent_direct_neural_points_bulk.emit(
						clean_id,
						area_data.x_array,
						area_data.y_array,
						area_data.z_array,
						area_data.p_array
					)
					var area: AbstractCorticalArea = _get_cortical_area_case_insensitive(clean_id)
					if area:
						area.FEAGI_set_direct_points_bulk_data(area_data.x_array, area_data.y_array, area_data.z_array, area_data.p_array)
					else:
						_handle_missing_cortical_area(clean_id)

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


func _type11_rootcause_enabled() -> bool:
	var v := str(OS.get_environment("BV_TYPE11_ROOTCAUSE")).strip_edges().to_lower()
	return v == "1" or v == "true" or v == "yes"


func _normalize_type11_cortical_key(key: Variant) -> String:
	return String(key).strip_edges().replace("'", "").replace('"', "")


func _type11_rootcause_sample_ids(ids: Array, max_n: int) -> String:
	if ids.is_empty():
		return "[]"
	var out: PackedStringArray = []
	var n: int = mini(ids.size(), max_n)
	for i in range(n):
		out.append(str(ids[i]))
	var tail := ", ..." if ids.size() > max_n else ""
	return "[%s]%s" % [", ".join(out), tail]


## Logs fast-path MultiMesh registration count (throttled). Enable with BV_TYPE11_ROOTCAUSE=1.
func _type11_rootcause_log_fastpath_rebuild(registered_multimesh: int) -> void:
	if not _type11_rootcause_enabled():
		return
	var now_ms := Time.get_ticks_msec()
	if now_ms - _type11_rootcause_last_rebuild_log_ms < _TYPE11_ROOTCAUSE_REBUILD_LOG_MS:
		return
	_type11_rootcause_last_rebuild_log_ms = now_ms
	if not _type11_rootcause_banner_printed:
		_type11_rootcause_banner_printed = true
		print("[TYPE11-ROOTCAUSE] Diagnostics ON (BV_TYPE11_ROOTCAUSE=1). Packet detail every %d ms; rebuild summary every %d ms." % [_TYPE11_ROOTCAUSE_LOG_INTERVAL_MS, _TYPE11_ROOTCAUSE_REBUILD_LOG_MS])
	print("[TYPE11-ROOTCAUSE] fast_path rebuild: cortical_ids_with_multimesh=%d" % registered_multimesh)


## Compare Type 11 payload cortical ids to fast-path map and cache objects (throttled).
func _type11_rootcause_log_packet_vs_fastpath(decoded_areas: Dictionary, perf: Dictionary) -> void:
	if not _type11_rootcause_enabled():
		return
	var now_ms := Time.get_ticks_msec()
	if now_ms - _type11_rootcause_last_packet_log_ms < _TYPE11_ROOTCAUSE_LOG_INTERVAL_MS:
		return
	_type11_rootcause_last_packet_log_ms = now_ms

	var fast_norm: Dictionary = {}
	for fk in _bv_fast_multimeshes_by_id.keys():
		fast_norm[_normalize_type11_cortical_key(fk)] = true

	var packet_norm: PackedStringArray = []
	var seen: Dictionary = {}
	for ck in decoded_areas.keys():
		var cid := _normalize_type11_cortical_key(ck)
		if cid.is_empty() or seen.has(cid):
			continue
		seen[cid] = true
		packet_norm.append(cid)

	var missing_cache: Array[String] = []
	var no_mesh_ipu_like: Array[String] = []
	var in_packet_not_in_fastmap: Array[String] = []

	for cid in packet_norm:
		var area_obj: AbstractCorticalArea = _get_cortical_area_case_insensitive(cid)
		if area_obj == null:
			missing_cache.append(cid)
			continue
		var requires_bulk := area_obj.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY
		requires_bulk = requires_bulk or area_obj.BV_requires_bulk_directpoints_updates()
		var mm = area_obj.BV_get_directpoints_multimesh()
		if mm == null and not requires_bulk:
			no_mesh_ipu_like.append(cid)
		if not fast_norm.has(cid):
			in_packet_not_in_fastmap.append(cid)

	var ok_apply := bool(perf.get("success", false))
	var areas_applied := int(perf.get("areas_applied", 0))
	var neurons_applied := int(perf.get("neurons_applied", 0))
	var err_apply := str(perf.get("error", ""))

	print("[TYPE11-ROOTCAUSE] frame: packet_cortical_ids=%d fast_path_keys=%d apply_ok=%s areas_applied=%d neurons_applied=%d err='%s'" % [
		packet_norm.size(), fast_norm.size(), str(ok_apply), areas_applied, neurons_applied, err_apply
	])
	if not missing_cache.is_empty():
		print("[TYPE11-ROOTCAUSE] ids in packet but NO AbstractCorticalArea in BV cache (sample): %s" % _type11_rootcause_sample_ids(missing_cache, 8))
	if not no_mesh_ipu_like.is_empty():
		print("[TYPE11-ROOTCAUSE] ids need fast-path MultiMesh but BV_get_directpoints_multimesh()==null (no bulk fallback; sample): %s" % _type11_rootcause_sample_ids(no_mesh_ipu_like, 8))
	if not in_packet_not_in_fastmap.is_empty():
		print("[TYPE11-ROOTCAUSE] ids in packet not present in _bv_fast_multimeshes_by_id after refresh (sample): %s" % _type11_rootcause_sample_ids(in_packet_not_in_fastmap, 8))


func _refresh_bv_fastpath_cache_if_needed() -> void:
	if OS.has_feature("web"):
		return
	var now_ms := Time.get_ticks_msec()
	# If the fast-path map is empty (e.g. after genome/cortical reload), always rebuild so Type 11 can target new MultiMeshes.
	if _bv_fast_multimeshes_by_id.size() > 0 and (now_ms - _bv_fast_cache_last_refresh_ms < _BV_FAST_CACHE_REFRESH_INTERVAL_MS):
		return
	_bv_fast_cache_last_refresh_ms = now_ms
	_bv_fast_multimeshes_by_id.clear()
	_bv_fast_dimensions_by_id.clear()
	if not FeagiCore.feagi_local_cache:
		return
	var areas_dict: Dictionary = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas
	var registered_multimesh: int = 0
	for cortical_id in areas_dict.keys():
		var area: AbstractCorticalArea = areas_dict.get(cortical_id)
		if area == null:
			continue
		# Normalize keys to String for stable Rust lookups (StringName vs String key mismatches are easy to hit).
		var key_str := String(cortical_id).strip_edges().replace("'", "").replace('"', "")
		var mm := area.BV_get_directpoints_multimesh()
		if mm != null:
			# Keep renderer visuals (mesh sizing) in sync with latest cortical properties.
			# Desktop Type11 fast-path bypasses per-area bulk signals, so we refresh explicitly here.
			area.BV_refresh_directpoints_renderer_visuals()
			_bv_fast_multimeshes_by_id[key_str] = mm
			_bv_fast_dimensions_by_id[key_str] = area.BV_get_directpoints_dimensions()
			registered_multimesh += 1
	_type11_rootcause_log_fastpath_rebuild(registered_multimesh)

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

func _handle_missing_cortical_area(cortical_id: StringName) -> void:
	# FILTER CORE AREAS FIRST - before any logging or processing
	# Convert to String for robust comparison (StringName may have different comparison semantics)
	var cortical_id_str := String(cortical_id)
	
	# Handle both quoted and unquoted versions (cortical ID may come with quotes)
	var clean_id := cortical_id_str.strip_edges().replace("'", "").replace('"', "")
	
	if AbstractCorticalArea.is_death_area(clean_id):
		# Death area cannot be visualized - silently ignore
		# Note: Power area CAN be visualized with custom cone animation, so allow it through
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
	# Debug log suppressed to reduce runtime console spam.
	_missing_cortical_areas.clear()
	_case_mapping_cache.clear()  # Clear case mapping cache too
	# Force immediate rebuild of desktop Type11 fast-path caches on next packet.
	_bv_fast_multimeshes_by_id.clear()
	_bv_fast_dimensions_by_id.clear()
	_bv_fast_cache_last_refresh_ms = 0
	# Brain Monitor may create DirectPoints MultiMeshes after this signal; rebuild fast-path map once the tree has settled.
	call_deferred("_deferred_rebuild_bv_fastpath_after_cache_touch")

## Re-scan cortical areas for MultiMesh registration after genome / incremental cortical refresh (desktop Type 11 fast path).
func _deferred_rebuild_bv_fastpath_after_cache_touch() -> void:
	if OS.has_feature("web"):
		return
	_bv_fast_cache_last_refresh_ms = 0
	_refresh_bv_fastpath_cache_if_needed()


## Public hook for Brain Monitor: after 3D cortical nodes re-register DirectPoints MultiMeshes on new cache
## instances, rebuild the desktop Type 11 map so packets target the current MultiMeshes (reconnect safe).
func request_bv_fastpath_cache_rebuild() -> void:
	if OS.has_feature("web"):
		return
	_bv_fast_multimeshes_by_id.clear()
	_bv_fast_dimensions_by_id.clear()
	_bv_fast_cache_last_refresh_ms = 0
	call_deferred("_deferred_rebuild_bv_fastpath_after_cache_touch")

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
