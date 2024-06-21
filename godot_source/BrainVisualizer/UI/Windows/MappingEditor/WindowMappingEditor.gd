extends BaseDraggableWindow
class_name WindowMappingEditor

const WINDOW_NAME: StringName = "mapping_editor"

enum MODE {
	NOTHING,
	GENERAL_MAPPING,
	TOWARDS_MEMORY
}

var _source: GenomeObject
var _destination: GenomeObject
var _mode: MODE

var _generic_mapping_settings: GenericMappingDetailSettings
var _memory_mapping: MappingEditorMemoryMapping
var _generic_mapping_settings_partial: GenericMappingDetailSettingsPartial
var _source_button: GenomeObjectSelectorButton
var _destination_button: GenomeObjectSelectorButton
var _suggested_label: Label
var _partial_mapping: PartialMappingSet = null



func setup(source: GenomeObject, destination: GenomeObject, partial_mapping: PartialMappingSet = null) -> void:
	_source_button = _window_internals.get_node("ends/Source")
	_memory_mapping = _window_internals.get_node("MappingEditorMemoryMapping")
	_destination_button = _window_internals.get_node("ends/Destination")
	_generic_mapping_settings = _window_internals.get_node("GenericMappingDetailSettings")
	_generic_mapping_settings_partial = _window_internals.get_node("GenericMappingDetailSettingsPartial")
	_suggested_label = _window_internals.get_node("suggested")
	
	_setup_base_window(WINDOW_NAME)
	_source = source
	_destination = destination
	_partial_mapping = partial_mapping
	_source_button.setup(source, GenomeObject.SINGLE_MAKEUP.SINGLE_CORTICAL_AREA)
	_destination_button.setup(destination, GenomeObject.SINGLE_MAKEUP.SINGLE_CORTICAL_AREA)
	_memory_mapping.visible = false
	_generic_mapping_settings.visible = false
	if _source is AbstractCorticalArea and _destination is AbstractCorticalArea:
		_load_mapping_between_cortical_areas(source as AbstractCorticalArea, destination as AbstractCorticalArea)
	if partial_mapping == null:
		_generic_mapping_settings_partial.clear()
		_generic_mapping_settings_partial.visible = false
		_suggested_label.visible = false
	else:
		_generic_mapping_settings_partial.load_mappings(partial_mapping.mappings)
		_suggested_label.visible = true
		_generic_mapping_settings_partial.import_mapping_hint.connect(_generic_mapping_settings.import_single_mapping)


func set_2_genome_objects(source: GenomeObject, destination: GenomeObject) -> void:
	_source_button.update_selection_no_signal(source)
	_destination_button.update_selection_no_signal(destination)
	_source = source
	_destination = destination
	_memory_mapping.visible = false
	_generic_mapping_settings.visible = false
	if _source is AbstractCorticalArea and _destination is AbstractCorticalArea:
		_load_mapping_between_cortical_areas(source as AbstractCorticalArea, destination as AbstractCorticalArea)
	if _partial_mapping == null:
		return
	if !((source.genome_ID == _partial_mapping.internal_target_cortical_area.genome_ID) or (destination.genome_ID == _partial_mapping.internal_target_cortical_area.genome_ID)):
		_partial_mapping == null
		_generic_mapping_settings_partial.clear()
		_generic_mapping_settings_partial.visible = false
	
func _load_mapping_between_cortical_areas(source: AbstractCorticalArea, destination: AbstractCorticalArea) -> void:
	var restrictions: MappingRestrictionCorticalMorphology = FeagiCore.feagi_local_cache.mapping_restrictions.get_restrictions_between_2_cortical_areas(source, destination)
	var defaults: MappingRestrictionDefault = FeagiCore.feagi_local_cache.mapping_restrictions.get_defaults_between_2_cortical_areas(source, destination)
	match(restrictions.restriction_name):
		MappingRestrictionCorticalMorphology.RESTRICTION_NAME.DEFAULT:
			# Seems like a generic no frills mapping
			_mode = MODE.GENERAL_MAPPING
			_generic_mapping_settings.clear()
			_generic_mapping_settings.visible = true
			var mappings: Array[SingleMappingDefinition] = source.get_mapping_array_toward_cortical_area(destination)
			var default_morphlogy_name: StringName = FeagiCore.feagi_local_cache.mapping_restrictions.get_defaults_between_2_cortical_areas(source, destination).name_of_default_morphology
			var default_morphology_for_new_mappings: BaseMorphology = null
			if default_morphlogy_name in FeagiCore.feagi_local_cache.morphologies.available_morphologies:
				default_morphology_for_new_mappings = FeagiCore.feagi_local_cache.morphologies.available_morphologies[default_morphlogy_name]
			_generic_mapping_settings.load_mappings(mappings, default_morphology_for_new_mappings)
		MappingRestrictionCorticalMorphology.RESTRICTION_NAME.TOWARD_MEMORY:
			_mode = MODE.TOWARDS_MEMORY
			_generic_mapping_settings.clear()
			_memory_mapping.visible = true
			var mappings: Array[SingleMappingDefinition] = source.get_mapping_array_toward_cortical_area(destination)
			_memory_mapping.load_mappings(mappings)
			
		
func _user_pressed_set_mappings() -> void:
	var mappings: Array[SingleMappingDefinition]
	match(_mode):
		MODE.GENERAL_MAPPING:
			mappings = _generic_mapping_settings.export_mappings()
			FeagiCore.requests.set_mappings_between_corticals(_source, _destination, mappings)
			close_window()
		MODE.TOWARDS_MEMORY:
			mappings = _memory_mapping.export_mappings()
			FeagiCore.requests.set_mappings_between_corticals(_source, _destination, mappings)
			close_window()

func _source_button_picked(genome_object: GenomeObject) -> void:
	set_2_genome_objects(genome_object, _destination)

func _destination_button_picked(genome_object: GenomeObject) -> void:
	set_2_genome_objects(_source, genome_object)

func _import_partial_mapping(mapping: SingleMappingDefinition) -> void:
	_generic_mapping_settings.add
