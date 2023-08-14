extends Node
class_name InputInterpreter
## Translates input events from mouse / touch into easier use signal outputs


signal zoom_changed(new_zoom: float)
signal pan_changed(new_pan: Vector2)  # Random Crits not included

@export var zoom_limit_upper: float = 10
@export var zoom_limit_lower: float = 0.1
@export var pan_speed: float = 1.0

@export var mouse_normal_click_button: MouseButton = MOUSE_BUTTON_LEFT
@export var mouse_alt_click_button: MouseButton = MOUSE_BUTTON_RIGHT
@export var mouse_pan_button: MouseButton = MOUSE_BUTTON_MIDDLE
@export var mouse_scroll_speed: float = 1.0

var zoom_current: float:
	get: return _zoom_current
	set(v):
		_zoom_current = FEAGIUtils.bounds(v, zoom_limit_lower, zoom_limit_upper)
		zoom_changed.emit(_zoom_current)
var pan_current: Vector2:
	get: return _pan_current
	set(v):
		_pan_current = v
		pan_changed.emit(v)

var _is_panning: bool = false
#var _touching_points: Dictionary = {}
var _zoom_current: float = 1
var _pan_current: Vector2 = Vector2(0.0,0.0)
var _screen_size: Vector2

func _ready():
	_screen_size = get_viewport().get_visible_rect().size
func _input(event):

	if event is InputEventScreenTouch:
		# user touched screen
		pass
	if event is InputEventScreenDrag:
		# user dragged on touchscreen
		pass
	if event is InputEventMouseButton:
		# user clicked mouse
		_handle_click(event)
	if event is InputEventMouseMotion:
		_handle_mouse_move(event)
		pass


## for responding to touch events (tap and double tap)
func _handle_press_touch(event: InputEventScreenTouch) -> void:

	pass
#	if event.double_tap:
#		pass
#	if event.pressed:
#		_touching_points[event.index] = event.position  # Where index is the finger touching the screen (first finger is 0, next is 1...)
#	else:
#		# we let go
#		_touching_points.erase(event.index)
#	
#	match _touching_points.size():
#		1:
#			# only 1 finger on screen
#			pass
#		2:
#			# 2 fingers
#			var touching_points_positions: Array[Vector2] = _touching_points.values()
#			start_distance = touching_points_positions[1].distance_to(touching_points_positions[0])
#			zoom_start = zoom_current
#		
#	if touching_points.size() < 2:
#		start_distance = 0.0


## Responding to MouseClicks
func _handle_click(event: InputEventMouseButton) -> void:

	if event.double_click:
		pass
	
	match event.button_index:
		mouse_normal_click_button:
			# clicking
			pass

		mouse_alt_click_button:
			# alt (usually right) clicking
			pass

		mouse_pan_button:
			# if pan button is selected
			_is_panning = event.pressed

func _handle_mouse_move(event: InputEventMouseMotion) -> void:
	if _is_panning:
		pan_current = pan_current - ((event.relative * pan_speed) / _screen_size)

	


