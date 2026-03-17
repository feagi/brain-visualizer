extends Node
## WindowStateManager
## Automatically saves and restores window position and size across application restarts
## Handles multi-monitor setups and validates saved state

const STATE_FILE_PATH = "user://window_state.json"
const MIN_WINDOW_WIDTH = 800
const MIN_WINDOW_HEIGHT = 600

var _state_data: Dictionary = {}
var _save_timer: Timer
var _debounce_delay = 0.5  # Seconds to wait before saving after window change
var _last_saved_position: Vector2i = Vector2i.ZERO
var _position_check_timer: float = 0.0
var _position_check_interval: float = 1.0  # Check position every second

func _ready() -> void:
	# Load saved state
	_load_window_state()
	
	# Create debounce timer for saving
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.timeout.connect(_save_window_state)
	add_child(_save_timer)
	
	# Restore window state immediately (position and size are applied synchronously)
	_restore_window_state()
	
	# Get main window reference
	var window = get_tree().root
	
	# Initialize last saved position to current position
	_last_saved_position = window.position
	
	# Connect to window events for auto-save
	window.size_changed.connect(_on_window_changed)
	window.close_requested.connect(_on_window_close_requested)
	
	print("[WindowStateManager] Window state manager initialized")

func _process(delta: float) -> void:
	# Poll position changes periodically (Godot has no position_changed signal)
	_position_check_timer += delta
	if _position_check_timer >= _position_check_interval:
		_position_check_timer = 0.0
		_check_position_changed()

func _check_position_changed() -> void:
	var window = get_tree().root
	var current_pos = window.position
	
	# Only trigger save if position actually changed
	if current_pos != _last_saved_position:
		print("[WindowStateManager] Position changed: (%d, %d) -> (%d, %d)" % [
			_last_saved_position.x, _last_saved_position.y,
			current_pos.x, current_pos.y
		])
		_last_saved_position = current_pos
		_on_window_changed()  # Trigger debounced save

func _on_window_changed() -> void:
	# Debounce saves to avoid excessive file writes during resize/move
	if _save_timer.is_stopped():
		_save_timer.start(_debounce_delay)

func _on_window_close_requested() -> void:
	# Save immediately on close
	_save_window_state()
	# Allow the window to close
	get_tree().quit()

func _load_window_state() -> void:
	if not FileAccess.file_exists(STATE_FILE_PATH):
		print("[WindowStateManager] No saved window state found")
		return
	
	var file = FileAccess.open(STATE_FILE_PATH, FileAccess.READ)
	if file == null:
		push_error("[WindowStateManager] Failed to open window state file: " + str(FileAccess.get_open_error()))
		return
	
	var raw_bytes = file.get_buffer(file.get_length())
	file.close()
	
	# Prevent Unicode parser errors when file contains UTF-16/binary data.
	if raw_bytes.find(0) != -1:
		push_warning("[WindowStateManager] window_state.json contains NUL bytes; ignoring corrupted state file")
		return
	
	var json_string = raw_bytes.get_string_from_utf8()
	if json_string.is_empty() and raw_bytes.size() > 0:
		push_warning("[WindowStateManager] window_state.json is not valid UTF-8; ignoring corrupted state file")
		return
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("[WindowStateManager] Failed to parse window state JSON")
		return
	
	_state_data = json.data
	print("[WindowStateManager] Loaded window state: ", _state_data)

func _save_window_state() -> void:
	var window = get_tree().root
	
	# Get current window state
	var state = {
		"position": {
			"x": window.position.x,
			"y": window.position.y
		},
		"size": {
			"width": window.size.x,
			"height": window.size.y
		},
		"mode": window.mode,  # Windowed, fullscreen, etc.
		"screen": window.current_screen
	}
	
	# Validate state before saving
	if state.size.width < MIN_WINDOW_WIDTH or state.size.height < MIN_WINDOW_HEIGHT:
		print("[WindowStateManager] Rejecting invalid window size: ", state.size.width, "x", state.size.height)
		return
	
	_state_data = state
	
	# Save to file
	var file = FileAccess.open(STATE_FILE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[WindowStateManager] Failed to save window state: " + str(FileAccess.get_open_error()))
		return
	
	var json_string = JSON.stringify(_state_data, "\t")
	file.store_string(json_string)
	file.close()
	
	print("[WindowStateManager] Saved window state: pos=(%d, %d) size=%dx%d screen=%d" % [
		state.position.x, state.position.y,
		state.size.width, state.size.height,
		state.screen
	])

func _restore_window_state() -> void:
	if _state_data.is_empty():
		print("[WindowStateManager] No window state to restore, using defaults")
		return
	
	var window = get_tree().root
	
	# Validate saved state
	var saved_width = _state_data.get("size", {}).get("width", 0)
	var saved_height = _state_data.get("size", {}).get("height", 0)
	var saved_x = _state_data.get("position", {}).get("x", 0)
	var saved_y = _state_data.get("position", {}).get("y", 0)
	
	if saved_width < MIN_WINDOW_WIDTH or saved_height < MIN_WINDOW_HEIGHT:
		print("[WindowStateManager] Saved size %dx%d is below minimum %dx%d, using defaults" % [
			saved_width, saved_height, MIN_WINDOW_WIDTH, MIN_WINDOW_HEIGHT
		])
		return
	
	# Validate position (ensure it's not completely off-screen)
	# Allow negative positions for multi-monitor setups
	var screen_count = DisplayServer.get_screen_count()
	var saved_screen = _state_data.get("screen", 0)
	
	if saved_screen >= screen_count:
		print("[WindowStateManager] Saved screen %d no longer exists (only %d screens), using primary" % [
			saved_screen, screen_count
		])
		saved_screen = 0
	
	# Restore window mode first
	var saved_mode = _state_data.get("mode", Window.MODE_WINDOWED)
	if saved_mode != Window.MODE_MINIMIZED:  # Don't restore minimized state
		window.mode = saved_mode
	
	# Only restore position/size in windowed mode
	if window.mode == Window.MODE_WINDOWED:
		# CRITICAL: Set position FIRST (determines which monitor), THEN size
		# This prevents the window from appearing on the wrong monitor first
		window.position = Vector2i(saved_x, saved_y)
		
		# Small delay to let position settle before setting size
		await get_tree().process_frame
		
		# Now set size on the correct monitor
		window.size = Vector2i(saved_width, saved_height)
		
		# Ensure the screen is set (might be redundant but ensures correctness)
		window.current_screen = saved_screen
		
		print("[WindowStateManager] Restored window state: pos=(%d, %d) size=%dx%d screen=%d" % [
			saved_x, saved_y, saved_width, saved_height, saved_screen
		])
	else:
		print("[WindowStateManager] Skipping position/size restore (window mode: %d)" % window.mode)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Save on window close request
		_save_window_state()
