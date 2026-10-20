extends BaseDraggableWindow
class_name WindowMappingEditor


# possible issues:
# amalgamation, starting region may not be correct


const WINDOW_NAME: StringName = "mapping_editor"
const TEXTURE_ARROW_VALID = preload("res://BrainVisualizer/UI/Windows/MappingEditor/Resources/connection.png")
const TEXTURE_ARROW_INVALID = preload("res://BrainVisualizer/UI/Windows/MappingEditor/Resources/connection-broken.png")

var _source_button: GenomeObjectSelectorButton
var _arrow: TextureRect
var _destination_button: GenomeObjectSelectorButton
var _invalid_message: BoxContainer
var _memory_mapping_setting: MappingEditorMemoryMapping
var _generic_mapping_settings: GenericMappingDetailSettings
var _generic_mapping_settings_partial: GenericMappingDetailSettingsPartial
var _set_mapping_button: Button
var _classifier_destination: GenomeClassifier = null


## Source / Destination cortical are or region, or null.
func setup(source: GenomeObject, destination: GenomeObject, partial_mapping: PartialMappingSet = null) -> void:
	_source_button = _window_internals.get_node("ends/Source")
	_arrow = _window_internals.get_node("ends/Arrow")
	_destination_button = _window_internals.get_node("ends/Destination")
	_invalid_message = _window_internals.get_node("Invalid")
	_memory_mapping_setting = _window_internals.get_node("MappingEditorMemoryMapping")
	_generic_mapping_settings = _window_internals.get_node("GenericMappingDetailSettings")
	_generic_mapping_settings_partial = _window_internals.get_node("GenericMappingDetailSettingsPartial")
	_set_mapping_button = _window_internals.get_node("HBoxContainer/Button")
	_setup_base_window(WINDOW_NAME)
	
	# starting point will be overridden next
	_source_button.setup(null, GenomeObject.SINGLE_MAKEUP.SINGLE_CORTICAL_AREA)
	_destination_button.setup(null, GenomeObject.SINGLE_MAKEUP.SINGLE_CORTICAL_AREA)
	set_ends(source, destination)
	return


func set_ends(source: GenomeObject, destination: GenomeObject, partial_mapping: PartialMappingSet = null) -> void:
	_classifier_destination = null
	_source_button.update_selection_no_signal(source)
	_destination_button.update_selection_no_signal(destination)
	
	if source == null or destination == null:
		_invalid_message.visible = true
		_set_mapping_button.disabled = true
		_arrow.texture = TEXTURE_ARROW_INVALID
		_arrow.tooltip_text = "Only connections between 2 cortical areas is possible."
		
		_memory_mapping_setting.visible = false
		_generic_mapping_settings.visible = false
		_generic_mapping_settings_partial.visible = false
		return
	
	_invalid_message.visible = false
	if FeagiCore != null and FeagiCore.feagi_local_cache != null:
		_classifier_destination = GenomeClassifier.classifier_for_mapping_destination(destination, FeagiCore.feagi_local_cache.classifiers)
	if _classifier_destination != null:
		if not source is AbstractCorticalArea:
			_classifier_destination = null
			_invalid_message.visible = true
			_set_mapping_button.disabled = true
			_arrow.texture = TEXTURE_ARROW_INVALID
			_arrow.tooltip_text = "Classifier inputs start from a cortical area."
			_memory_mapping_setting.visible = false
			_generic_mapping_settings.visible = false
			_generic_mapping_settings_partial.visible = false
			return
		_set_mapping_button.disabled = false
		_arrow.texture = TEXTURE_ARROW_VALID
		_arrow.tooltip_text = "Classifier Sample or Classifier Class."
		_memory_mapping_setting.visible = false
		_generic_mapping_settings_partial.visible = false
		_generic_mapping_settings.visible = true
		var classifier_rules := MappingRestrictionCorticalMorphology.new()
		classifier_rules.preset_morphologies = GenomeClassifier.input_morphologies()
		classifier_rules.allow_changing_scalar = false
		classifier_rules.allow_changing_PSP = false
		classifier_rules.allow_changing_inhibitory = false
		classifier_rules.allow_changing_plasticity = false
		_generic_mapping_settings.load_mappings([], classifier_rules, null)
		_generic_mapping_settings._add_mapping_row()
		return
	
	if source is BrainRegion or destination is BrainRegion:
		# if either are brain regions, then it means we have loaded in some partial settings
		if partial_mapping == null:
			push_error("FEAGI Mapping Editor: One end is a brain region but no partial mapping set was defined!")
			set_ends(null, null)
			return
		_arrow.texture = TEXTURE_ARROW_INVALID
		_arrow.tooltip_text = "Only connections between 2 cortical areas is possible."
		
		_set_mapping_button.disabled = true
		_generic_mapping_settings_partial.visible = true
		_generic_mapping_settings_partial.load_mappings(partial_mapping.mappings) # TODO connect signal for adding
		_memory_mapping_setting.visible = false
		_generic_mapping_settings.visible = false
		return
	
	# both ends are cortical areas
	_set_mapping_button.disabled = false
	_arrow.texture = TEXTURE_ARROW_VALID
	_arrow.tooltip_text = ""
	
	# Use new cached API with fast local lookups
	var restrictions: MappingRestrictionCorticalMorphology = MappingRestrictionsAPI.get_restrictions_between_cortical_areas(source, destination)
	var defaults: MappingRestrictionDefault = MappingRestrictionsAPI.get_defaults_between_cortical_areas(source, destination)
	
	# No need to error on null restrictions/defaults - this is normal for unmatched area types
	# The UI will handle null values gracefully
	
	var current_mappings: Array[SingleMappingDefinition] = source.get_mapping_array_toward_cortical_area(destination)
	
	var destination_is_memory: bool = destination is MemoryCorticalArea
	var source_is_memory: bool = source is MemoryCorticalArea
	if destination_is_memory and not source_is_memory:
		_generic_mapping_settings.visible = false
		_memory_mapping_setting.visible = true
		_memory_mapping_setting.load_mappings(current_mappings)
		return
	else:
		_generic_mapping_settings.visible = true
		_memory_mapping_setting.visible = false
		_generic_mapping_settings.load_mappings(current_mappings, restrictions, defaults)


func _user_pressed_set_mappings() -> void:
	if !(_source_button.current_selected is AbstractCorticalArea) or !(_destination_button.current_selected is AbstractCorticalArea):
		push_error("FEAGI Mapping Editor: Cannot Set mapping on ends that arent cortical areas!")
		return
	if _classifier_destination != null and _source_button.current_selected is AbstractCorticalArea:
		var source_area: AbstractCorticalArea = _source_button.current_selected as AbstractCorticalArea
		for mapping in _generic_mapping_settings.export_mappings():
			if mapping == null or mapping.morphology_used == null:
				continue
			var classifier_result: FeagiRequestOutput = await FeagiCore.requests.map_classifier_input(
				_classifier_destination,
				source_area,
				mapping.morphology_used.name
			)
			if classifier_result == null or not classifier_result.success:
				return
		close_window()
		return
	var mappings: Array[SingleMappingDefinition]
	if _generic_mapping_settings.visible:
		mappings = _generic_mapping_settings.export_mappings()
	else: # assume memory
		mappings = _memory_mapping_setting.export_mappings()
	var out: FeagiRequestOutput = await FeagiCore.requests.set_mappings_between_corticals(
		_source_button.current_selected as AbstractCorticalArea,
		_destination_button.current_selected as AbstractCorticalArea,
		mappings,
	)
	if out.failed_requirement and out.failed_requirement_key in [
		&"USER_CANCELLED_DESIGNATION",
		&"USER_CANCELLED_ALL_TO_ALL",
	]:
		return
	if out.success:
		close_window()


func _source_button_picked(genome_object: GenomeObject) -> void:
	set_ends(genome_object, _destination_button.current_selected)
	#_source_button.change_starting_exploring_region(FeagiCore.feagi_local_cache.brain_regions.get_root_region())

func _destination_button_picked(genome_object: GenomeObject) -> void:
	set_ends(_source_button.current_selected, genome_object)
	#_destination_button.change_starting_exploring_region(FeagiCore.feagi_local_cache.brain_regions.get_root_region())

func _import_partial_mapping(mapping: SingleMappingDefinition) -> void:
	_generic_mapping_settings.import_single_mapping(mapping)
