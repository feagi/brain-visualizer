extends GraphElement
class_name InterCorticalConnection
## Shows number of mappings, and controls the line creationa and destruction

const LINE_COLOR_PSPP_PLASTIC: Color = Color.DARK_GREEN
const LINE_COLOR_PSPP_INPLASTIC: Color = Color.DARK_GREEN
const LINE_COLOR_PSPN_PLASTIC: Color = Color.RED
const LINE_COLOR_PSPN_INPLASTIC: Color = Color.RED
const LINE_COLOR_TRANSPARENT: Color = Color(0,0,0,0)
const LINE_INPUT_X_OFFSET: int = 200
const LINE_OUTPUT_X_OFFSET: int = -200
const NUM_POINTS_PER_CURVE: int = 20
const NUM_DOTTED_LINE_DIVISIONS: int = 50
const COLOR_CONSTANT_OFFSET_HIGHLIGHT: float = 0.4
const COLOR_SLOPE_OFFSET_HIGHLIGHT: float = 0.4

enum HIGHLIGHT{
	NO_HIGHLIGHT,
	LEFT_HIGHLIGHT,
	RIGHT_HIGHLIGHT,
	BOTH_HIGHLIGHT
}

var left_side_highlighted: bool:
	get: return _left_side_highlighted
	set(v):
		_left_side_highlighted = v
		if v:
			_set_highlighting(HIGHLIGHT.BOTH_HIGHLIGHT if _right_side_highlighted else HIGHLIGHT.LEFT_HIGHLIGHT) 
		else:
			_set_highlighting(HIGHLIGHT.RIGHT_HIGHLIGHT if _right_side_highlighted else HIGHLIGHT.NO_HIGHLIGHT) 

var right_side_highlighted: bool:
	get: return _right_side_highlighted
	set(v):
		_right_side_highlighted = v
		if v:
			_set_highlighting(HIGHLIGHT.BOTH_HIGHLIGHT if _left_side_highlighted else HIGHLIGHT.RIGHT_HIGHLIGHT) 
		else:
			_set_highlighting(HIGHLIGHT.LEFT_HIGHLIGHT if _left_side_highlighted else HIGHLIGHT.NO_HIGHLIGHT) 


var _node_graph: CorticalNodeGraph
var _source_terminal: InterCorticalNodeTerminal
var _destination_terminal: InterCorticalNodeTerminal
var _source_node: CorticalNode
var _destination_node: CorticalNode
var _mapping_properties: MappingProperties
var _left_side_highlighted: bool
var _right_side_highlighted: bool

var _button: Button
var _line: Line2D

func _ready():
	_button = $Button
	_line = $Line2D
	var mat: Material = _line.material #TODO Change away from duplicate materials ASAP!
	var unique_line_material: Material = mat.duplicate()
	_line.material = unique_line_material
	for i in NUM_POINTS_PER_CURVE: # TODO optimize! This should be static in TSCN
		_line.add_point(Vector2(0,0))

func setup(source_terminal: InterCorticalNodeTerminal, destination_terminal: InterCorticalNodeTerminal, mapping_properties: MappingProperties):
	
	# Initial Setup
	_source_terminal = source_terminal
	_destination_terminal = destination_terminal
	_source_node = _source_terminal.cortical_node
	_destination_node = _destination_terminal.cortical_node
	_mapping_properties = mapping_properties
	_node_graph = get_parent()

	# Button Positioning
	#_source_terminal.get_port_reference().draw.connect(_update_position)
	#_destination_terminal.get_port_reference().draw.connect(_update_position)
	_source_terminal.get_port_reference().terminal_moved.connect(_update_position)
	_destination_terminal.get_port_reference().terminal_moved.connect(_update_position)
	_mapping_properties.mappings_changed.connect(_feagi_updated_mapping)
	
	# Line Highlighting
	_source_terminal.line_highlighting_set.connect(set_left_side_highlighting)
	_destination_terminal.line_highlighting_set.connect(set_right_side_highlighting)
	#TODO set initial state
	
	# update Line Properties
	_feagi_updated_mapping(_mapping_properties)
	
	# Labeling
	name = "count_" + _source_node.cortical_area_ID + "->" + _destination_node.cortical_area_ID
	_update_position()
	
## To delete the connection UI side
func destroy_ui_connection() -> void:
	_source_terminal.queue_free()
	_destination_terminal.queue_free()
	queue_free()

## Set the highlighting on the left side of the line
func set_left_side_highlighting(is_left_highlighted: bool) -> void:
	_left_side_highlighted = is_left_highlighted
	if is_left_highlighted:
		_set_highlighting(HIGHLIGHT.BOTH_HIGHLIGHT if _right_side_highlighted else HIGHLIGHT.LEFT_HIGHLIGHT) 
	else:
		_set_highlighting(HIGHLIGHT.RIGHT_HIGHLIGHT if _right_side_highlighted else HIGHLIGHT.NO_HIGHLIGHT) 

## Set the highlighting on the right side of the line
func set_right_side_highlighting(is_right_highlighted: bool) -> void:
	_right_side_highlighted = is_right_highlighted
	if is_right_highlighted:
		_set_highlighting(HIGHLIGHT.BOTH_HIGHLIGHT if _left_side_highlighted else HIGHLIGHT.RIGHT_HIGHLIGHT) 
	else:
		_set_highlighting(HIGHLIGHT.LEFT_HIGHLIGHT if _left_side_highlighted else HIGHLIGHT.NO_HIGHLIGHT) 


## Sets highlighting of the line
func _set_highlighting(setting: HIGHLIGHT) -> void:
	match(setting):
		HIGHLIGHT.NO_HIGHLIGHT:
			_set_line_highlighting_params(0.0, 0.0)
		HIGHLIGHT.LEFT_HIGHLIGHT:
			_set_line_highlighting_params(COLOR_CONSTANT_OFFSET_HIGHLIGHT, -COLOR_SLOPE_OFFSET_HIGHLIGHT)
		HIGHLIGHT.RIGHT_HIGHLIGHT:
			_set_line_highlighting_params(0.0, COLOR_SLOPE_OFFSET_HIGHLIGHT)
		HIGHLIGHT.BOTH_HIGHLIGHT:
			_set_line_highlighting_params(COLOR_CONSTANT_OFFSET_HIGHLIGHT, 0.0)
	
func _spawn_edit_mapping_window() -> void:
	VisConfig.UI_manager.window_manager.spawn_edit_mappings(_source_node.cortical_area_ref, _destination_node.cortical_area_ref)

## Update position of the box and line if either [CorticalNode] moves
func _update_position(_irrelevant = null) -> void:
	var left: Vector2 = _source_terminal.get_output_location()
	var right: Vector2 = _destination_terminal.get_input_location()
	position_offset = (left + right - (size / 2.0)) / 2.0
	_update_line_positions(left, right)

func _update_line_positions(start_point: Vector2, end_point: Vector2) -> void:
	_line.points = _generate_cubic_bezier_points(start_point - position_offset, end_point - position_offset)


## Update the mapping count
func _feagi_updated_mapping(_updated_mapping_data: MappingProperties) -> void:
	if _updated_mapping_data.number_mappings == 0:
		destroy_ui_connection()
		return
	_update_mapping_counter(_mapping_properties.number_mappings)
	_update_line_look(_updated_mapping_data)

func _update_mapping_counter(number_of_mappings: int):
	_button.text = " " + str(number_of_mappings) + " "

func _update_line_look(_updated_mapping_data: MappingProperties) -> void:
		if _updated_mapping_data.is_any_PSP_multiplier_negative():
			if _updated_mapping_data.is_any_mapping_plastic():
				_set_line_dotted_params(LINE_COLOR_PSPN_PLASTIC, LINE_COLOR_TRANSPARENT, NUM_DOTTED_LINE_DIVISIONS)
			else:
				_set_line_dotted_params(LINE_COLOR_PSPN_INPLASTIC, LINE_COLOR_PSPN_INPLASTIC, NUM_DOTTED_LINE_DIVISIONS)
		else:
			if _updated_mapping_data.is_any_mapping_plastic():
				_set_line_dotted_params(LINE_COLOR_PSPP_PLASTIC, LINE_COLOR_TRANSPARENT, NUM_DOTTED_LINE_DIVISIONS)
			else:
				_set_line_dotted_params(LINE_COLOR_PSPP_INPLASTIC, LINE_COLOR_PSPP_INPLASTIC, NUM_DOTTED_LINE_DIVISIONS)
			

func _set_line_dotted_params(color_a: Color, color_b: Color, number_of_divisions: float) -> void:
	_line.material.set_shader_parameter(&"colorA", Vector4(color_a.r, color_a.g, color_a.b, color_a.a))
	_line.material.set_shader_parameter(&"colorB", Vector4(color_b.r, color_b.g, color_b.b, color_b.a))
	_line.material.set_shader_parameter(&"numDivisions", number_of_divisions)

func _set_line_highlighting_params(constant: float, slope: float) -> void:
	_line.material.set_shader_parameter(&"linConstant", constant)
	_line.material.set_shader_parameter(&"linSlope", slope)

## Cubic bezier curve approximation, where t is between 0 and 1
func _cubic_bezier(t: float, p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2) -> Vector2:
	return (pow(1.0 - t, 3.0) * p1) + (3.0 * t * pow(1.0 - t, 2.0) * p2) + (3.0 * pow(t, 2.0) * (1.0 - t) * p3) + (pow(t,3.0) * p4)
	
func _generate_cubic_bezier_points(start_point: Vector2, end_point: Vector2) -> PackedVector2Array:
	var start_offset: Vector2 = start_point + Vector2(LINE_INPUT_X_OFFSET, 0)
	var output_offset: Vector2 = end_point + Vector2(LINE_OUTPUT_X_OFFSET, 0)
	var x_space = 1.0 / float(NUM_POINTS_PER_CURVE)
	var output: PackedVector2Array = []
	output.resize(NUM_POINTS_PER_CURVE)
	for i:int in NUM_POINTS_PER_CURVE:
		output[i] = _cubic_bezier((float(i) * x_space), start_point, start_offset, output_offset, end_point)
	return output
