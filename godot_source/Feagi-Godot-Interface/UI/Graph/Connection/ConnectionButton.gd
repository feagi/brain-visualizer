extends GraphNode
class_name ConnectionButton
## Shows number of mappings

var _source_node: CorticalNode
var _destination_node: CorticalNode
var _label: TextButton_Element

func setup(source_node: CorticalNode, destination_node: CorticalNode, number_mappings: int):
	_source_node = source_node
	_destination_node = destination_node
	_source_node.position_offset_changed.connect(update_position)
	if _source_node.cortical_area_ID != _destination_node.cortical_area_ID:
		_destination_node.position_offset_changed.connect(update_position)
	_source_node.cortical_area_ref.efferent_area_count_updated.connect(_feagi_updated_a_mapping_count)
	_label = get_child(0)
	update_position()
	update_mapping_counter(number_mappings)


func update_mapping_counter(number_of_mappings: int):
	_label.text = str(number_of_mappings)

# TODO replace with something better
func update_position() -> void:
	var left: Vector2 = _source_node.get_center_position_offset()
	var right: Vector2 = _destination_node.get_center_position_offset()
	position_offset = (left + right - (size / 2.0)) / 2.0

func destroy_self() -> void:
	queue_free()

func _button_pressed() -> void:
	VisConfig.UI_manager.window_manager.spawn_edit_mappings(_source_node.cortical_area_ref, _destination_node.cortical_area_ref)

## Confirm efferent area is the one this conneciton represents, and update the mapping count
func _feagi_updated_a_mapping_count(efferent_area: CorticalArea, mapping_count: int) -> void:
	if efferent_area.cortical_ID == _destination_node.cortical_area_ID:
		update_mapping_counter(mapping_count)


