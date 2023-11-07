extends Panel
class_name TitleBar

const MINIMUM_TITLEBAR_HEIGHT: int = 40
const DEFAULT_RESPAWN_POSITION: Vector2 = Vector2(100,100)

signal drag_started(current_window_position: Vector2, current_mouse_position: Vector2)
signal dragged(window_position: Vector2, mouse_position: Vector2,  mouse_delta_offset: Vector2)
signal drag_finished(current_window_position: Vector2, current_mouse_position: Vector2)
signal close_pressed()

@export var mouse_normal_click_button: MouseButton = MOUSE_BUTTON_LEFT

## Whether title bar movement calculations should use positional changes over frames rather delta directly
@export var use_position_instead_of_delta_movement: bool = true

## How far out remaining the titlebar can be before automatic repositioning occurs
@export var reposition_buffer: int = 45

@export var title_gap: int:
	get: return $Title_Text.gap
	set(v): $Title_Text.gap = v

@export var title: String:
	get: return $Title_Text.text
	set(v): $Title_Text.text = v

## if True, will attempt to automatically set up dragging behavior on parent window
@export var automatic_setup_dragging: bool = true

## if True, will attempt to automatically set up closing behavior (by hiding the window)
@export var automatic_setup_hiding_closing: bool = true

## if True, will attempt to set the correct width of the parent window, and maintain it
@export var automatic_maintain_width: bool = true

## if set to a non blank string, will attempt to automatically set up closing behavior on parent window for the window manager. CANNOT be mixed with hiding closing
@export var automatic_setup_window_closing_for_window_manager_name: StringName

var is_dragging: bool:
	get: return _is_dragging
	set(v):
		if v == _is_dragging: 
			return # ignore setting to the same value
			
		_is_dragging = v
		if v:
			# Start Drag
			drag_started.emit(_parent.position, _viewport.get_mouse_position())
			VisConfig.UI_manager.is_user_dragging_a_window = true
			if _parent is DraggableWindow:
				_parent.move_to_front()
		else:
			# end Drag
			var screen_rect: Rect2 = Rect2(Vector2(0,0), VisConfig.UI_manager.screen_size)
			var self_rect: Rect2 = get_global_rect().grow(-reposition_buffer).abs()
			if !screen_rect.intersects(self_rect):
				_parent.position = DEFAULT_RESPAWN_POSITION
				print("UI: Windows: Snapping back out of bounds window!")
			drag_finished.emit(_parent.position, _viewport.get_mouse_position())
			VisConfig.UI_manager.is_user_dragging_a_window = false


var _is_mousing_over: bool = false
var _is_dragging: bool = false
var _parent: Control
var _sibling: Control
var _initial_position: Vector2i
var _prev_window_minus_mouse_position: Vector2
var _viewport: Viewport

func _ready():
	_viewport = get_viewport()
	
	$Close_Button.resized.connect(_height_resized)
	$Title_Text.resized.connect(_recalculate_title_bar_min_width)
	mouse_entered.connect(_mouse_enter)
	mouse_exited .connect(_mouse_leave)
	
	custom_minimum_size = Vector2(0, MINIMUM_TITLEBAR_HEIGHT)
	
	if automatic_setup_hiding_closing and automatic_setup_window_closing_for_window_manager_name != &"":
		push_warning("TitleBar cannot have multiple close methods defined at once. Please check this windows titleBar settings")
		automatic_setup_window_closing_for_window_manager_name = "" # To Prevent weird issues, disable this method

	_recalculate_title_bar_min_width()
	
	if automatic_setup_dragging or automatic_setup_hiding_closing or automatic_maintain_width:
		_parent = get_parent()
		_sibling = _parent.get_child(0)
		
	if automatic_setup_dragging:
		if use_position_instead_of_delta_movement:
			drag_started.connect(_auto_drag_move_parent_position_start)
			dragged.connect(_auto_drag_move_parent_position)
		else:
			dragged.connect(_auto_drag_move_parent_delta)
	
	if automatic_setup_hiding_closing:
		$Close_Button.pressed.connect(_auto_hide_parent)
	
	if automatic_maintain_width:
		_sibling.resized.connect(_auto_maintain_width)
		_auto_maintain_width()
	
	if automatic_setup_window_closing_for_window_manager_name != &"":
		$Close_Button.pressed.connect(_window_manager_close)
	
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

func _height_resized() -> void:
	custom_minimum_size.y = VisConfig._minimum_button_size_pixel.y
	# Because button is a square

## USe the draggable windows close function to call for a close
func _window_manager_close() -> void:
	var draggable_parent: DraggableWindow = _parent as DraggableWindow
	draggable_parent.close_window(automatic_setup_window_closing_for_window_manager_name)

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
	dragged.emit(_parent.position, drag.position, drag.relative)

func _close_proxy():
	close_pressed.emit()

## IF auto-setup-dragging is enabled (with delta), responsible for moving parent around
func _auto_drag_move_parent_delta(_window_position: Vector2, _mouse_position: Vector2, delta_offset: Vector2) -> void:
	_parent.position = _parent.position + delta_offset

## IF auto-setup-dragging is enabled (without delta), responsible for starting to moving parent around
func _auto_drag_move_parent_position_start(current_window_position: Vector2, current_mouse_position: Vector2) -> void:
	_prev_window_minus_mouse_position = current_window_position - current_mouse_position

## IF auto-setup-dragging is enabled (without delta), responsible for moving parent around
func _auto_drag_move_parent_position(_window_position: Vector2, mouse_position: Vector2,  _delta_offset: Vector2) -> void:
	_parent.position = _prev_window_minus_mouse_position + mouse_position


## IF automatic_setup_hiding_closing is enabled, responsible for hiding parent
func _auto_hide_parent() -> void:
	_parent.visible = false

func _auto_maintain_width() -> void:
	#set_deferred("size", Vector2(0,0))
	var width: float = _sibling.size.x
	if _parent is DraggableWindow:
		var _drag_parent: DraggableWindow = _parent as DraggableWindow
		width += _drag_parent.left_pixel_gap + _drag_parent.right_pixel_gap
	
	custom_minimum_size = Vector2(width, MINIMUM_TITLEBAR_HEIGHT)

