extends DraggableWindow
class_name WindowEditMappingDefinition
## Window for editing the mapping definitions between 2 cortical areas

var source_area: CorticalArea:
	get: return _source_area
	set(v):
		# break any previous connection first
		if _source_area != null and _source_area.efferent_mapping_updated.is_connected(_mappings_updated):
			_source_area.efferent_mapping_updated.disconnect(_mappings_updated)
		_source_area = v
		_source_area.efferent_mapping_updated.connect(_mappings_updated)
		_request_mappings_from_feagi()

var destination_area: CorticalArea:
	get: return _destination_area
	set(v):
		_destination_area = v
		_request_mappings_from_feagi()

var _source_area: CorticalArea
var _destination_area: CorticalArea
var _sources_dropdown: CorticalDropDown
var _destinations_dropdown: CorticalDropDown
var _mapping_details: WindowMappingDetails

func _ready() -> void:
	super()
	_sources_dropdown = $BoxContainer/SourceAndDestination/src_box/src_dropdown
	_destinations_dropdown = $BoxContainer/SourceAndDestination/des_box/des_dropdown
	_mapping_details = $BoxContainer/Mapping_Details


func setup(cortical_source: CorticalArea = null, cortical_destination: CorticalArea = null):
	var all_cortical_areas: Array[CorticalArea] = []
	all_cortical_areas.assign(FeagiCache.cortical_areas_cache.cortical_areas.values())
	_sources_dropdown.overwrite_cortical_areas(all_cortical_areas)
	_destinations_dropdown.overwrite_cortical_areas(all_cortical_areas)
	if cortical_source != null:
		_sources_dropdown.set_selected_cortical_area(cortical_source)
		source_area = cortical_source
	else:
		_sources_dropdown.select(-1)
	if cortical_destination != null:
		_destinations_dropdown.set_selected_cortical_area(cortical_destination)
		destination_area = cortical_destination
	else:
		_destinations_dropdown.select(-1)
	_sources_dropdown.user_selected_cortical_area.connect(_source_changed)
	_destinations_dropdown.user_selected_cortical_area.connect(_destination_changed)

## Called from the source cortical area via signal whenever a mapping of it is updated
func _mappings_updated(destination: CorticalArea, mappings: MappingProperties) -> void:
	if destination.cortical_ID != destination_area.cortical_ID:
		return # we dont care if a different mapping was updated
	_mapping_details.display_mapping_properties(mappings)

## Request FEAGI to give us the latest information on the user picked mapping (only if both the source and destination are valid)
func _request_mappings_from_feagi() -> void:
	if !_are_cortical_areas_valid():
		_mapping_details.clear_mapping_properties()
		return
	print("Window Edit Mappings is requesting FEAGI for the mapping information of %s to %s" % [_source_area.cortical_ID, _destination_area.cortical_ID])
	FeagiRequests.get_mapping_properties_between_two_areas(source_area, destination_area)

func _request_apply_mappings_to_FEAGI():
	if !_are_cortical_areas_valid():
		push_warning("User attempted to request mappings to undefined cortical areas. Skipping!")
	print("Window Edit Mappings is requesting FEAGI to apply new mappings to %s to %s" % [_source_area.cortical_ID, _destination_area.cortical_ID])
	var current_mappings: MappingProperties = _mapping_details.generate_mapping_properties(_source_area, _destination_area)
	FeagiRequests.request_set_mapping_between_corticals(_source_area, _destination_area, current_mappings)
	close_window("edit_mappings")

## Returns true only if the source and destination areas selected are valid
func _are_cortical_areas_valid() -> bool:
	if _source_area == null or _destination_area == null:
		return false
	return true
func _source_changed(new_source: CorticalArea) -> void:
	source_area = new_source

func _destination_changed(new_destination: CorticalArea) -> void:
	destination_area = new_destination

#TODO add these signals

func _cortical_area_added(new_cortical_area: CorticalArea) -> void:
	pass

func _cortical_area_removed(removed_cortical_area: CorticalArea) -> void:
	pass

func _morphology_added(new_morphology: Morphology) -> void:
	pass

func _morphology_removed(removed_morphology: Morphology) -> void:
	pass

