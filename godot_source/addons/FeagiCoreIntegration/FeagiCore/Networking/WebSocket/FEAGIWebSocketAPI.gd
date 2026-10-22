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
# FEAGI may never acknowledge a close frame; past this the socket is dropped and handled as closed.
const DEF_CLOSE_TIMEOUT_SECONDS: float = 3.0
const SOCKET_GENOME_UPDATE_FLAG: String = "updated" # FEAGI sends this string via websocket if genome is reloaded / changed
const SOCKET_GENEOME_UPDATE_LATENCY: String = "ping" # TODO DELETE

signal FEAGI_socket_health_changed(previous_health: WEBSOCKET_HEALTH, current_health: WEBSOCKET_HEALTH)
signal FEAGI_socket_retrying_connection(retry_count: int, max_retry_count: int)
signal feagi_requesting_reset()


var socket_health: WEBSOCKET_HEALTH:
	get: return _socket_health

## Connection attempts since the last successful connect.
var retry_count: int:
	get: return _retry_count

## Receives every binary packet this transport delivers. Set by [FEAGINetworking].
var visualization_sink: FEAGIVisualizationSink = null
## While shared memory carries the stream, WebSocket connects are suppressed. Set by [FEAGINetworking].
var shm_transport: FEAGISharedMemoryTransport = null

#var _cache_websocket_data: PackedByteArray # outside to try to avoid reallocation penalties # NOTE: Godot doesnt seem to care and reallocates anyways lol
var _socket_web_address: StringName = ""
var _socket: WebSocketPeer
var _socket_health: WEBSOCKET_HEALTH = WEBSOCKET_HEALTH.NO_CONNECTION
var _retry_count: int = 0
var _is_purposfully_disconnecting: bool = false
var _last_connect_time: int = 0  # Track when we last attempted to connect
var _retry_timer_active: bool = false  # Track if a retry timer is already running
var _last_disconnect_time: int = 0  # Track last disconnect to prevent rapid processing
var _closing_since_ms: int = 0  # When the socket entered CLOSING; 0 when not closing

const WASMDecoder = preload("res://Utils/WASMDecoder.gd")
var _waiting_for_wasm: bool = false

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



func _process(_delta: float):
	# [FEAGI] Guard: If socket is null (e.g. never connected when using SHM), skip WebSocket polling but continue to SHM polling below
	if not _socket:
		# SHM polling for neuron visualization happens at end of _process()
		# But if we also use SHM for video, that's handled by WindowViewPreviews directly
		return

	_socket.poll()
	if _socket.get_ready_state() != WebSocketPeer.State.STATE_CLOSING:
		_closing_since_ms = 0
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
				visualization_sink.ingest_packet(newest_binary)
		WebSocketPeer.State.STATE_CLOSING:
			# Closing connection to FEAGI, waiting for FEAGI to respond to close request.
			# Without a deadline an unacknowledged close leaves the socket here forever: no data,
			# health still CONNECTED, and no retry.
			var now_closing_ms := Time.get_ticks_msec()
			if _closing_since_ms == 0:
				_closing_since_ms = now_closing_ms
			elif now_closing_ms - _closing_since_ms > int(DEF_CLOSE_TIMEOUT_SECONDS * 1000.0):
				print("[%s] ⚠️ [WS] Close not acknowledged after %dms - dropping socket" % [_get_timestamp(), now_closing_ms - _closing_since_ms])
				_closing_since_ms = 0
				_socket.close(-1) # drop without handshake; the next poll takes the CLOSED path
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
	if shm_transport != null and shm_transport.is_active:
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

func _get_timestamp() -> String:
	var time = Time.get_time_dict_from_system()
	return "%02d:%02d:%02d.%03d" % [time.hour, time.minute, time.second, Time.get_ticks_msec() % 1000]

func _reconnect_websocket() -> void:
	# If SHM neuron visualization is active, do not attempt WS reconnects.
	if shm_transport != null and shm_transport.is_active:
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

func _set_socket_health(new_health: WEBSOCKET_HEALTH) -> void:
	var prev_health: WEBSOCKET_HEALTH = _socket_health
	# Avoid no-op emissions to reduce downstream duplicate state handling.
	if prev_health == new_health:
		return
	_socket_health = new_health
	FEAGI_socket_health_changed.emit(prev_health, new_health)

# All deserialization is now handled by the Rust extension
# The _decode_type_11_optimized function has been removed as it's no longer needed
