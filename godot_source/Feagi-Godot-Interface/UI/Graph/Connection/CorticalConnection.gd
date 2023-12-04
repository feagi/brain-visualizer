extends GraphElement
class_name CorticalConnection
## Shows number of mappings, and controls the line creationa and destruction

const LINE_COLOR_UNKNOWN_MAPPING: Color = Color.GHOST_WHITE
const LINE_COLOR_PSPP_PLASTIC: Color = Color.LIME_GREEN
const LINE_COLOR_PSPP_INPLASTIC: Color = Color.DARK_GREEN
const LINE_COLOR_PSPN_PLASTIC: Color = Color.RED
const LINE_COLOR_PSPN_INPLASTIC: Color = Color.DARK_RED

var _node_graph: CorticalNodeGraph
var _source_node: CorticalNode
var _destination_node: CorticalNode
var _source_node_terminal: CorticalNodeTerminal
var _destination_node_terminal: CorticalNodeTerminal
var _mapping_properties: MappingProperties

var _label: TextButton_Element
var _line: Line2D


func setup(source_node: CorticalNode, destination_node: CorticalNode, mapping_properties: MappingProperties, node_graph: CorticalNodeGraph):
	# Initial Setup
	_source_node = source_node
	_destination_node = destination_node
	_mapping_properties = mapping_properties
	_node_graph = node_graph
	_node_graph.add_child(self)
	
	# Create Terminals
	if !_mapping_properties.is_recursive():
		# non-recursive mapping
		_source_node_terminal = _source_node.spawn_efferent_terminal(destination_node.cortical_area_ref)
		_destination_node_terminal = _destination_node.spawn_afferent_terminal(source_node.cortical_area_ref)
	else:
		# recursive
		_source_node_terminal = _source_node.spawn_recurrsive_terminal()
		_destination_node_terminal = _source_node_terminal
	
	# Button Positioning
	_source_node.position_offset_changed.connect(update_position)
	if !_mapping_properties.is_recursive():
		_destination_node.position_offset_changed.connect(update_position)
	_mapping_properties.mappings_changed.connect(_feagi_updated_mapping)
	
	
	#	Line
	_line = $Line2D
	if _mapping_properties.is_recursive():
		_line.visible = false
	else:
		update_position()
	
	# Labeling
	_label = get_child(0)
	name = "count_" + _source_node.cortical_area_ID + "->" + _destination_node.cortical_area_ID

	# update Line Properties
	_feagi_updated_mapping(_mapping_properties)


# TODO replace with something better
func update_position() -> void:
	var left: Vector2 = _source_node_terminal.get_input_location()
	var right: Vector2 = _destination_node_terminal.get_output_location()
	_line.points[0] = left - position_offset
	_line.points[1] = right - position_offset
	position_offset = (left + right - (size / 2.0)) / 2.0

func destroy_self() -> void:
	queue_free()

func _button_pressed() -> void:
	VisConfig.UI_manager.window_manager.spawn_edit_mappings(_source_node.cortical_area_ref, _destination_node.cortical_area_ref)

## Update the mapping count
func _feagi_updated_mapping(_updated_mapping_data: MappingProperties) -> void:
	_update_mapping_counter(_mapping_properties.number_mappings)
	_source_node_terminal.set_port_color(_determine_line_color())
	_destination_node_terminal.set_port_color(_determine_line_color())

func _update_mapping_counter(number_of_mappings: int):
	_label.text = " " + str(number_of_mappings) + " "

func _determine_line_color() -> Color:
	if _mapping_properties.is_any_PSP_multiplier_negative():
		# negative PSP
		return LINE_COLOR_PSPN_INPLASTIC
	else:
		return LINE_COLOR_PSPP_INPLASTIC
