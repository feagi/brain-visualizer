extends VBoxContainer
class_name BaseDraggableWindow
## Base Window Behaviors
#NOTE: Best to use this using the ExampleWindow.tscn to get the expected structure and settings

const MOUSE_BUTTONS_THAT_BRING_WINDOW_TO_TOP: Array = [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]

signal close_window_requested(self_window_name: StringName) ## Connected to WindowManager, which closes this window
signal close_window_requesed_no_arg() ## As above but passes no argument
signal bring_window_to_top_request(self_window_name: StringName)

@export var window_spawn_location: Vector2i = Vector2i(200,200)
@export var theme_scalar_nodes_to_not_include_or_search: Array[Node] = []

var _window_name: StringName # Internal name
var _titlebar: TitleBar
var _window_panel: PanelContainer
var _window_margin: MarginContainer
var _window_internals: VBoxContainer # the internals the most every window will be caring about
var _theme_custom_scaler: ScaleThemeApplier = ScaleThemeApplier.new()

func _ready() -> void:
	# Set References
	_titlebar = $TitleBar
	_window_panel = $WindowPanel
	_window_margin = $WindowPanel/WindowMargin
	_window_internals = $WindowPanel/WindowMargin/WindowInternals
	_theme_custom_scaler.setup(self, theme_scalar_nodes_to_not_include_or_search, BV.UI.loaded_theme)
	BV.UI.theme_changed.connect(_theme_updated)
	_theme_updated(BV.UI.loaded_theme)
	

func _gui_input(event: InputEvent) -> void:
	_bring_to_top_if_click(event)

func bring_window_to_top():
	bring_window_to_top_request.emit(_window_name)

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
	size = Vector2i(0,0) # look into await() - checkw ith web export

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

func _theme_updated(new_theme: Theme) -> void:
	theme = new_theme
	shrink_window()
