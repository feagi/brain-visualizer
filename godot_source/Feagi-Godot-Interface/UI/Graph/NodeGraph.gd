extends Node2D
class_name NodeGraph

var panning: Vector2:
	get: return _panning
	set(v):
		_panning = v
		_apply_pan(v)

var zoom: float:
	get: return _zoom
	set(v):
		_zoom = v
		_apply_zoom(v)

var _input: InputInterpreter
var _background: Material

var _panning: Vector2 = Vector2(0.0, 0.0)
var _zoom: float = 1.0

func _ready():
	_background = ($Background).material
	_input = $InputInterpreter
	_input.pan_changed.connect(_apply_pan)
	_input.zoom_changed.connect(_apply_zoom)


func _apply_pan(new_pan: Vector2) -> void:
	_panning = new_pan
	_background.set_shader_parameter("offset", new_pan)

func _apply_zoom(new_zoom: float) -> void:
	_zoom = new_zoom
	_background.set_shader_parameter("zoom", new_zoom)