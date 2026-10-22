extends Node
class_name FEAGISharedMemoryTransport
## Shared-memory transport for the FEAGI data stream (FEAGI -> Brain Visualizer). Activated by the
## FEAGI_VIZ_NEURONS_SHM / FEAGI_VIZ_SHM environment variables or [method enable_shared_memory_visualization].
## Polls the ring buffer at the negotiated rate and hands each new frame to the visualization sink.

signal shm_visualization_enabled(shm_path: String)

## Whether a shared-memory file is open and being polled.
var is_active: bool:
	get: return _use_shared_mem
## Path of the active shared-memory file, or "" when inactive.
var shm_path: String:
	get: return _shm_path

## Receives every packet read from shared memory. Set by [FEAGINetworking].
var visualization_sink: FEAGIVisualizationSink = null

var _use_shared_mem: bool = false
var _shm_path: String = ""
var _shm_file: FileAccess = null
var _shm_header_size: int = 256
var _shm_num_slots: int = 0
var _shm_slot_size: int = 0
var _shm_last_seq: int = -1
var _shm_notice_printed: bool = false
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
var _shm_last_frame_time: float = 0.0  # Track time between frames for instantaneous FPS
var _shm_frame_times: Array = []  # Rolling window of last 10 frame times
const _SHM_FRAME_WINDOW_SIZE: int = 10

# SHM polling throttle (to match negotiated rate)
var _shm_last_poll_time: float = 0.0
var _shm_poll_interval: float = 0.0  # Calculated from negotiated rate

# SHM diagnostics (rate-limited)
var _shm_last_rx_log_ms: int = 0
const _SHM_RX_LOG_INTERVAL_MS: int = 1000


func _ready() -> void:
	set_process(false) # polls only once a shared-memory file is open
	_init_shm_visualization()


func _process(_delta: float) -> void:
	# Throttle polling to negotiated rate (not every frame!)
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Update poll interval from negotiated rate if available
	if _shm_poll_interval == 0.0:
		# Try to get negotiated rate from parent FEAGINetworking
		var feagi_networking = get_parent()
		if feagi_networking and feagi_networking.has_meta("_negotiated_viz_hz"):
			var negotiated_hz = feagi_networking.get_meta("_negotiated_viz_hz")
			_shm_poll_interval = 1.0 / negotiated_hz
			print("[FEAGI] [SHM] SHM polling throttled to %.1f Hz (%.1f ms interval); path=%s" % [negotiated_hz, _shm_poll_interval * 1000.0, _shm_path])
		else:
			# Fallback: use 60 Hz (backwards compat)
			_shm_poll_interval = 1.0 / 60.0
			print("[FEAGI] [SHM] WARN: No negotiated rate found, defaulting to 60 Hz polling")
	
	# Only poll if enough time has elapsed
	if current_time - _shm_last_poll_time >= _shm_poll_interval:
		_poll_shm_once()
		_shm_last_poll_time = current_time
		
		if not _shm_notice_printed:
			var rate_hz = 1.0 / _shm_poll_interval if _shm_poll_interval > 0.0 else 60.0
			print("[FEAGI] [SHM] SHM polling active at %.1f Hz (throttled); path=%s" % [rate_hz, _shm_path])
			_shm_notice_printed = true


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
	print("[FEAGI] [SHM] Awaiting SHM neuron visualization path: ", p)
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
			print("[FEAGI] [SHM] SHM try ", _shm_init_attempts, "/", _shm_init_max_attempts, ": waiting for file: ", p)
			get_tree().create_timer(0.25).timeout.connect(_try_open_shm_path)
			return
		else:
			print("[FEAGI] [SHM] SHM activation failed: file never appeared: ", p)
			_shm_attempting = false
			_pending_shm_path = ""
			return
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		if _shm_init_attempts < _shm_init_max_attempts:
			_shm_init_attempts += 1
			var err := FileAccess.get_open_error()
			_shm_last_error = "open failed error=" + str(err)
			print("[FEAGI] [SHM] SHM try ", _shm_init_attempts, "/", _shm_init_max_attempts, ": open failed. error=", err)
			get_tree().create_timer(0.25).timeout.connect(_try_open_shm_path)
			return
		else:
			var err2 := FileAccess.get_open_error()
			print("[FEAGI] [SHM] SHM activation failed after ", _shm_init_attempts, " attempts; last_error=open failed error=", err2)
			_shm_attempting = false
			_pending_shm_path = ""
			return
	# Read header once to initialize
	f.seek(0)
	var h := f.get_buffer(_shm_header_size)
	if h.size() < 32:
		if _shm_init_attempts < _shm_init_max_attempts:
			_shm_init_attempts += 1
			_shm_last_error = "header too small size=" + str(h.size())
			print("[FEAGI] [SHM] SHM try ", _shm_init_attempts, "/", _shm_init_max_attempts, ": header too small (", h.size(), ")")
			get_tree().create_timer(0.25).timeout.connect(_try_open_shm_path)
			return
		else:
			print("[FEAGI] [SHM] SHM activation failed after ", _shm_init_attempts, " attempts; last_error=header too small size=", h.size())
			_shm_attempting = false
			_pending_shm_path = ""
			return
	var magic := ""
	for i in range(8):
		magic += char(h[i])
	if magic != "FEAGIVIS" and magic != "FEAGIBIN" and magic != "FEAGIMOT":
		if _shm_init_attempts < _shm_init_max_attempts:
			_shm_init_attempts += 1
			_shm_last_error = "invalid magic=" + magic
			print("[FEAGI] [SHM] SHM try ", _shm_init_attempts, "/", _shm_init_max_attempts, ": invalid magic '", magic, "' (expect FEAGIVIS/FEAGIBIN/FEAGIMOT)")
			get_tree().create_timer(0.25).timeout.connect(_try_open_shm_path)
			return
		else:
			print("[FEAGI] [SHM] SHM activation failed after ", _shm_init_attempts, " attempts; last_error=invalid magic '", magic, "'")
			_shm_attempting = false
			_pending_shm_path = ""
			return
	var num_slots := h.decode_u32(12)
	var slot_size := h.decode_u32(16)
	var first_seq := _decode_u64_le(h, 20)
	if num_slots <= 0 or slot_size <= 0:
		if _shm_init_attempts < _shm_init_max_attempts:
			_shm_init_attempts += 1
			_shm_last_error = "invalid header values slots=" + str(num_slots) + ", slot_size=" + str(slot_size)
			print("[FEAGI] [SHM] SHM try ", _shm_init_attempts, "/", _shm_init_max_attempts, ": invalid header values slots=", num_slots, " slot_size=", slot_size)
			get_tree().create_timer(0.25).timeout.connect(_try_open_shm_path)
			return
		else:
			print("[FEAGI] [SHM] SHM activation failed after ", _shm_init_attempts, " attempts; last_error=invalid header values slots=", num_slots, " slot_size=", slot_size)
			_shm_attempting = false
			_pending_shm_path = ""
			return
	_shm_num_slots = num_slots
	_shm_slot_size = slot_size
	_shm_last_seq = first_seq - 1
	_shm_file = f
	_shm_path = p
	_use_shared_mem = true
	set_process(true)
	_pending_shm_path = ""
	_shm_attempting = false
	
	# Initialize rate tracking
	_shm_updates_received = 0
	_shm_last_rate_log_time = Time.get_ticks_msec() / 1000.0
	
	print("[FEAGI] [SHM] Using SHM neuron visualization: ", p, " magic=", magic, " slots=", _shm_num_slots, " slot_size=", _shm_slot_size, " first_seq=", first_seq)
	shm_visualization_enabled.emit(p)
	_shm_notice_printed = false

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
			print("[FEAGI] [SHM] SHM no new frame: head=", frame_seq, " last=", _shm_last_seq, " write_index=", wi)
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
		print("[FEAGI] [SHM] SHM frame ", frame_seq, " idx=", idx, " bytes=", payload_len)
	if visualization_sink != null:
		visualization_sink.ingest_packet(payload)

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
	print("[FEAGI] [SHM] Enabling SHM neuron visualization via register; will retry: ", p)
	_try_open_shm_path()

func _decode_u64_le(bytes: PackedByteArray, offset: int) -> int:
	# Godot GDScript lacks decode_u64 on some versions; compose from two u32
	var lo := int(bytes.decode_u32(offset))
	var hi := int(bytes.decode_u32(offset + 4))
	return (hi << 32) | (lo & 0xFFFFFFFF)
