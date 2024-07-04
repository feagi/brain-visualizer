extends BaseDraggableWindow
class_name WindowMappingEditor

const WINDOW_NAME: StringName = "mapping_editor"
const TEXTURE_ARROW_VALID = preload("res://BrainVisualizer/UI/Windows/MappingEditor/Resources/connection.png")
const TEXTURE_ARROW_INVALID = preload("res://BrainVisualizer/UI/Windows/MappingEditor/Resources/connection-broken.png")

var _source: GenomeObject
var _destination: GenomeObject

var _generic_mapping_settings: GenericMappingDetailSettings
var _generic_mapping_settings_partial: GenericMappingDetailSettingsPartial
var _source_button: GenomeObjectSelectorButton
var _destination_button: GenomeObjectSelectorButton
var _arrow: TextureRect
var _suggested_label: Label
var _partial_mapping: PartialMappingSet = null



func setup(source: GenomeObject, destination: GenomeObject, partial_mapping: PartialMappingSet = null) -> void:
	_source_button = _window_internals.get_node("ends/Source")
	_arrow = _window_internals.get_node("ends/Arrow")
	_destination_button = _window_internals.get_node("ends/Destination")
	_generic_mapping_settings = _window_internals.get_node("GenericMappingDetailSettings")
	_generic_mapping_settings_partial = _window_internals.get_node("GenericMappingDetailSettingsPartial")
	_suggested_label = _window_internals.get_node("suggested")
	
	_setup_base_window(WINDOW_NAME)
	_source = source
	_destination = destination
	

	var source_button_start_explorer: BrainRegion = FeagiCore.feagi_local_cache.brain_regions.get_root_region()
	var destination_button_start_explorer: BrainRegion = FeagiCore.feagi_local_cache.brain_regions.get_root_region()
	
	if source is BrainRegion:
		source_button_start_explorer = source
		_arrow.texture = TEXTURE_ARROW_INVALID
		_arrow.tooltip_text = "Only connections between 2 cortical areas is possible."
	if destination is BrainRegion:
		destination_button_start_explorer = destination
		_arrow.texture = TEXTURE_ARROW_INVALID
		_arrow.tooltip_text = "Only connections between 2 cortical areas is possible."
	
	_generic_mapping_settings_partial.import_mapping_hint.connect(_generic_mapping_settings.import_single_mapping)
	_source_button.setup(source, GenomeObject.SINGLE_MAKEUP.SINGLE_CORTICAL_AREA, source_button_start_explorer)
	_destination_button.setup(destination, GenomeObject.SINGLE_MAKEUP.SINGLE_CORTICAL_AREA, destination_button_start_explorer)
	if _source is AbstractCorticalArea and _destination is AbstractCorticalArea:
		_load_mapping_between_cortical_areas(source as AbstractCorticalArea, destination as AbstractCorticalArea)
	_load_partial_mappings(partial_mapping)


func set_2_genome_objects(source: GenomeObject, destination: GenomeObject) -> void:
	_source_button.update_selection_no_signal(source)
	_destination_button.update_selection_no_signal(destination)
	_source = source
	_destination = destination
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
	_arrow.texture = TEXTURE_ARROW_VALID
	_arrow.tooltip_text = ""
	var restrictions: MappingRestrictionCorticalMorphology = FeagiCore.feagi_local_cache.mapping_restrictions.get_restrictions_between_2_cortical_areas(source, destination)
	var defaults: MappingRestrictionDefault = FeagiCore.feagi_local_cache.mapping_restrictions.get_defaults_between_2_cortical_areas(source, destination)
	
	_generic_mapping_settings.clear()
	var mappings: Array[SingleMappingDefinition] = source.get_mapping_array_toward_cortical_area(destination)
	_generic_mapping_settings.load_mappings(mappings, restrictions, defaults)
	

## Loads a set of partial mappings given one. Unloads it and clears the GUI if null is passed
func _load_partial_mappings(partial_mapping: PartialMappingSet) -> void:
	_partial_mapping = partial_mapping
	if partial_mapping == null:
		_generic_mapping_settings_partial.clear()
		_suggested_label.visible = false
		_generic_mapping_settings_partial.visible = false
	else:
		_generic_mapping_settings_partial.load_mappings(partial_mapping.mappings)
		_suggested_label.visible = true
		_generic_mapping_settings_partial.visible = true

func _user_pressed_set_mappings() -> void:
	var mappings: Array[SingleMappingDefinition]
	mappings = _generic_mapping_settings.export_mappings()
	FeagiCore.requests.set_mappings_between_corticals(_source, _destination, mappings)
	close_window()


func _source_button_picked(genome_object: GenomeObject) -> void:
	if _source is BrainRegion:
		if !(_source as BrainRegion).is_root_region():
			if _destination is AbstractCorticalArea:
				var partial_mapping: PartialMappingSet = (_source as BrainRegion).return_partial_mapping_set_of_target_area(_destination as AbstractCorticalArea)
				_load_partial_mappings(partial_mapping)
	elif _destination is BrainRegion:
		if !(_destination as BrainRegion).is_root_region():
			if _source is AbstractCorticalArea:
				var partial_mapping: PartialMappingSet = (_destination as BrainRegion).return_partial_mapping_set_of_target_area(_source as AbstractCorticalArea)
				_load_partial_mappings(partial_mapping)
		 
	set_2_genome_objects(genome_object, _destination)
	_source_button.change_starting_exploring_region(FeagiCore.feagi_local_cache.brain_regions.get_root_region())

func _destination_button_picked(genome_object: GenomeObject) -> void:
	if _source is BrainRegion:
		if !(_source as BrainRegion).is_root_region():
			if _destination is AbstractCorticalArea:
				var partial_mapping: PartialMappingSet = (_source as BrainRegion).return_partial_mapping_set_of_target_area(genome_object as AbstractCorticalArea)
				_load_partial_mappings(partial_mapping)
	elif _destination is BrainRegion:
		if !(_destination as BrainRegion).is_root_region():
			if _source is AbstractCorticalArea:
				var partial_mapping: PartialMappingSet = (_destination as BrainRegion).return_partial_mapping_set_of_target_area(genome_object as AbstractCorticalArea)
				_load_partial_mappings(partial_mapping)
	
	set_2_genome_objects(_source, genome_object)
	_destination_button.change_starting_exploring_region(FeagiCore.feagi_local_cache.brain_regions.get_root_region())

func _import_partial_mapping(mapping: SingleMappingDefinition) -> void:
	_generic_mapping_settings.add
