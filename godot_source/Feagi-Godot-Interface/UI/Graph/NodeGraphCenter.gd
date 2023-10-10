extends Node2D
class_name NodeGraphCenter
## Center point that of the NodeGraph that all nodes are parented too. Responsible for panning and zooming animations


var _initial_offset: Vector2


func setup(window_resolution: Vector2) -> void:
	_initial_offset = window_resolution / 2.0
	position = _initial_offset

func apply_pan(change_in_position: Vector2) -> void:
	position = position + change_in_position

