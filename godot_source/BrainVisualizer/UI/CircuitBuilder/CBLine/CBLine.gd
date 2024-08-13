extends GraphElement
class_name CBLine

const LINE_INPUT_X_OFFSET: int = 200 # Shapes the line curvature
const LINE_OUTPUT_X_OFFSET: int = -200 # Shapes the line curvature
const NUM_POINTS_PER_CURVE: int = 20
const NUM_DOTTED_LINE_DIVISIONS: int = 50
const COLOR_CONSTANT_OFFSET_HIGHLIGHT: float = 0.4
const COLOR_SLOPE_OFFSET_HIGHLIGHT: float = 0.4

var _line: Line2D


func line_setup() -> void:
	_line = $Line2D
	# Duplicate the material to make it independent
	var mat: Material = _line.material
	var unique_line_material: Material = mat.duplicate()
	_line.material = unique_line_material
	set_line_dashing(false)
	
	for i in NUM_POINTS_PER_CURVE: # TODO optimize! This should be static in TSCN
		_line.add_point(Vector2(0,0))

func set_line_base_color(line_color: Color) -> void:
	_line.material.set_shader_parameter(&"baseColor", Vector4(line_color.r, line_color.g, line_color.b, line_color.a))

func set_line_dashing(is_dashed: bool) -> void:
	_line.material.set_shader_parameter(&"isDashed", is_dashed)

## Sets the endpoints of the line
func set_line_endpoints(left: Vector2, right: Vector2) -> void:
	position_offset = (left + right - (size / 2.0)) / 2.0
	_line.points = _generate_cubic_bezier_points(left - position_offset, right - position_offset)

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
	
	
func _generate_cubic_bezier_points(start_point: Vector2, end_point: Vector2) -> PackedVector2Array:
	var start_offset: Vector2 = start_point + Vector2(LINE_INPUT_X_OFFSET, 0)
	var output_offset: Vector2 = end_point + Vector2(LINE_OUTPUT_X_OFFSET, 0)
	var x_space = 1.0 / float(NUM_POINTS_PER_CURVE)
	var output: PackedVector2Array = []
	output.resize(NUM_POINTS_PER_CURVE)
	for i:int in NUM_POINTS_PER_CURVE:
		output[i] = _cubic_bezier((float(i) * x_space), start_point, start_offset, output_offset, end_point)
	return output

## Cubic bezier curve approximation, where t is between 0 and 1
func _cubic_bezier(t: float, p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2) -> Vector2:
	return (pow(1.0 - t, 3.0) * p1) + (3.0 * t * pow(1.0 - t, 2.0) * p2) + (3.0 * pow(t, 2.0) * (1.0 - t) * p3) + (pow(t,3.0) * p4)
