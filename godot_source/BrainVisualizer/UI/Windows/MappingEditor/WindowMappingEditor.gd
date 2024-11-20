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
	
	var restrictions: MappingRestrictionCorticalMorphology = FeagiCore.feagi_local_cache.mapping_restrictions.get_restrictions_between_2_cortical_areas(source, destination)
	if restrictions == null:
		push_error("FEAGI Mapping Editor: Unable to load restrictions between %s and %s!" % [source.genome_ID, destination.genome_ID])
		set_ends(null, null)
		return
	var defaults: MappingRestrictionDefault = FeagiCore.feagi_local_cache.mapping_restrictions.get_defaults_between_2_cortical_areas(source, destination)
	if defaults == null:
		push_error("FEAGI Mapping Editor: Unable to load defaults between %s and %s!" % [source.genome_ID, destination.genome_ID])
		set_ends(null, null)
		return
	var current_mappings: Array[SingleMappingDefinition] = source.get_mapping_array_toward_cortical_area(destination)
	
	if destination is MemoryCorticalArea:
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
	var mappings: Array[SingleMappingDefinition]
	mappings = _generic_mapping_settings.export_mappings()
	FeagiCore.requests.set_mappings_between_corticals((_source_button.current_selected as AbstractCorticalArea), (_destination_button.current_selected as AbstractCorticalArea), mappings)
	close_window()


func _source_button_picked(genome_object: GenomeObject) -> void:
	set_ends(genome_object, _destination_button.current_selected)
	#_source_button.change_starting_exploring_region(FeagiCore.feagi_local_cache.brain_regions.get_root_region())

func _destination_button_picked(genome_object: GenomeObject) -> void:
	set_ends(_source_button.current_selected, genome_object)
	#_destination_button.change_starting_exploring_region(FeagiCore.feagi_local_cache.brain_regions.get_root_region())

func _import_partial_mapping(mapping: SingleMappingDefinition) -> void:
	_generic_mapping_settings.import_single_mapping(mapping)
