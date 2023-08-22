extends Control
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
var _background: Control
var _background_shader: Material
var _logo: CBLogo

var _panning: Vector2 = Vector2(0.0, 0.0)
var _zoom: float = 1.0

func _ready():
	_background = $Background
	_background_shader = _background.material
	_input = $InputInterpreter
	_logo = $Logo
	_input.pan_changed.connect(_apply_pan)
	_input.zoom_changed.connect(_apply_zoom)
	VisConfig.screen_size_changed.connect(_apply_resize)

func _apply_pan(new_pan: Vector2) -> void:
	_panning = new_pan
	_background_shader.set_shader_parameter("offset", new_pan)
	#_logo.set_background_position(new_pan)

func _apply_zoom(new_zoom: float) -> void:
	# TODO renable zoom at some point
	#_zoom = new_zoom
	#_background_shader.set_shader_parameter("zoom", new_zoom)
	pass

func _apply_resize(new_size: Vector2) -> void:
	_background.size = new_size
