extends PanelContainer
class_name TitleBar

signal drag_started(current_window_position: Vector2, current_mouse_position: Vector2)
signal drag_finished(current_window_position: Vector2, current_mouse_position: Vector2)
signal clicked()
signal released()
signal close_pressed()

@export var mouse_normal_click_button: MouseButton = MOUSE_BUTTON_LEFT

## if disabled, hide the close button entirely:
@export var show_close_button: bool = true

## How far out in any direction the title bar can go before it snaps back
@export var screen_edge_buffer: int = 16

## if disabled, will disable (fade) the close button to prevent it from being clicked
@export var enable_close_button: bool = true:
	get: return $HBoxContainer/Close_Button.visible
	set(v):
		$HBoxContainer/Close_Button.visible = v

@export var title: String:
	get: return $HBoxContainer/Title_Text.text
	set(v): 
		$HBoxContainer/Title_Text.text = v

var button_ref: Button:
	get: return $HBoxContainer/Close_Button

var _is_dragging: bool = false
var _prev_window_minus_mouse_position: Vector2
var _window_parent: BaseDraggableWindow
var _viewport: Viewport
var _title: Label
var _tex_button: TextureButton
var _left_gap: Control

func _ready() -> void:
	_viewport = get_viewport()
	_title = $HBoxContainer/Title_Text
	_tex_button = $HBoxContainer/Close_Button
	_left_gap = $HBoxContainer/gap
	_on_theme_change()
	BV.UI.theme_changed.connect(_on_theme_change)
	

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		# user touched screen
		pass
	if event is InputEventScreenDrag:
		# user dragged on touchscreen
		pass
	if event is InputEventMouseButton:
		_process_mouse_click_event(event as InputEventMouseButton)
	if event is InputEventMouseMotion:
		if !_is_dragging:
			return # If we arent dragging (as decided by _process_mouse_click_event), then dont process this is a drag
		_process_mouse_drag_event(event as InputEventMouseMotion)



## The parent window object calls this to finish setting up this child. Technically not best practice
func setup_from_window(window: BaseDraggableWindow) -> void:
	_window_parent = window

## Check if TitleBar is within bounds
func is_titlebar_within_view_bounds() -> bool:
	var self_rect: Rect2 = get_global_rect().grow(-screen_edge_buffer).abs() # Calculate bounds
	var screen_rect: Rect2 = Rect2(Vector2(0,0), BV.UI.screen_size) # Get Screen Rect
	return screen_rect.encloses(self_rect)

func get_minimum_width() -> int:
	var minimum_width: int = 2 * int(_tex_button.size_x ) # size of the close button and left gap
	minimum_width += _title.get_theme_font(&"font").get_string_size(_title.text, HORIZONTAL_ALIGNMENT_CENTER, -1, _title.get_theme_font_size(&"font_size")).x
	return minimum_width

func _on_theme_change(_new_theme: Theme = null) -> void:
	var min_size: Vector2i = BV.UI.get_minimum_size_from_loaded_theme("TextureButton_WindowClose")
	_tex_button.custom_minimum_size = min_size
	_left_gap.custom_minimum_size = min_size


## Processes Mouse clicks on the title bar
func _process_mouse_click_event(mouse_event: InputEventMouseButton) -> void:
		if mouse_event.button_index != mouse_normal_click_button:
			return
		if mouse_event.pressed:
			_is_dragging = true
			clicked.emit()
			drag_started.emit(_window_parent.position, _viewport.get_mouse_position())
			_prev_window_minus_mouse_position = _window_parent.position - _viewport.get_mouse_position()
		else:
			_is_dragging = false
			released.emit()
			if !is_titlebar_within_view_bounds():
				_window_parent.position = _window_parent.window_spawn_location
			drag_finished.emit(_window_parent.position, _viewport.get_mouse_position())
			

## Processes Mouse Dragging (mouse movement while _is_dragging is true)
func _process_mouse_drag_event(_mouse_event: InputEventMouseMotion) -> void:
	_window_parent.position = _prev_window_minus_mouse_position + _viewport.get_mouse_position()

func _close_window_from_close_button() -> void:
	close_pressed.emit()
	_window_parent.close_window()

func set_in_bounds_with_window_size_change() -> void:
	if !is_titlebar_within_view_bounds():
		_window_parent.position = _window_parent.window_spawn_location

