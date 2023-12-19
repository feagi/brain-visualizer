extends VBoxContainer
class_name GeneralMappingEditor
## Shows mapping configurator for user for general use cases

const SPECIAL_CASES_NEEDING_SIMPLE_MODE: Array[MappingHints.MAPPING_SPECIAL_CASES] = [
	MappingHints.MAPPING_SPECIAL_CASES.ANY_TO_MEMORY,
	MappingHints.MAPPING_SPECIAL_CASES.MEMORY_TO_ANY,
	MappingHints.MAPPING_SPECIAL_CASES.MEMORY_TO_MEMORY,
]

var _mappings_scroll: BaseScroll
var _mapping_hints: MappingHints
var _add_mapping: Button

func _ready() -> void:
	_mappings_scroll = $Mappings
	_add_mapping = $labels_box/add_button

func update_displayed_mapping_properties(mappings_copy: MappingProperties, mapping_hints: MappingHints) -> void:
	_mapping_hints = mapping_hints
	_mappings_scroll.remove_all_children()
	var is_simple_mode: bool = mapping_hints.exist_any_matching_special_cases(SPECIAL_CASES_NEEDING_SIMPLE_MODE)
	_toggle_show_full_editing(!is_simple_mode)
	
	if is_simple_mode:
		_spawn_simple_mapping(mappings_copy, mapping_hints)
	else:
		_spawn_full_mappings(mappings_copy, mapping_hints)
	
	_add_mapping.disabled = _mappings_scroll.get_number_of_children() >= mapping_hints.max_number_mappings

## Creates an Array of [MappingProperty] given the items within the scroll section
func generate_mapping_propertys() -> Array[MappingProperty]:
	var mappings: Array[MappingProperty]= []
	var scroll_box_box: VBoxContainer = _mappings_scroll.get_node("VBoxContainer")
	var children_of_scroll_box: Array = scroll_box_box.get_children()
	for mapping_prefab in children_of_scroll_box:
		mappings.append(mapping_prefab.generate_mapping_property())
	return mappings

func _toggle_show_full_editing(full_editing: bool) -> void:
	$labels_box/g1.visible = full_editing
	$labels_box/Label2.visible = full_editing
	$labels_box/g2.visible = full_editing
	$labels_box/Label3.visible = full_editing
	$labels_box/g3.visible = full_editing
	$labels_box/Label4.visible = full_editing
	$labels_box/g4.visible = full_editing
	$labels_box/Label5.visible = full_editing
	$labels_box/g5.visible = full_editing
	$labels_box/Label6.visible = full_editing
	$labels_box/g6.visible = full_editing
	$labels_box/Label7.visible = full_editing

func _spawn_full_mappings(mappings: MappingProperties, mapping_hints: MappingHints) -> void:
	for mapping in mappings.mappings:
		var spawn_parameter: Dictionary = {"mapping": mapping}
		_mappings_scroll.spawn_list_item(spawn_parameter)
	_add_mapping.disabled = _mappings_scroll.get_number_of_children() >= mapping_hints.max_number_mappings

func _spawn_simple_mapping(mappings: MappingProperties, mapping_hints: MappingHints) -> void:
	for mapping in mappings.mappings:
		var spawn_parameter: Dictionary = {
			"mapping": mapping,
			"simple": true}
		if mapping_hints.is_morphologies_restricted:
			spawn_parameter["allowed_morphologies"] = mapping_hints.restricted_morphologies
		_mappings_scroll.spawn_list_item(spawn_parameter)
	_add_mapping.disabled = _mappings_scroll.get_number_of_children() >= mapping_hints.max_number_mappings

# connected in WindowMappingDetails.tscn
func _add_mapping_pressed() -> void:
	if len(FeagiCache.morphology_cache.available_morphologies.keys()) == 0:
		print("Unable to spawn a connection when no morphologies exist!")
		## TODO a user error may go well here
		return
	var new_mapping: MappingProperty = MappingProperty.create_placeholder_mapping()
	var spawn_parameter: Dictionary = {"mapping": new_mapping}
	_mappings_scroll.spawn_list_item(spawn_parameter)
