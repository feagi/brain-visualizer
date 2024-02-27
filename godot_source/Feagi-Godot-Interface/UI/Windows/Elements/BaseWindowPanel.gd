extends Panel
class_name BaseWindowPanel
## Base Window Behaviors

const MOUSE_BUTTONS_THAT_BRING_WINDOW_TO_TOP: Array = [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]

signal close_window_requested(self_window_name) ## Connected to WindowManager, which closes this window
signal close_window_requesed_no_arg() ## As above but passes no argument

@export var left_pixel_gap_default: int = 8
@export var right_pixel_gap_default: int = 8
@export var top_pixel_gap_default: int = 8
@export var bottom_pixel_gap_default: int = 8
@export var window_spawn_location: Vector2i = Vector2i(200,200)

var _child: Container
var _window_name: StringName # Internal name
var _titlebar: TitleBar

func _gui_input(event: InputEvent) -> void:
	_bring_to_top_if_click(event)

func bring_window_to_top():
	VisConfig.UI_manager.window_manager.bring_window_to_top(self)

## Tells the window manager to close this window
func close_window():
	close_window_requested.emit(_window_name)
	close_window_requesed_no_arg.emit()

## Primarily used by Window Manager to save position (plus other details
func export_window_details() -> Dictionary:
	return {
		"position": position,
	}

## First time window is spawned, put some default data in [WindowManager]
func export_default_window_details() -> Dictionary:
	return {
		"position": window_spawn_location,
	}

## Primarily used by Window Manager to load position (plus other details)
func import_window_details(previous_data: Dictionary) -> void:
	position = previous_data["position"]

func shrink_window() -> void:
	_child.size = Vector2i(0,0)

## Call to initialize window
func _setup_base_window(window_name: StringName) -> void:
	_window_name = window_name
	#NOTE: Make SURE that the window child is the first child, and the [TitleBar] is the second!
	_child = get_child(0)
	_titlebar = get_child(1)
	_child.resized.connect(_update_sizes_given_child_size_update)
	_titlebar.button_ref.pressed.connect(close_window)
	_titlebar.setup_from_window(self)
	_titlebar.clicked.connect(bring_window_to_top)
	
	VisConfig.UI_manager.UI_scale_changed.connect(_update_sizes_given_child_size_update.unbind(1)) # ignore the argument
	_update_sizes_given_child_size_update()

func _bring_to_top_if_click(event: InputEvent):
	if !(event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if !(mouse_event.button_index in MOUSE_BUTTONS_THAT_BRING_WINDOW_TO_TOP):
		return
	if !mouse_event.pressed:
		return
	bring_window_to_top()

func _update_sizes_given_child_size_update() -> void:
	#NOTE: This isn't very efficient, this call can get called numerous times when scaling.
	#TODO: Look for a way to cut down the number of calls this goes through to resize
	# Apply scale
	var left_pixel_gap: int = left_pixel_gap_default * int(VisConfig.UI_manager.UI_scale)
	var right_pixel_gap: int = right_pixel_gap_default * int(VisConfig.UI_manager.UI_scale)
	var top_pixel_gap: int = top_pixel_gap_default * int(VisConfig.UI_manager.UI_scale)
	var bottom_pixel_gap: int = bottom_pixel_gap_default * int(VisConfig.UI_manager.UI_scale)
	
	var new_size: Vector2 = _child.size + Vector2(left_pixel_gap + right_pixel_gap, top_pixel_gap + bottom_pixel_gap)
	_child.position =  Vector2i(left_pixel_gap, top_pixel_gap)
	custom_minimum_size = new_size
	var size_x: int = new_size.x
	var min_titlebar_width: int = _titlebar.get_minimum_width(VisConfig.UI_manager.UI_scale)
	if size_x > min_titlebar_width:
		# Titlebar too narrow
		_titlebar.size.x = size_x
	else:
		# Window too narrow
		_titlebar.size.x = min_titlebar_width
		size_x =  min_titlebar_width 
		_child.size.x = _titlebar.size.x - left_pixel_gap - right_pixel_gap
	size = Vector2(size_x,0)
	
