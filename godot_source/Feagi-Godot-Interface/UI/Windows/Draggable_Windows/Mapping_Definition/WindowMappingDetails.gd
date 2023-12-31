extends VBoxContainer
class_name WindowMappingDetails

# needs to make use of signals of when cortical areas are added or removed (same with morpholopgies)

var _mappings_scroll: BaseScroll

func _ready() -> void:
	_mappings_scroll = $Mappings

func display_mapping_properties(mappings_copy: MappingProperties) -> void:
	clear_mapping_properties()
	visible = true
	for mapping in mappings_copy.mappings:
		_mappings_scroll.spawn_list_item(
			{
				"mapping": mapping,
			})

func clear_mapping_properties():
	_mappings_scroll.remove_all_children()
	visible = false

## Creates an Array of [MappingProperty] given the items within the scroll section
func generate_mapping_properties(source_area: BaseCorticalArea, destination_area: BaseCorticalArea) -> Array[MappingProperty]:
	var mappings: Array[MappingProperty]= []
	var scroll_box_box: VBoxContainer = _mappings_scroll.get_node("VBoxContainer")
	var children_of_scroll_box: Array = scroll_box_box.get_children()
	for mapping_prefab in children_of_scroll_box:
		mappings.append(mapping_prefab.generate_mapping_property())
	return mappings

# connected in WindowMappingDetails.tscn
func _add_mapping_pressed() -> void:
	if len(FeagiCache.morphology_cache.available_morphologies.keys()) == 0:
		print("Unable to spawn a connection when no morphologies exist!")
		## TODO a user error may go well here
		return
	var new_mapping: MappingProperty = MappingProperty.create_default_mapping(FeagiCache.morphology_cache.available_morphologies[FeagiCache.morphology_cache.available_morphologies.keys()[0]])
	_mappings_scroll.spawn_list_item(
		{
			"mapping": new_mapping,
		}
	)
