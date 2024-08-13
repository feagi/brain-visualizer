extends VBoxContainer
class_name GenericMappingDetailSettingsPartial

const PREFAB_ROW: PackedScene = preload("res://BrainVisualizer/UI/Windows/MappingEditor/MappingEditorRowGenericPartial.tscn")

signal import_mapping_hint(mapping: SingleMappingDefinition)

var _original_mappings: Array[SingleMappingDefinition]
var _scroll: ScrollSectionGeneric


func _ready() -> void:
	_scroll = $ScrollSectionGeneric

func clear() -> void:
	_scroll.remove_all_items()

func load_mappings(mappings: Array[SingleMappingDefinition]) -> void:
	_original_mappings = mappings
	
	for mapping in mappings:
		var row: MappingEditorRowGenericPartial = PREFAB_ROW.instantiate()
		_scroll.add_generic_item(row, null, "") #NOTE: Doing this first so _ready has a chance to run
		row.load_mapping(mapping)
		row.add_pressed.connect(_proxy_mapping_import)

func export_original_mappings() -> Array[SingleMappingDefinition]:
	return _original_mappings

func _proxy_mapping_import(mapping: SingleMappingDefinition) -> void:
	import_mapping_hint.emit(mapping)
