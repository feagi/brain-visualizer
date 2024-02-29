extends Node
class_name UIManager
## Non-Autoload object that coordinates high level UI systems

enum MODE {
	CIRCUIT_BUILDER,
	VISUALIZER_3D
}

signal screen_size_changed(new_screen_size: Vector2)
signal UI_settings_changed()
signal user_changed_typing_status(is_typing: bool) ## Emits whenever a user starts / stops interaction with a text box
signal user_changed_window_drag_status(is_dragging_a_window: bool) ## Emits whenever a user starts / stops dragging a window
signal mode_changed(new_mode: MODE)
signal UI_scale_changed(multiplier: float)

@export var enable_developer_options: bool = false
@export var developer_options_key: Key = KEY_BACKSLASH

var screen_size: Vector2:  # keep as float for easy division
	get: return _screen_size

var screen_center: Vector2:
	get: return _screen_size / 2.0

var minimum_button_size_pixel: Vector2i:
	get: return _minimum_button_size_pixel
	set(v):
		_minimum_button_size_pixel = v
		UI_settings_changed.emit()

var window_manager: WindowManager:
	get: return _window_manager_ref

var current_mode: MODE:
	get: return _current_mode

## Is the user currently typing in a textbox somewhere
var is_user_typing: bool:
	get: return _is_user_typing
	set(v):
		_is_user_typing = v
		user_changed_typing_status.emit(v)

## Is the user currently dragging a window somewhere
var is_user_dragging_a_window: bool:
	get: return _is_user_dragging_a_window
	set(v):
		_is_user_dragging_a_window = v
		user_changed_window_drag_status.emit(v)

var UI_scale: float:
	get: return _UI_scale
	set(v):
		if v == _UI_scale:
			return
		_UI_scale = v
		UI_scale_changed.emit(v)

var circuit_builder: CorticalNodeGraph:
	get: return $temp_split/NodeGraph

var rosetta: Rosetta:
	get: return _rosetta

var _window_manager_ref: WindowManager
var _notification_system_ref: NotificationSystem
var _rosetta: Rosetta
var _screen_size: Vector2
var _minimum_button_size_pixel: Vector2i = Vector2i(40,40) # HINT: number should be divisible by 4
var _is_user_typing: bool = false
var _is_user_dragging_a_window: bool = false
var _current_mode: MODE = MODE.VISUALIZER_3D
var _UI_scale: float = 1.0

func _init():
	_rosetta = Rosetta.new()

func _ready():
	_screen_size = get_viewport().get_visible_rect().size
	get_viewport().size_changed.connect(_update_screen_size)
	_window_manager_ref = $Windows
	_notification_system_ref = $NotificationSystem
	VisConfig.UI_manager = self
	_update_screen_size()

func _input(event: InputEvent) -> void:
	if !enable_developer_options:
		return
	
	if !(event is InputEventKey):
		return
	
	var key_event: InputEventKey = event as InputEventKey
	if key_event.keycode == developer_options_key:
		window_manager.spawn_developer_options()

func set_mode(new_mode: MODE) -> void:
	_current_mode = new_mode
	match(new_mode):
		MODE.CIRCUIT_BUILDER:
			switch_to_circuit_builder()
		MODE.VISUALIZER_3D:
			switch_to_brain_visualizer_3D()
	mode_changed.emit(new_mode)

func switch_to_circuit_builder():
	var brain_visualizer = $Brain_Visualizer
	var brain_visualizer_back: FullScreenControl = $Brain_Visualizer/BV_Background

	circuit_builder.visible = true
	brain_visualizer.visible = false
	brain_visualizer_back.visible = false # hacky thing to do until this is corrected

func switch_to_brain_visualizer_3D():
	var brain_visualizer = $Brain_Visualizer
	var brain_visualizer_back: FullScreenControl = $Brain_Visualizer/BV_Background

	circuit_builder.visible = false
	brain_visualizer.visible = true
	brain_visualizer_back.visible = true # hacky thing to do until this is corrected

func make_notification(text: StringName, notification_type: SingleNotification.NOTIFICATION_TYPE = SingleNotification.NOTIFICATION_TYPE.INFO, time: float = SingleNotification.DEFAULT_TIME) -> void:
	_notification_system_ref.add_notification(text, notification_type, time)

func make_error_notification(key: StringName, replacements: Dictionary, notification_type: SingleNotification.NOTIFICATION_TYPE = SingleNotification.NOTIFICATION_TYPE.ERROR, time: float = SingleNotification.DEFAULT_TIME) -> void:
	var string_to_post: StringName = _rosetta.get_text(key, replacements)
	push_error("Posting error to user: %s" % string_to_post)
	_notification_system_ref.add_notification(string_to_post, notification_type, time)

	

#TODO TEMP
## Tell BV to create a new singular cortical area preview
func spawn_BV_single_preview(preview_dimensions: Vector3, preview_position: Vector3, color: Color = BrainMonitorSinglePreview.DEFAULT_COLOR, is_rendering: bool = true) -> BrainMonitorSinglePreview:
	var preview: BrainMonitorSinglePreview = $Brain_Visualizer.generate_single_preview(preview_dimensions, preview_position, color, is_rendering)
	return preview
	
func snap_camera_to_cortical_area(cortical_area: BaseCorticalArea) -> void:
	#TODO change behavior depending on BV / CB
	$Brain_Visualizer.snap_camera_to_cortical_area(cortical_area)

func temp_get_temp_split() -> TempSplit:
	return $temp_split

## Updates the screensize 
func _update_screen_size():
	_screen_size = get_viewport().get_visible_rect().size
	screen_size_changed.emit(screen_size)
	if OS.is_debug_build():
		print("UI: Window Size Change Detected!")

# Connected via top bar button
func _toggle_between_views() -> void:
	var modulo: int = (int(_current_mode) + 1) % len(MODE.keys())
	var new_state: MODE = MODE.values()[modulo]
	set_mode(new_state)
