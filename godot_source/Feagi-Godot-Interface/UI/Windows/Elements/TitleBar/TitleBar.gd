extends Panel
class_name TitleBar

signal close_pressed()
signal drag_started(current_position: Vector2)
signal dragged(current_position: Vector2, mouse_delta_offset: Vector2) # TODO
signal drag_finished(current_position: Vector2)

@export var mouse_normal_click_button: MouseButton = MOUSE_BUTTON_LEFT

@export var title_gap: int:
	get: return $Title_Text.gap
	set(v): $Title_Text.gap = v

@export var title: String:
	get: return $Title_Text.text
	set(v): $Title_Text.text = v

## if True, will attempt to automatically set up dragging behavior on parent window
@export var automatic_setup_dragging: bool = true

## if True, will attempt to automatically set up closing behavior on parent window
@export var automatic_setup_closing: bool = true

## if True, will attempt to set the correct width of the parent window, and maintain it
@export var automatic_maintain_width: bool = true

## if set to a non blank string, will attempt to automatically set up closing behavior on parent window for the window manager
@export var automatic_setup_window_closing_for_window_manager_name: StringName

var is_dragging: bool:
	get: return _is_dragging
	set(v):
		if v == _is_dragging: 
			return # ignore setting to the same value
			
		_is_dragging = v
		if v:
			drag_started.emit(_parent.position)
			VisConfig.UI_manager.is_user_dragging_a_window = true
		else:
			drag_finished.emit(_parent.position)
			VisConfig.UI_manager.is_user_dragging_a_window = false


var _is_mousing_over: bool = false
var _is_dragging: bool = false
var _parent: Control
var _initial_position: Vector2i

func _ready():
	$Close_Button.pressed.connect(_proxy_close_button)
	$Close_Button.resized.connect(_height_resized)
	$Title_Text.resized.connect(_recalculate_title_bar_min_width)
	mouse_entered.connect(_mouse_enter)
	mouse_exited .connect(_mouse_leave)

	_recalculate_title_bar_min_width()
	
	if automatic_setup_dragging or automatic_setup_closing or automatic_maintain_width:
		_parent = get_parent()

	if automatic_setup_dragging:
		dragged.connect(_auto_drag_move_parent)
	
	if automatic_setup_closing:
		close_pressed.connect(_auto_close_parent)
	
	if automatic_maintain_width:
		_parent.resized.connect(_auto_maintain_width)
		_auto_maintain_width()
	
	if automatic_setup_window_closing_for_window_manager_name != &"":
		close_pressed.connect(_window_manager_close)
	
	_initial_position = position


func _input(event):

	if event is InputEventScreenTouch:
		# user touched screen
		pass
	if event is InputEventScreenDrag:
		# user dragged on touchscreen
		pass
	if event is InputEventMouseButton:
		# user clicked mouse (or clicked / scrolled mouse wheel)
		_mouse_click(event)
	if event is InputEventMouseMotion:
		_dragging(event)


		

func _proxy_close_button():
	close_pressed.emit()

func _height_resized() -> void:
	custom_minimum_size.y = VisConfig._minimum_button_size_pixel.y
	# Because button is a square

func _window_manager_close() -> void:
	var draggable_window: DraggableWindow = _parent as DraggableWindow
	draggable_window.close_window(automatic_setup_window_closing_for_window_manager_name)

## What is the minimum width the title bar needs to be to fit everything?
func _recalculate_title_bar_min_width() -> void:
	custom_minimum_size.x = int($Close_Button.custom_minimum_size.y) + int($Title_Text.size.x) + title_gap # Yes, using the close button Y is intentional to avoid repositioning loops

func _mouse_enter() -> void:
	_is_mousing_over = true

func _mouse_leave() -> void:
	_is_mousing_over = false


func _mouse_click(click: InputEventMouseButton) -> void:
	if click.button_index != mouse_normal_click_button:
		return
	
	# if click while mousing over, start dragging
	if click.pressed:
		if !_is_mousing_over:
			return
		is_dragging = true
	else:
		is_dragging = false

func _dragging(drag: InputEventMouseMotion) -> void:
	if !is_dragging:
		return # if we arent dragging, don't do anything!
	
	dragged.emit(_parent.position, drag.relative)

func _end_drag() -> void:
	drag_finished.emit(_parent.position)

## IF auto-setup-dragging is enabled, responsible for moving parent around
func _auto_drag_move_parent(_current_position: Vector2, delta_offset: Vector2) -> void:
	_parent.position = _parent.position + delta_offset

## IF auto-setup-closing is enabled, responsible for moving parent around
func _auto_close_parent() -> void:
	_parent.visible = false # TODO
#	_parent.queue_free() # Temporary. This is useful for duplicated/JSON. We aren't using it

func _auto_maintain_width() -> void:
	call_deferred("_defered_size_adjust")

func _defered_size_adjust():
	size = Vector2(0,0)
	custom_minimum_size.x = _parent.size.x
