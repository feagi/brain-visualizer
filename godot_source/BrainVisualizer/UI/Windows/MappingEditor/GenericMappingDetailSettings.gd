extends VBoxContainer
class_name GenericMappingDetailSettings

const PREFAB_ROW: PackedScene = preload("res://BrainVisualizer/UI/Windows/MappingEditor/MappingEditorRowGeneric.tscn")

signal user_changed_something()

var _default_morphology: BaseMorphology

var _scroll: ScrollSectionGeneric

func _ready() -> void:
	_scroll = $ScrollSectionGeneric

func clear() -> void:
	_scroll.remove_all_items()

func load_mappings(mappings: Array[SingleMappingDefinition], default_morphology: BaseMorphology) -> void:
	_default_morphology = default_morphology
	
	for mapping in mappings:
		var row: MappingEditorRowGeneric = PREFAB_ROW.instantiate()
		_scroll.add_generic_item(row, null, "")
		row.load_mapping(mapping)

func export_mappings() -> Array[SingleMappingDefinition]:
	var mappings: Array[SingleMappingDefinition] = []
	var list_items: Array[ScrollSectionGenericItem] = _scroll.get_all_spawned_children_of_container()
	for item in list_items:
		var mapping_row: MappingEditorRowGeneric = item.get_control()
		mappings.append(mapping_row.export_mapping())
	return mappings

func _add_mapping_row() -> void:
	var row: MappingEditorRowGeneric = PREFAB_ROW.instantiate()
	row.load_default_settings(_default_morphology)
	_scroll.add_generic_item(row, null, "")

