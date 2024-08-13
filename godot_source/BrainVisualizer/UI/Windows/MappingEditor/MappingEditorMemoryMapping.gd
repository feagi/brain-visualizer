extends VBoxContainer
class_name MappingEditorMemoryMapping

signal user_changed_something()

var _button: ToggleButton

func _ready():
	_button = $HBoxContainer/ToggleButton

func load_mappings(mappings: Array[SingleMappingDefinition]) -> void:
	if len(mappings) == 0:
		_button.set_toggle_no_signal(false)
		return
	if len(mappings) > 1:
		push_error("WINDOW MAPPING EDITOR: Invalid number of mappings towards a memory area!")
		_button.set_toggle_no_signal(false)
		return
	var first_mapping: SingleMappingDefinition = mappings[0]
	if first_mapping.morphology_used.name != "memory":
		push_error("WINDOW MAPPING EDITOR: Invalid morphology %s for memory mapping!" % first_mapping.morphology_used.name)
		_button.set_toggle_no_signal(false)
		return
	_button.set_toggle_no_signal(true)
	
func export_mappings() -> Array[SingleMappingDefinition]:
	if _button.button_pressed:
		var memory: BaseMorphology = FeagiCore.feagi_local_cache.morphologies.available_morphologies["memory"]
		var mapping: SingleMappingDefinition = SingleMappingDefinition.create_default_mapping(memory)
		return [mapping]
	return []



