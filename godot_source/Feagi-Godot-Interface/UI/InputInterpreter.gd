extends Node
class_name InputInterpreter
## Translates input events from mouse / touch into easier use signal outputs

signal zoom_changed(new_zoom: float)
signal pan_changed(new_pan: Vector2)  # Random Crits not included

var zoom_limit_upper: float = 10
var zoom_limit_lower: float = 0.1
var pan_speed: float = 1


var touching_points: Dictionary = {} # what fingers are touching (in case of mouse, theres only 1)
var start_distance: float
var zoom_start: float

var zoom_current: float:
	get: return _zoom_current
	set(v):
		_zoom_current = v
		zoom_changed.emit(v)
var pan_current: Vector2:
	get: return _pan_current
	set(v):
		_pan_current = v
		pan_changed.emit(v)

var _touching_points: Dictionary = {}
var _zoom_current: float = 1
var _pan_current: Vector2 = Vector2(0.0,0.0)


func _input(event):

	match event:
		# Query if its a touch event first
		InputEventScreenTouch:
			_handle_press_touch(event)
		InputEventScreenDrag:
			pass
		
		# Query if its a mouse event
		InputEventMouseButton:
			pass
		InputEventMouseMotion:
			pass

## for responding to touch events (tap and double tap)
func _handle_press_touch(event: InputEventScreenTouch) -> void:

	if event.double_tap:
		pass
	if event.pressed:
		_touching_points[event.index] = event.position  # Where index is the finger touching the screen (first finger is 0, next is 1...)
	else:
		# we let go
		_touching_points.erase(event.index)
	
	match _touching_points.size():
		1:
			# only 1 finger on screen
			pass
		2:
			# 2 fingers
			var touching_points_positions: Array[Vector2] = _touching_points.values()
			start_distance = touching_points_positions[1].distance_to(touching_points_positions[0])
			zoom_start = zoom_current
		
	if touching_points.size() < 2:
		start_distance = 0.0

## for responding to touch drag events
func _handle_drag_touch(event: InputEventScreenDrag) -> void:
	_touching_points[event.index] = event.position

	match _touching_points.size():
		1:
			# only 1 finger on screen
			pan_current -= event.relative * pan_speed
		2:
			# 2 fingers
			var touching_points_positions: Array[Vector2] = _touching_points.values()
			var current_distance: float = touching_points_positions[1].distance_to(touching_points_positions[0])
			var zoom_factor = start_distance / current_distance
			zoom_current = FEAGIUtils.bounds(zoom_factor, zoom_limit_lower, zoom_limit_upper)



