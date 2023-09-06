extends GrowingPanel
class_name WindowEditMappingDefinition

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
var _sources_dropdown: DropDown
var _destinations_dropdown: DropDown
var _mapping_properties_ref: MappingProperties
var _mapping_details: WindowMappingDetails


func _ready() -> void:
	_sources_dropdown = $VBoxContainer/SourceAndDestination/src_box/src_dropdown
	_destinations_dropdown = $VBoxContainer/SourceAndDestination/des_box/des_dropdown
	_mapping_details = $VBoxContainer/Mapping_Details


func setup(cortical_source: CorticalArea = null, cortical_destination: CorticalArea = null):
	_sources_dropdown.options = FeagiCache.cortical_areas_cache.cortical_areas.keys()
	_destinations_dropdown.options = FeagiCache.cortical_areas_cache.cortical_areas.keys()
	if cortical_source != null:
		_sources_dropdown.set_option(cortical_source.cortical_ID)
		source_area = cortical_source
	if cortical_destination != null:
		_destinations_dropdown.set_option(cortical_destination.cortical_ID)
		destination_area = cortical_destination

## Called from the source cortical area via signal whenever a mapping of it is updated
func _mappings_updated(destination: CorticalArea, mappings: MappingProperties) -> void:
	if destination.cortical_ID != destination_area.cortical_ID:
		return # we dont care if a different mapping was updated
	
	_mapping_properties_ref = mappings.duplicate() # to avoid reference shenanigans
	print("Window Edit Mappings is loading new mappings...")
	_mapping_details.display_mapping_properties(_mapping_properties_ref)

## Request FEAGI to give us the latest information on the user picked mapping (only if both the source and destination are valid)
func _request_mappings_from_feagi() -> void:
	if !_are_cortical_areas_valid():
		_mapping_details.clear_mapping_properties()
		return
	print("Window Edit Mappings is now requesting FEAGI for the mapping information of %s to %s" % [_source_area.cortical_ID, _destination_area.cortical_ID])
	FeagiRequests.get_mapping_properties_between_two_areas(source_area, destination_area)

func _request_apply_mappings_to_FEAGI():
	if !_are_cortical_areas_valid():
		push_warning("User attempted to request mappings to undefined cortical areas. Skipping!")
	FeagiRequests.request_set_mapping_between_corticals(_source_area, _destination_area, _mapping_properties_ref)


## Returns true only if the source and destination areas selected are valid
func _are_cortical_areas_valid() -> bool:
	if _source_area == null or _destination_area == null:
		return false
	return true


#TODO add these signals

func _cortical_area_added(new_cortical_area: CorticalArea) -> void:
	pass

func _cortical_area_removed(removed_cortical_area: CorticalArea) -> void:
	pass

func _morphology_added(new_morphology: Morphology) -> void:
	pass

func _morphology_removed(removed_morphology: Morphology) -> void:
	pass
