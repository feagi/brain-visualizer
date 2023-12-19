extends DraggableWindow
class_name WindowEditMappingDefinition
## Window for editing the mapping definitions between 2 cortical areas

var source_area: BaseCorticalArea:
	get: return _source_area
	set(v):
		# break any previous connection first
		if _source_area != null and _source_area.efferent_mapping_updated.is_connected(_updated_mapping_UI):
			_source_area.efferent_mapping_updated.disconnect(_updated_mapping_UI)
		_source_area = v
		_source_area.efferent_mapping_edited.connect(_updated_mapping_UI)
		_selected_cortical_areas_changed(_source_area, _destination_area)

var destination_area: BaseCorticalArea:
	get: return _destination_area
	set(v):
		_destination_area = v
		_selected_cortical_areas_changed(_source_area, _destination_area)

var _source_area: BaseCorticalArea
var _destination_area: BaseCorticalArea
var _sources_dropdown: CorticalDropDown
var _destinations_dropdown: CorticalDropDown
var _general_mapping_details: GeneralMappingEditor
var _single_mapping_details: SingleMappingConnectionToggle
var _special_conditions: Array[BaseCorticalArea.MAPPING_SPECIAL_CASES]

func _ready() -> void:
	super()
	_sources_dropdown = $BoxContainer/SourceAndDestination/src_box/src_dropdown
	_destinations_dropdown = $BoxContainer/SourceAndDestination/des_box/des_dropdown
	_general_mapping_details = $BoxContainer/Mapping_Details
	_single_mapping_details = $BoxContainer/SingleMappingConnectionToggle

func setup(cortical_source: BaseCorticalArea = null, cortical_destination: BaseCorticalArea = null):
	if cortical_source != null:
		_sources_dropdown.set_selected_cortical_area(cortical_source)
		_source_area = cortical_source
		_source_area.efferent_mapping_edited.connect(_updated_mapping_UI)
	else:
		_sources_dropdown.select(-1)
		
	if cortical_destination != null:
		_destinations_dropdown.set_selected_cortical_area(cortical_destination)
		_destination_area = cortical_destination
	else:
		_destinations_dropdown.select(-1)
	
	_sources_dropdown.user_selected_cortical_area.connect(_source_changed)
	_destinations_dropdown.user_selected_cortical_area.connect(_destination_changed)

	if !((cortical_source == null) and (cortical_destination == null)):
		_selected_cortical_areas_changed(cortical_source, cortical_destination)

func _selected_cortical_areas_changed(source: BaseCorticalArea, destination: BaseCorticalArea) -> void:
	if !_are_cortical_areas_valid():
		return
	_general_mapping_details.visible = false
	_single_mapping_details.visible = false
	_request_mappings_from_feagi()
	_special_conditions = source.get_special_cases_for_mapping_to_destination(destination)
	if _special_conditions[0] == BaseCorticalArea.MAPPING_SPECIAL_CASES.NONE:
		_general_mapping_details.visible = true
	else:
		_single_mapping_details.visible = true

## Called from the source cortical area via signal whenever a mapping of it is updated
func _updated_mapping_UI(mappings: MappingProperties) -> void:
	if mappings.destination_cortical_area.cortical_ID != destination_area.cortical_ID:
		return # we dont care if a different mapping was updated
	if _special_conditions[0] == BaseCorticalArea.MAPPING_SPECIAL_CASES.NONE:
		_general_mapping_details.display_mapping_properties(mappings)
	else:
		_single_mapping_details.display_mapping_properties(mappings)

## Request FEAGI to give us the latest information on the user picked mapping (only if both the source and destination are valid)
func _request_mappings_from_feagi() -> void:
	if !_are_cortical_areas_valid():
		_general_mapping_details.clear_mapping_properties()
		return
	print("Window Edit Mappings is requesting FEAGI for the mapping information of %s to %s" % [_source_area.cortical_ID, _destination_area.cortical_ID])
	FeagiRequests.get_mapping_properties_between_two_areas(source_area, destination_area)

func _request_apply_mappings_to_FEAGI():
	if !_are_cortical_areas_valid():
		push_warning("User attempted to request mappings to undefined cortical areas. Skipping!")
	print("Window Edit Mappings is requesting FEAGI to apply new mappings to %s to %s" % [_source_area.cortical_ID, _destination_area.cortical_ID])
	
	var mapping_properties: Array[MappingProperty] = []
	if _special_conditions[0] == BaseCorticalArea.MAPPING_SPECIAL_CASES.NONE:
		mapping_properties = _general_mapping_details.generate_mapping_properties()
	else:
		mapping_properties =  _single_mapping_details.generate_mapping_properties()
	
	FeagiRequests.request_set_mapping_between_corticals(_source_area, _destination_area, mapping_properties)
	close_window("edit_mappings")

## Returns true only if the source and destination areas selected are valid
func _are_cortical_areas_valid() -> bool:
	if _source_area == null or _destination_area == null:
		return false
	return true
func _source_changed(new_source: BaseCorticalArea) -> void:
	source_area = new_source

func _destination_changed(new_destination: BaseCorticalArea) -> void:
	destination_area = new_destination
