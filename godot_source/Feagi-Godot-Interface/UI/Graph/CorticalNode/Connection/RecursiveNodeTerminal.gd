extends HBoxContainer
class_name RecursiveNodeTerminal

var _button: Button
var _parent_node: CorticalNode
var _mapping_properties: MappingProperties

func _ready() -> void:
	_button = $Button
	_parent_node = get_parent()

func setup(mapping_properties: MappingProperties) -> void:
	_mapping_properties = mapping_properties
	name = mapping_properties.source_cortical_area.cortical_ID
