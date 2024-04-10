extends BaseDraggableWindow
class_name WindowEditMappingDefinition
## Window for editing the mapping definitions between 2 cortical areas

var _source_area: BaseCorticalArea
var _destination_area: BaseCorticalArea
var _sources_dropdown: CorticalDropDown
var _destinations_dropdown: CorticalDropDown
var _general_mapping_details: GeneralMappingEditor
var _spawn_default_mapping_if_applicable_on_spawn

func _ready() -> void:
	super()
	_sources_dropdown = _window_internals.get_node("SourceAndDestination/src_box/src_dropdown")
	_destinations_dropdown = _window_internals.get_node("SourceAndDestination/des_box/des_dropdown")
	_general_mapping_details = _window_internals.get_node("Mapping_Details")

func setup(cortical_source: BaseCorticalArea = null, cortical_destination: BaseCorticalArea = null, spawn_default_mapping_if_applicable = false):
	_setup_base_window("edit_mappings")
	_spawn_default_mapping_if_applicable_on_spawn = spawn_default_mapping_if_applicable
	if cortical_source != null:
		_sources_dropdown.set_selected_cortical_area(cortical_source)
		_source_area = cortical_source
		_source_area.efferent_mapping_retrieved_from_feagi.connect(_retrieved_feagi_mapping_data)
	else:
		_sources_dropdown.select(-1)
		_spawn_default_mapping_if_applicable_on_spawn = false
		
	if cortical_destination != null:
		_destinations_dropdown.set_selected_cortical_area(cortical_destination)
		_destination_area = cortical_destination
	else:
		_destinations_dropdown.select(-1)
		_spawn_default_mapping_if_applicable_on_spawn = false

	if !((cortical_source == null) and (cortical_destination == null)):
		_selected_cortical_areas_changed(cortical_source, cortical_destination)
	

func _selected_cortical_areas_changed(source: BaseCorticalArea, destination: BaseCorticalArea) -> void:
	if !_are_cortical_areas_valid():
		return
	
	BV.CB.set_outlining_state_of_connection(source, destination, true)
	
	_request_mappings_from_feagi()

## Overridden!
func close_window():
	if _source_area != null && _destination_area != null:
		BV.CB.set_outlining_state_of_connection(_source_area, _destination_area, false)
	super()

## Called from the source cortical area via signal whenever a mapping of it is updated
func _retrieved_feagi_mapping_data(mappings: MappingProperties) -> void:
	var mapping_hints: MappingHints = MappingHints.new(_source_area, _destination_area)
	_general_mapping_details.update_displayed_mapping_properties(mappings.duplicate(), mapping_hints)
	if _spawn_default_mapping_if_applicable_on_spawn:
		_general_mapping_details.add_default_mapping_if_applicable()
		_spawn_default_mapping_if_applicable_on_spawn = false

## Request FEAGI to give us the latest information on the user picked mapping (only if both the source and destination are valid)
func _request_mappings_from_feagi() -> void:
	if !_are_cortical_areas_valid():
		return
	_general_mapping_details.visible = true
	print("Window Edit Mappings is requesting FEAGI for the mapping information of %s to %s" % [_source_area.cortical_ID, _destination_area.cortical_ID])
	FeagiCore.requests.get_mappings_between_2_cortical_areas(_source_area.cortical_ID, _destination_area.cortical_ID)

func _request_apply_mappings_to_FEAGI():
	if !_are_cortical_areas_valid():
		push_warning("User attempted to request applying mappings to undefined cortical areas. Skipping!")
	print("Window Edit Mappings is requesting FEAGI to apply new mappings to %s to %s" % [_source_area.cortical_ID, _destination_area.cortical_ID])
	var mapping_properties: Array[MappingProperty] = _general_mapping_details.generate_mapping_propertys()
	FeagiCore.requests.set_mappings_between_corticals(_source_area, _destination_area, mapping_properties)
	close_window()

## Returns true only if the source and destination areas selected are valid
func _are_cortical_areas_valid() -> bool:
	if _source_area == null or _destination_area == null:
		return false
	return true

func _source_changed(new_source: BaseCorticalArea) -> void:
	if _source_area != null:
		if _source_area.efferent_mapping_retrieved_from_feagi.is_connected(_retrieved_feagi_mapping_data):
			_source_area.efferent_mapping_retrieved_from_feagi.disconnect(_retrieved_feagi_mapping_data)
		BV.CB.set_outlining_state_of_connection(_source_area, _destination_area, false)
	_source_area = new_source
	_source_area.efferent_mapping_retrieved_from_feagi.connect(_retrieved_feagi_mapping_data)
	_selected_cortical_areas_changed(_source_area, _destination_area)

func _destination_changed(new_destination: BaseCorticalArea) -> void:
	if _destination_area != null:
		BV.CB.set_outlining_state_of_connection(_source_area, _destination_area, false)
	_destination_area = new_destination
	_selected_cortical_areas_changed(_source_area, _destination_area)
