extends PanelContainer
class_name TitleBar

signal drag_started(current_window_position: Vector2, current_mouse_position: Vector2)
signal drag_finished(current_window_position: Vector2, current_mouse_position: Vector2)
signal clicked()
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
var _window_parent: BaseWindowPanel
var _viewport: Viewport

func _ready() -> void:
	_viewport = get_viewport()
	VisConfig.UI_manager.screen_size_changed.connect(set_in_bounds_with_window_size_change.unbind(1))

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

func _UI_scale_changed(_multiplier: float) -> void:
	var _label: Label = $HBoxContainer/Title_Text
	#TODO

## The parent window object calls this to finish setting up this child. Technically not best practice
func setup_from_window(window: BaseWindowPanel) -> void:
	_window_parent = window

## Check if TitleBar is within bounds
func is_titlebar_within_view_bounds() -> bool:
	var self_rect: Rect2 = get_global_rect().grow(-screen_edge_buffer).abs() # Calculate bounds
	var screen_rect: Rect2 = Rect2(Vector2(0,0), VisConfig.UI_manager.screen_size) # Get Screen Rect
	return screen_rect.encloses(self_rect)

## Processes Mouse clicks on the title bar
func _process_mouse_click_event(mouse_event: InputEventMouseButton) -> void:
		if mouse_event.button_index != mouse_normal_click_button:
			return
		if mouse_event.pressed:
			_is_dragging = true
			clicked.emit()
			VisConfig.UI_manager.is_user_dragging_a_window = true
			drag_started.emit(_window_parent.position, _viewport.get_mouse_position())
			_prev_window_minus_mouse_position = _window_parent.position - _viewport.get_mouse_position()
		else:
			_is_dragging = false
			VisConfig.UI_manager.is_user_dragging_a_window = false
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
	
