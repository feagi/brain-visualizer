extends VBoxContainer
class_name GeneralMappingEditor
## Shows mapping configurator for user for general use cases

const SPECIAL_CASES_NEEDING_SIMPLE_MODE: Array[MappingHints.MAPPING_SPECIAL_CASES] = [
	MappingHints.MAPPING_SPECIAL_CASES.ANY_TO_MEMORY,
	MappingHints.MAPPING_SPECIAL_CASES.MEMORY_TO_MEMORY,
]

@export var elements_to_scale: Array[Control]

var _mappings_scroll: BaseScroll
var _mapping_hints: MappingHints
var _add_mapping: TextureButton
var _is_simple_mode: bool
var _custom_minimum_size_scalar: ScalingCustomMinimumSize

func _ready() -> void:
	_mappings_scroll = $Mappings
	_add_mapping = $labels_box/add_button
	_custom_minimum_size_scalar = ScalingCustomMinimumSize.new(elements_to_scale)
	BV.UI.theme_changed.connect(_on_theme_change)
	_on_theme_change(BV.UI.loaded_theme)

func update_displayed_mapping_properties(mappings_copy: MappingProperties, mapping_hints: MappingHints) -> void:
	_mapping_hints = mapping_hints
	_mappings_scroll.remove_all_children()
	_is_simple_mode = mapping_hints.exist_any_matching_special_cases(SPECIAL_CASES_NEEDING_SIMPLE_MODE)
	_toggle_show_full_editing(!_is_simple_mode)
	
	if _is_simple_mode:
		_spawn_simple_mappings(mappings_copy, mapping_hints)
	else:
		_spawn_full_mappings(mappings_copy, mapping_hints)
	
	_toggle_enable_mapping_button_automatically()
	size = Vector2(0,0)

## Creates an Array of [MappingProperty] given the items within the scroll section
func generate_mapping_propertys() -> Array[MappingProperty]:
	var mappings: Array[MappingProperty]= []
	var children_of_scroll_box: Array = _mappings_scroll.get_children_as_list()
	for mapping_prefab in children_of_scroll_box:
		mappings.append(mapping_prefab.generate_mapping_property())
	return mappings

## Adds a mapping to the mappingProperties if applicable (valid and starting empty)
func add_default_mapping_if_applicable(override_child_check: bool = false) -> void:
	if (_mappings_scroll.get_number_of_children() != 0) and (!override_child_check):
		# No adding a default mapping if there already is a mapping
		return
	
	if _mapping_hints == null:
		push_warning("Unable to spawn default mapping without mapping_hints defined! Ignoring user request...")
		return
	
	if _mapping_hints.default_morphology == null:
		push_error("Unable to spawn default mapping without default connectivity rule defined")
		return
	var mapping: MappingProperty = MappingProperty.create_default_mapping(_mapping_hints.default_morphology)
	
	if _is_simple_mode:
		_spawn_simple_mapping(mapping, _mapping_hints)
	else:
		_spawn_full_mapping(mapping, _mapping_hints)
	_toggle_enable_mapping_button_automatically()

func _toggle_show_full_editing(full_editing: bool) -> void:
	$labels_box/Label2.visible = full_editing
	$labels_box/Label3.visible = full_editing
	$labels_box/Label4.visible = full_editing
	$labels_box/Label5.visible = full_editing
	$labels_box/Label6.visible = full_editing
	$labels_box/Label7.visible = full_editing

func _spawn_full_mappings(mappings: MappingProperties, mapping_hints: MappingHints) -> void:
	for mapping: MappingProperty in mappings.mappings:
		_spawn_full_mapping(mapping, mapping_hints)
	_toggle_enable_mapping_button_automatically()

func _spawn_full_mapping(mapping: MappingProperty, mapping_hints: MappingHints) -> void:
	var spawn_parameter: Dictionary = {"mapping": mapping}
	if mapping_hints.is_morphologies_restricted:
		spawn_parameter["allowed_morphologies"] = mapping_hints.restricted_morphologies
	var mapping_ui_prefab: Prefab_Mapping = _mappings_scroll.spawn_list_item(spawn_parameter)
	mapping_ui_prefab.mapping_to_be_deleted.connect(_toggle_enable_mapping_button_automatically)

func _spawn_simple_mappings(mappings: MappingProperties, mapping_hints: MappingHints) -> void:
	for mapping: MappingProperty in mappings.mappings:
		_spawn_simple_mapping(mapping, mapping_hints)
	_toggle_enable_mapping_button_automatically()

func _spawn_simple_mapping(mapping: MappingProperty, mapping_hints: MappingHints) -> void:
	var spawn_parameter: Dictionary = {
		"mapping": mapping,
		"simple": true}
	if mapping_hints.is_morphologies_restricted:
		spawn_parameter["allowed_morphologies"] = mapping_hints.restricted_morphologies
	var mapping_ui_prefab: Prefab_Mapping = _mappings_scroll.spawn_list_item(spawn_parameter)
	mapping_ui_prefab.mapping_to_be_deleted.connect(_toggle_enable_mapping_button_automatically)

func _toggle_enable_mapping_button_automatically() -> void:
	if _mapping_hints.is_number_mappings_restricted:
		_add_mapping.disabled = _mappings_scroll.get_number_of_children() >= _mapping_hints.max_number_mappings
	else:
		_add_mapping.disabled = false


# connected in WindowMappingDetails.tscn
func _add_mapping_pressed() -> void:
	if len(FeagiCore.feagi_local_cache.morphologies.available_morphologies.keys()) == 0:
		print("Unable to spawn a connection when no morphologies exist!")
		## TODO a user error may go well here
		return
	add_default_mapping_if_applicable(true)

func _on_theme_change(new_theme: Theme):
	$labels_box/add_button.custom_minimum_size = BV.UI.get_minimum_size_from_loaded_theme_variant_given_control($labels_box/add_button, "TextureButton")
	_custom_minimum_size_scalar.theme_updated(new_theme)
