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
var _source_button: GenomeObjectSelectorButton
var _destination_button: GenomeObjectSelectorButton



func setup(source: GenomeObject, destination: GenomeObject) -> void:
	_source_button = _window_internals.get_node("ends/Source")
	_destination_button = _window_internals.get_node("ends/Destination")
	_generic_mapping_settings = _window_internals.get_node("GenericMappingDetailSettings")
	_setup_base_window(WINDOW_NAME)
	_source = source
	_destination = destination
	_source_button.setup(source, GenomeObject.SINGLE_MAKEUP.SINGLE_CORTICAL_AREA)
	_destination_button.setup(destination, GenomeObject.SINGLE_MAKEUP.SINGLE_CORTICAL_AREA)
	if _source is AbstractCorticalArea and _destination is AbstractCorticalArea:
		_load_mapping_between_cortical_areas(source as AbstractCorticalArea, destination as AbstractCorticalArea)


func set_2_genome_objects(source: GenomeObject, destination: GenomeObject) -> void:
	_source_button.update_selection_no_signal(source)
	_destination_button.update_selection_no_signal(destination)
	_source = source
	_destination = destination
	if _source is AbstractCorticalArea and _destination is AbstractCorticalArea:
		_load_mapping_between_cortical_areas(source as AbstractCorticalArea, destination as AbstractCorticalArea)


func _load_mapping_between_cortical_areas(source: AbstractCorticalArea, destination: AbstractCorticalArea) -> void:
	var restrictions: MappingRestrictionCorticalMorphology = FeagiCore.feagi_local_cache.mapping_restrictions.get_restrictions_between_2_cortical_areas(source, destination)
	var defaults: MappingRestrictionDefault = FeagiCore.feagi_local_cache.mapping_restrictions.get_defaults_between_2_cortical_areas(source, destination)
	if restrictions.restriction_name == MappingRestrictionCorticalMorphology.RESTRICTION_NAME.DEFAULT:
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
		
func _user_pressed_set_mappings() -> void:
	var mappings: Array[SingleMappingDefinition]
	match(_mode):
		MODE.GENERAL_MAPPING:
			mappings = _generic_mapping_settings.export_mappings()
			FeagiCore.requests.set_mappings_between_corticals(_source, _destination, mappings)
			close_window()

func _source_button_picked(genome_object: GenomeObject) -> void:
	set_2_genome_objects(genome_object, _destination)

func _destination_button_picked(genome_object: GenomeObject) -> void:
	set_2_genome_objects(_source, genome_object)
