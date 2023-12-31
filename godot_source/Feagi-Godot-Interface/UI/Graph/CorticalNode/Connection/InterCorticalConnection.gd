extends GraphElement
class_name InterCorticalConnection
## Shows number of mappings, and controls the line creationa and destruction

const LINE_COLOR_UNKNOWN_MAPPING: Color = Color.GHOST_WHITE
const LINE_COLOR_PSPP_PLASTIC: Color = Color.LIME_GREEN
const LINE_COLOR_PSPP_INPLASTIC: Color = Color.DARK_GREEN
const LINE_COLOR_PSPN_PLASTIC: Color = Color.RED
const LINE_COLOR_PSPN_INPLASTIC: Color = Color.DARK_RED
const LINE_INPUT_X_OFFSET: int = 200
const LINE_OUTPUT_X_OFFSET: int = -200
const NUM_POINTS_PER_CURVE: int = 20

var _node_graph: CorticalNodeGraph
var _source_terminal: InterCorticalNodeTerminal
var _destination_terminal: InterCorticalNodeTerminal
var _source_node: CorticalNode
var _destination_node: CorticalNode
var _mapping_properties: MappingProperties

var _button: Button
var _line: Line2D

func _ready():
	_button = $Button
	_line = $Line2D
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
	_source_node.connection_positions_changed.connect(_update_position)
	_destination_node.connection_positions_changed.connect(_update_position)
	_source_terminal.get_port_reference().draw.connect(_update_position)
	_destination_terminal.get_port_reference().draw.connect(_update_position)
	_mapping_properties.mappings_changed.connect(_feagi_updated_mapping)
	_update_position()

	# update Line Properties
	_feagi_updated_mapping(_mapping_properties)
	

	# Labeling
	name = "count_" + _source_node.cortical_area_ID + "->" + _destination_node.cortical_area_ID


func destroy_self() -> void:
	_source_terminal.queue_free()
	_destination_terminal.queue_free()
	queue_free()



func _button_pressed() -> void:
	VisConfig.UI_manager.window_manager.spawn_edit_mappings(_source_node.cortical_area_ref, _destination_node.cortical_area_ref)

## Update position of the box and line if either [CorticalNode] moves
func _update_position(_irrelevant = null) -> void:
	var left: Vector2 = _source_terminal.get_output_location()
	var right: Vector2 = _destination_terminal.get_input_location()
	position_offset = (left + right - (size / 2.0)) / 2.0
	_update_line_positions(left, right)

# TODO replace with curves
func _update_line_positions(start_point: Vector2, end_point: Vector2) -> void:
	_line.points = _generate_cubic_bezier_points(start_point - position_offset, end_point - position_offset)

## Update the mapping count
func _feagi_updated_mapping(_updated_mapping_data: MappingProperties) -> void:
	if _updated_mapping_data.number_mappings == 0:
		destroy_self()
		return
	_source_terminal.set_port_elastic(_updated_mapping_data.is_any_mapping_plastic())
	_destination_terminal.set_port_elastic(_updated_mapping_data.is_any_mapping_plastic())
	_update_mapping_counter(_mapping_properties.number_mappings)
	_update_line_look(_updated_mapping_data)

func _update_mapping_counter(number_of_mappings: int):
	_button.text = " " + str(number_of_mappings) + " "

func _spawn_edit_mapping_window() -> void:
	VisConfig.UI_manager.window_manager.spawn_edit_mappings(_source_node.cortical_area_ref, _destination_node.cortical_area_ref)

func _update_line_look(_updated_mapping_data: MappingProperties) -> void:
	_line.default_color = _determine_line_color()

func _determine_line_color() -> Color:
	if _mapping_properties.is_any_PSP_multiplier_negative():
		# negative PSP
		return LINE_COLOR_PSPN_INPLASTIC
	else:
		return LINE_COLOR_PSPP_INPLASTIC

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
