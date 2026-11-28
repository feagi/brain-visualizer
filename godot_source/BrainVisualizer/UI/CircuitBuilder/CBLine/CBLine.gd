extends GraphElement
class_name CBLine

const LINE_INPUT_X_OFFSET: int = 200 # Shapes the line curvature
const LINE_OUTPUT_X_OFFSET: int = -200 # Shapes the line curvature
const NUM_POINTS_PER_CURVE: int = 20
var _last_zoom: float = -1.0
# Must stay well above the line width (Line2D default 10 px) to read as a wave.
const WAVE_AMPLITUDE_PX: float = 8.0
const WAVE_LENGTH_PX: float = 40.0
const COLOR_CONSTANT_OFFSET_HIGHLIGHT: float = 0.4
const COLOR_SLOPE_OFFSET_HIGHLIGHT: float = 0.4

var _line: Line2D
var _is_wavy: bool = false
var _left_local: Vector2 = Vector2.ZERO
var _right_local: Vector2 = Vector2.ZERO
var _has_endpoints: bool = false


func line_setup() -> void:
	_line = $Line2D
	# Duplicate the material to make it independent
	var mat: Material = _line.material
	var unique_line_material: Material = mat.duplicate()
	_line.material = unique_line_material
	set_line_dashing(false)
	var cycle: float = MappingLineStyle.DASH_CYCLE_S if MappingLineStyle.dash_motion_enabled() else 0.0
	_line.material.set_shader_parameter(&"dashCycleSeconds", cycle)
	var pair: float = MappingLineStyle.DASH_LENGTH_PX + MappingLineStyle.DASH_GAP_PX
	_line.material.set_shader_parameter(&"dashDuty", MappingLineStyle.DASH_LENGTH_PX / pair)
	
	for i in NUM_POINTS_PER_CURVE: # TODO optimize! This should be static in TSCN
		_line.add_point(Vector2(0,0))

func set_line_base_color(line_color: Color) -> void:
	_line.material.set_shader_parameter(&"baseColor", Vector4(line_color.r, line_color.g, line_color.b, line_color.a))

func set_line_dashing(is_dashed: bool) -> void:
	_line.material.set_shader_parameter(&"isDashed", is_dashed)
	set_process(is_dashed)
	if is_dashed:
		_update_dash_scale()

## Sets the endpoints of the line
func set_line_endpoints(left: Vector2, right: Vector2) -> void:
	position_offset = (left + right - (size / 2.0)) / 2.0
	_left_local = left - position_offset
	_right_local = right - position_offset
	_has_endpoints = true
	_rebuild_points()

## Makes the line a smooth static sine wave (associative memory).
func set_line_wavy(is_wavy: bool) -> void:
	if _is_wavy == is_wavy:
		return
	_is_wavy = is_wavy
	if _has_endpoints:
		_rebuild_points()

func _rebuild_points() -> void:
	var points: PackedVector2Array = _generate_cubic_bezier_points(_left_local, _right_local, NUM_POINTS_PER_CURVE)
	if _is_wavy:
		points = MappingLineStyle.wave_points(points, WAVE_AMPLITUDE_PX, WAVE_LENGTH_PX)
	_line.points = points
	_update_dash_scale()


## How many dash-and-gap pairs fit along the line at the current zoom, so each dash stays
## [constant MappingLineStyle.DASH_LENGTH_PX] on screen.
func _update_dash_scale() -> void:
	if _line == null or _line.material == null:
		return
	var pair: float = MappingLineStyle.DASH_LENGTH_PX + MappingLineStyle.DASH_GAP_PX
	var periods: float = maxf(_screen_length() / pair, 1.0)
	_line.material.set_shader_parameter(&"numDivisions", periods)


func _screen_length() -> float:
	var length: float = 0.0
	for i in range(1, _line.points.size()):
		length += _line.points[i - 1].distance_to(_line.points[i])
	return length * _graph_zoom()


func _graph_zoom() -> float:
	var node: Node = self
	while node != null:
		var graph: GraphEdit = node as GraphEdit
		if graph != null:
			return graph.zoom
		node = node.get_parent()
	return 1.0


func _process(_delta: float) -> void:
	var zoom: float = _graph_zoom()
	if is_equal_approx(zoom, _last_zoom):
		return
	_last_zoom = zoom
	_update_dash_scale()

## Sets highlighting of the line
func set_highlighting(start_highlighted: bool, end_higlighted: bool) -> void:
	if start_highlighted:
		if end_higlighted:
			# both
			_line.material.set_shader_parameter(&"linConstant", COLOR_CONSTANT_OFFSET_HIGHLIGHT) 
			_line.material.set_shader_parameter(&"linSlope", 0.0)
		else:
			# left
			_line.material.set_shader_parameter(&"linConstant", COLOR_CONSTANT_OFFSET_HIGHLIGHT)
			_line.material.set_shader_parameter(&"linSlope", -COLOR_SLOPE_OFFSET_HIGHLIGHT)
	else:
		if end_higlighted:
			# right
			_line.material.set_shader_parameter(&"linConstant", 0.0)
			_line.material.set_shader_parameter(&"linSlope", COLOR_SLOPE_OFFSET_HIGHLIGHT)
		else:
			# neither
			_line.material.set_shader_parameter(&"linConstant", 0.0)
			_line.material.set_shader_parameter(&"linSlope", 0.0)
	
	
func _generate_cubic_bezier_points(start_point: Vector2, end_point: Vector2, point_count: int = NUM_POINTS_PER_CURVE) -> PackedVector2Array:
	var start_offset: Vector2 = start_point + Vector2(LINE_INPUT_X_OFFSET, 0)
	var output_offset: Vector2 = end_point + Vector2(LINE_OUTPUT_X_OFFSET, 0)
	var x_space: float = 1.0 / float(maxi(point_count - 1, 1)) # last point lands on t = 1
	var output: PackedVector2Array = []
	output.resize(point_count)
	for i:int in point_count:
		output[i] = _cubic_bezier((float(i) * x_space), start_point, start_offset, output_offset, end_point)
	return output

## Cubic bezier curve approximation, where t is between 0 and 1
func _cubic_bezier(t: float, p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2) -> Vector2:
	return (pow(1.0 - t, 3.0) * p1) + (3.0 * t * pow(1.0 - t, 2.0) * p2) + (3.0 * pow(t, 2.0) * (1.0 - t) * p3) + (pow(t,3.0) * p4)
