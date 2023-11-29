extends GraphElement
class_name ConnectionButton
## Shows number of mappings

var _node_graph: CorticalNodeGraph
var _source_node: CorticalNode
var _destination_node: CorticalNode
var _source_node_terminal: CorticalNodeTerminal
var _destination_node_terminal: CorticalNodeTerminal
var _mapping_properties: MappingProperties

var _label: TextButton_Element

func setup(source_node: CorticalNode, destination_node: CorticalNode, mapping_properties: MappingProperties, node_graph: CorticalNodeGraph):
	# Initial Setup
	_source_node = source_node
	_destination_node = destination_node
	_mapping_properties = mapping_properties
	_node_graph = node_graph
	_node_graph.add_child(self)
	
	# Create Terminals
	_source_node_terminal = _source_node.spawn_efferent_terminal(destination_node.cortical_area_ref)
	_destination_node_terminal = _destination_node.spawn_afferent_terminal(source_node.cortical_area_ref)
	
	# Positioning
	_source_node.position_offset_changed.connect(update_position)
	if !_mapping_properties.is_recursive():
		_destination_node.position_offset_changed.connect(update_position)
	_mapping_properties.mappings_changed.connect(_feagi_updated_mapping_count)
	update_position()
	
	#Line
	_node_graph.connect_node(_source_node.name, _source_node_terminal.port_index, _destination_node.name, _destination_node_terminal.port_index)

	# Labeling
	_label = get_child(0)
	_feagi_updated_mapping_count(_mapping_properties)
	name = "count_" + _source_node.cortical_area_ID + "->" + _destination_node.cortical_area_ID


# TODO replace with something better
func update_position() -> void:
	var left: Vector2 = _source_node_terminal.get_port_position()
	var right: Vector2 = _destination_node_terminal.get_port_position()
	position_offset = (left + right - (size / 2.0)) / 2.0

func destroy_self() -> void:
	queue_free()

func _button_pressed() -> void:
	VisConfig.UI_manager.window_manager.spawn_edit_mappings(_source_node.cortical_area_ref, _destination_node.cortical_area_ref)

## Update the mapping count
func _feagi_updated_mapping_count(_updated_mapping_data: MappingProperties) -> void:
	_update_mapping_counter(_mapping_properties.number_mappings)

func _update_mapping_counter(number_of_mappings: int):
	_label.text = " " + str(number_of_mappings) + " "
