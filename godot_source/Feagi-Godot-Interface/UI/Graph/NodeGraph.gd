extends Control
class_name NodeGraph

var pan_pixel: Vector2:
	get: return _panning_pixel
	set(v):
		_apply_pan_from_absolute_change(v)

var pan_normal: Vector2:
	get: return _panning_pixel / _graph_window_size

var zoom: float:
	get: return _zoom
	set(v):
		_zoom = v
		_apply_zoom(v)

var _input: InputInterpreter
var _background: Control
var _background_shader: Material
var _background_center: NodeGraphCenter

var _panning_pixel: Vector2 = Vector2(0.0, 0.0) # store as float for easier math
var _zoom: float = 1.0
var _graph_window_size: Vector2

func _ready():
	_graph_window_size = VisConfig.UI_manager.screen_size
	_background = $Background
	_background_center = $Background/Center
	_background_center.setup(VisConfig.UI_manager.screen_size)
	_background_shader = _background.material
	_input = $InputInterpreter
	_input.pan_changed.connect(_apply_pan)
	_input.zoom_changed.connect(_apply_zoom)
	VisConfig.UI_manager.screen_size_changed.connect(_apply_resize)

func _apply_pan(_change_in_pan_normal: Vector2, change_in_pan_pixel: Vector2) -> void:
	_update_pan_from_delta(change_in_pan_pixel)
	_background_shader.set_shader_parameter("offset", -pan_normal)
	_background_center.apply_pan(change_in_pan_pixel)

func _apply_zoom(new_zoom: float) -> void:
	# TODO renable zoom at some point
	#_zoom = new_zoom
	#_background_shader.set_shader_parameter("zoom", new_zoom)
	pass

func _apply_resize(new_size: Vector2) -> void:
	_background.size = new_size

func _update_pan_from_delta(change_in_pan_pixel: Vector2) -> void:
	_panning_pixel = _panning_pixel + change_in_pan_pixel

func _apply_pan_from_absolute_change(new_pan_pixel: Vector2) -> void:
	var delta_pixel: Vector2 = new_pan_pixel - _panning_pixel
	_apply_pan(delta_pixel, delta_pixel * _graph_window_size)
