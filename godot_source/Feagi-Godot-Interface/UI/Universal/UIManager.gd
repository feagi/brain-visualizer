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

var screen_size: Vector2:  # keep as float for easy division
	get: return _screen_size

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

var _window_manager_ref: WindowManager
var _notification_system_ref: NotificationSystem
var _screen_size: Vector2
var _minimum_button_size_pixel: Vector2i = Vector2i(40,40) # HINT: number should be divisible by 4
var _is_user_typing: bool = false
var _is_user_dragging_a_window: bool = false
var _current_mode: MODE = MODE.VISUALIZER_3D

func _ready():
	_screen_size = get_viewport().get_visible_rect().size
	get_viewport().size_changed.connect(_update_screen_size)
	_window_manager_ref = $Windows
	_notification_system_ref = $NotificationSystem
	VisConfig.UI_manager = self
	_update_screen_size()
	#TEST


func set_mode(new_mode: MODE) -> void:
	_current_mode = new_mode
	match(new_mode):
		MODE.CIRCUIT_BUILDER:
			switch_to_circuit_builder()
		MODE.VISUALIZER_3D:
			switch_to_brain_visualizer_3D()
	mode_changed.emit(new_mode)

func switch_to_circuit_builder():
	var circuit_builder: CorticalNodeGraph = $NodeGraph
	var brain_visualizer = $Brain_Visualizer
	var brain_visualizer_back: FullScreenControl = $Brain_Visualizer/BV_Background

	circuit_builder.visible = true
	brain_visualizer.visible = false
	brain_visualizer_back.visible = false # hacky thing to do until this is corrected

func switch_to_brain_visualizer_3D():
	var circuit_builder: CorticalNodeGraph = $NodeGraph
	var brain_visualizer = $Brain_Visualizer
	var brain_visualizer_back: FullScreenControl = $Brain_Visualizer/BV_Background

	circuit_builder.visible = false
	brain_visualizer.visible = true
	brain_visualizer_back.visible = true # hacky thing to do until this is corrected

func make_notification(text: StringName, notification_type: SingleNotification.NOTIFICATION_TYPE = SingleNotification.NOTIFICATION_TYPE.INFO, time: float = SingleNotification.DEFAULT_TIME) -> void:
	_notification_system_ref.add_notification(text, notification_type, time)

## Tell BV to create a new singular cortical area preview
func start_new_cortical_area_preview(coordinates_changed: Signal, dimensions_changed: Signal, close_signals: Array[Signal]) -> CorticalBoxPreview:
	var preview: CorticalBoxPreview = $Brain_Visualizer.generate_prism_preview()
	coordinates_changed.connect(preview.update_position)
	dimensions_changed.connect(preview.update_size)
	for close_signal in close_signals:
		close_signal.connect(preview.delete_preview)
	return preview
	
func snap_camera_to_cortical_area(cortical_area: BaseCorticalArea) -> void:
	#TODO change behavior depending on BV / CB
	$Brain_Visualizer.snap_camera_to_cortical_area(cortical_area)

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
