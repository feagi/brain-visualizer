extends Panel
class_name BaseWindowPanel
## Base Window Behaviors

const MOUSE_BUTTONS_THAT_BRING_WINDOW_TO_TOP: Array = [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]

signal close_window_requested(self_window_name) ## Connected to WindowManager, which closes this window


@export var left_pixel_gap_default: int = 8
@export var right_pixel_gap_default: int = 8
@export var top_pixel_gap_default: int = 8
@export var bottom_pixel_gap_default: int = 8
@export var window_spawn_location: Vector2i = Vector2i(100,100)
@export var should_scale_with_UI: bool = true
@export var additionally_bind_to_UI_scale_change: bool = false


var _child: Container
var _window_name: StringName # Internal name
var _titlebar: TitleBar

## Call to initialize window
func setup_window(window_name: StringName) -> void:
	_window_name = window_name
	#NOTE: Make SURE that the window child is the first child, and the [TitleBar] is the second!
	_child = get_child(0)
	_titlebar = get_child(1)
	_child.resized.connect(_update_sizes_given_child_size_update)
	_titlebar.button_ref.pressed.connect(close_window)
	_titlebar.setup_from_window(self)
	
	if additionally_bind_to_UI_scale_change:
		VisConfig.UI_manager.UI_scale_changed.connect(_update_sizes_given_child_size_update.unbind(0)) # ignore the argument
	_update_sizes_given_child_size_update()

func bring_window_to_top():
	VisConfig.UI_manager.window_manager.bring_window_to_top(self)

## Tells the window manager to close this window
func close_window():
	close_window_requested.emit(_window_name)

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
	# Apply scale
	var left_pixel_gap: int = left_pixel_gap_default
	var right_pixel_gap: int = right_pixel_gap_default
	var top_pixel_gap: int = top_pixel_gap_default
	var bottom_pixel_gap: int = bottom_pixel_gap_default
	if should_scale_with_UI:
		left_pixel_gap *= VisConfig.UI_manager.UI_scale
		right_pixel_gap *= VisConfig.UI_manager.UI_scale
		top_pixel_gap *= VisConfig.UI_manager.UI_scale
		bottom_pixel_gap *= VisConfig.UI_manager.UI_scale
	
	var new_size: Vector2 = _child.size + Vector2(left_pixel_gap + right_pixel_gap, top_pixel_gap + bottom_pixel_gap)
	_titlebar.size.x = new_size.x
	_child.position =  Vector2i(left_pixel_gap, top_pixel_gap)
	custom_minimum_size = new_size
	size = Vector2(0,0)
	
