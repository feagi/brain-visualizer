extends VBoxContainer
class_name BaseDraggableWindow
## Base Window Behaviors
#NOTE: Best to use this using the ExampleWindow.tscn to get the expected structure and settings

const MOUSE_BUTTONS_THAT_BRING_WINDOW_TO_TOP: Array = [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]

signal close_window_requested(self_window_name) ## Connected to WindowManager, which closes this window
signal close_window_requesed_no_arg() ## As above but passes no argument

@export var left_pixel_gap_default: int = 8
@export var right_pixel_gap_default: int = 8
@export var top_pixel_gap_default: int = 8
@export var bottom_pixel_gap_default: int = 8
@export var window_spawn_location: Vector2i = Vector2i(200,200)

var _window_name: StringName # Internal name
var _titlebar: TitleBar
var _window_panel: PanelContainer
var _window_margin: MarginContainer
var _window_internals: VBoxContainer # the internals the most every window will be caring about

func _ready() -> void:
	# Set References
	_titlebar = $TitleBar
	_window_panel = $WindowPanel
	_window_margin = $WindowPanel/WindowMargin
	_window_internals = $WindowPanel/WindowMargin/WindowInternals
	
	_set_margins(top_pixel_gap_default, 
		right_pixel_gap_default, 
		bottom_pixel_gap_default, 
		left_pixel_gap_default)

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
	size = Vector2i(0,0)

## Call to initialize window
func _setup_base_window(window_name: StringName) -> void:
	_window_name = window_name
	_titlebar.button_ref.pressed.connect(close_window)
	_titlebar.setup_from_window(self)
	_titlebar.clicked.connect(bring_window_to_top)

func _bring_to_top_if_click(event: InputEvent):
	if !(event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if !(mouse_event.button_index in MOUSE_BUTTONS_THAT_BRING_WINDOW_TO_TOP):
		return
	if !mouse_event.pressed:
		return
	bring_window_to_top()


func _set_margins(top: int, right: int, bottom: int, left: int) -> void:
	_window_margin.add_theme_constant_override("margin_top", top)
	_window_margin.add_theme_constant_override("margin_left", right)
	_window_margin.add_theme_constant_override("margin_bottom", bottom)
	_window_margin.add_theme_constant_override("margin_right", left)
	
