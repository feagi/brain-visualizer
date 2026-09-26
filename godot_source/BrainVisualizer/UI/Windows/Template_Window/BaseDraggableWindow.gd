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
## True after [method apply_condensed_chrome]. Title and close button stay hidden.
var _condensed_chrome: bool = false
var _condensed_dragging: bool = false
var _condensed_drag_offset: Vector2 = Vector2.ZERO
var _condensed_dismissed: bool = false

func _ready() -> void:
	# Set References
	_titlebar = $TitleBar
	_window_panel = $WindowPanel
	_window_margin = $WindowPanel/WindowMargin
	_window_internals = $WindowPanel/WindowMargin/WindowInternals
	_theme_custom_scaler.setup(self, theme_scalar_nodes_to_not_include_or_search, BV.UI.loaded_theme)
	BV.UI.theme_changed.connect(_theme_updated)
	_theme_updated(BV.UI.loaded_theme)
	# Allow global ESC handling
	set_process_unhandled_key_input(true)
	set_process_input(true)
	

func _gui_input(event: InputEvent) -> void:
	_bring_to_top_if_click(event)

func _unhandled_key_input(event: InputEvent) -> void:
	# Global ESC-to-close for all windows (works even when a child has focus)
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_ESCAPE:
			close_window()

func _input(event: InputEvent) -> void:
	# Fallback: capture ESC even if a Control consumes GUI input
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_ESCAPE:
			accept_event()
			close_window()
			return
	_handle_condensed_chrome_input(event)

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

func _theme_updated(new_theme: Theme) -> void:
	theme = new_theme
	call_deferred("_delay_shrink_window")

func _delay_shrink_window():
	size = Vector2i(0,0)


## Condensed chrome: no title, no close button, a border drag handle, and dismiss on an outside click.
## Call after [method _ready] (the title bar and panel nodes must exist). Other windows keep the title bar
## until they call this. Buttons inside the panel keep their own clicks. A click on the scene, outside
## this window and outside [method _condensed_keep_open_rects], closes the window and is not consumed,
## so the scene still receives that click.
func apply_condensed_chrome() -> void:
	if _titlebar == null or _window_panel == null or _window_margin == null:
		push_error("BaseDraggableWindow: apply_condensed_chrome requires the window to be ready")
		return
	_condensed_chrome = true
	_titlebar.visible = false
	_titlebar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prepare_condensed_drag_surface(_window_panel)
	_prepare_condensed_drag_surface(_window_margin)


## True when a press at [param click_position] is outside the window and outside any extra rect that must stay open.
static func condensed_click_should_dismiss(window_rect: Rect2, click_position: Vector2, keep_open_rects: Array[Rect2] = []) -> bool:
	if window_rect.has_point(click_position):
		return false
	for keep_rect in keep_open_rects:
		if keep_rect.has_point(click_position):
			return false
	return true


## Keeps a grab-sized piece of the window on screen while dragging the border.
static func clamp_condensed_window_position(proposed: Vector2, window_size: Vector2, screen_size: Vector2, edge_buffer: float) -> Vector2:
	var buffer := maxf(edge_buffer, 0.0)
	var min_x := buffer - window_size.x
	var max_x := screen_size.x - buffer
	var min_y := buffer - window_size.y
	var max_y := screen_size.y - buffer
	if min_x > max_x:
		min_x = 0.0
		max_x = maxf(screen_size.x - window_size.x, 0.0)
	if min_y > max_y:
		min_y = 0.0
		max_y = maxf(screen_size.y - window_size.y, 0.0)
	return Vector2(clampf(proposed.x, min_x, max_x), clampf(proposed.y, min_y, max_y))


## Extra viewport rects that an outside click must not dismiss. Popups owned by the window override this.
func _condensed_keep_open_rects() -> Array[Rect2]:
	return []


## Subclasses override when outside-click dismiss should not use [method close_window] unchanged.
func _close_for_condensed_dismiss() -> void:
	close_window()


func _prepare_condensed_drag_surface(control: Control) -> void:
	if control == null:
		return
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	control.mouse_default_cursor_shape = Control.CURSOR_MOVE
	if not control.gui_input.is_connected(_on_condensed_border_gui_input):
		control.gui_input.connect(_on_condensed_border_gui_input)


func _on_condensed_border_gui_input(event: InputEvent) -> void:
	if not _condensed_chrome or not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse_event.pressed:
		_condensed_dragging = true
		_condensed_drag_offset = Vector2(position) - get_viewport().get_mouse_position()
		bring_window_to_top()
		return
	_finish_condensed_drag()


func _handle_condensed_chrome_input(event: InputEvent) -> void:
	if not _condensed_chrome:
		return
	if _condensed_dragging and event is InputEventMouseMotion:
		var proposed := _condensed_drag_offset + get_viewport().get_mouse_position()
		position = clamp_condensed_window_position(proposed, size, _condensed_screen_size(), _condensed_edge_buffer())
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if _condensed_dragging:
		if not mouse_event.pressed:
			_finish_condensed_drag()
		return
	if not mouse_event.pressed:
		return
	if not (mouse_event.button_index in MOUSE_BUTTONS_THAT_BRING_WINDOW_TO_TOP):
		return
	if not condensed_click_should_dismiss(get_global_rect(), get_global_mouse_position(), _condensed_keep_open_rects()):
		return
	_dismiss_condensed_window()


func _finish_condensed_drag() -> void:
	if not _condensed_dragging:
		return
	_condensed_dragging = false
	position = clamp_condensed_window_position(position, size, _condensed_screen_size(), _condensed_edge_buffer())


func _dismiss_condensed_window() -> void:
	if _condensed_dismissed:
		return
	_condensed_dismissed = true
	_close_for_condensed_dismiss()


func _condensed_edge_buffer() -> float:
	if _titlebar == null:
		return 0.0
	return float(_titlebar.screen_edge_buffer)


func _condensed_screen_size() -> Vector2:
	return BV.UI.screen_size
