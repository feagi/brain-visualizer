extends VBoxContainer
class_name GenericMappingDetailSettings

const PREFAB_ROW: PackedScene = preload("res://BrainVisualizer/UI/Windows/MappingEditor/MappingEditorRowGeneric.tscn")

signal user_changed_something()

var _restrictions: MappingRestrictionCorticalMorphology
var _defaults: MappingRestrictionDefault

var _add_button: TextureButton
var _scroll: ScrollSectionGeneric

func _ready() -> void:
	_scroll = $ScrollSectionGeneric
	_add_button = $labels_box/add_button

func clear() -> void:
	_scroll.remove_all_items()

func load_mappings(mappings: Array[SingleMappingDefinition], restrictions: MappingRestrictionCorticalMorphology, defaults: MappingRestrictionDefault) -> void:
	_restrictions = restrictions
	_defaults = defaults
	for mapping in mappings:
		import_single_mapping(mapping)
	if restrictions.has_max_number_mappings():
		_add_button.disabled = restrictions.max_number_mappings >= len(mappings)

func export_mappings() -> Array[SingleMappingDefinition]:
	var mappings: Array[SingleMappingDefinition] = []
	var list_items: Array[ScrollSectionGenericItem] = _scroll.get_all_spawned_children_of_container()
	for item in list_items:
		var mapping_row: MappingEditorRowGeneric = item.get_control()
		mappings.append(mapping_row.export_mapping())
	return mappings

func import_single_mapping(mapping: SingleMappingDefinition) -> void:
	var row: MappingEditorRowGeneric = PREFAB_ROW.instantiate()
	var item: ScrollSectionGenericItem = _scroll.add_generic_item(row, null, "") #NOTE: Doing this first so _ready has a chance to run
	row.load_settings(_restrictions, _defaults)
	row.load_mapping(mapping)
	item.about_to_be_deleted.connect(_on_row_deletion)

func _add_mapping_row() -> void:
	var row: MappingEditorRowGeneric = PREFAB_ROW.instantiate()
	var item: ScrollSectionGenericItem = _scroll.add_generic_item(row, null, "")
	item.about_to_be_deleted.connect(_on_row_deletion)
	row.load_settings(_restrictions, _defaults)
	if _restrictions.has_max_number_mappings():
		_add_button.disabled = _restrictions.max_number_mappings >= _scroll.get_item_count()

func _on_row_deletion(item: ScrollSectionGenericItem) -> void:
	if _restrictions.has_max_number_mappings():
		_add_button.disabled = _restrictions.max_number_mappings < _scroll.get_item_count() - 1 # Subtract 1 since it is about to be 1 less
