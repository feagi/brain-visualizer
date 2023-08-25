extends Object
class_name CorticalAreasCache
## Stores all cortical areas available in the genome

var cortical_areas: Dictionary:
	get: return _cortical_areas

var _cortical_areas: Dictionary = {}

# TODO add / update cortical areas

## Adds a cortical area by ID and emits a signal that this was done. Should only be called from FEAGI!
func add_cortical_area_from_dict(all_cortical_area_properties: Dictionary) -> void:
	if all_cortical_area_properties["cortical_id"] in _cortical_areas.keys():
		push_error("Cortical area of ID %s already exists in memory! Unable to add another of the same name! Skipping" % [all_cortical_area_properties["cortical_id"]])
		return

	var new_ID: StringName = all_cortical_area_properties["cortical_id"]
	var new_name: StringName = all_cortical_area_properties["cortical_name"]
	var new_group: CorticalArea.CORTICAL_AREA_TYPE = CorticalArea.CORTICAL_AREA_TYPE[all_cortical_area_properties["cortical_group"]]
	var new_visibility: bool = all_cortical_area_properties["cortical_visibility"]
	var new_cortical_dimensions: Vector3i = FEAGIUtils.array_to_vector3i(all_cortical_area_properties["cortical_dimensions"])
	var new_area: CorticalArea = CorticalArea.new(new_ID, new_name, new_group,  new_visibility, new_cortical_dimensions, all_cortical_area_properties)
	
	# coordinates may or may not be specified, check the dictionary properly
	if all_cortical_area_properties["cortical_coordinates_2d"][0] != null: # assume either all are null or none are
		new_area.coordinates_2D = FEAGIUtils.array_to_vector2i(all_cortical_area_properties["cortical_coordinates_2d"])
	if all_cortical_area_properties["cortical_coordinates"][0] != null: # assume either all are null or none are
		new_area.coordinates_3D = FEAGIUtils.array_to_vector3i(all_cortical_area_properties["cortical_coordinates"])

	_cortical_areas[new_ID] = new_area
	FeagiCacheEvents.cortical_area_added.emit(_cortical_areas[new_ID])
	
## Removes a cortical area by ID and emits a signal that this was done. Should only be called from FEAGI!
func remove_cortical_area(removed_cortical_ID: StringName) -> void:
	if removed_cortical_ID not in _cortical_areas.keys():
		push_error("Attempted to remove cortical area " + removed_cortical_ID + " when already non existant in cache")
		return
	
	FeagiCacheEvents.cortical_area_removed.emit(_cortical_areas[removed_cortical_ID])
	_cortical_areas.erase(removed_cortical_ID)

# TODO add signal passthroughs for cortical areas

## Goes over a dictionary of cortical areas and adds / removes the cached listing as needed
func update_cortical_area_cache_from_summary(_new_listing_with_summaries: Dictionary) -> void:

	# TODO: Possible optimizations used packedStringArrays and less duplications
	var new_listing: Array = _new_listing_with_summaries.keys()
	var removed: Array = _cortical_areas.keys().duplicate()
	var added: Array = []
	var search: int # init here to reduce GC

	# Check what has to be added, what has to be removed
	for new in new_listing:
		search = removed.find(new)
		if search != -1:
			# item was found
			removed.remove_at(search)
			continue
		# new item
		added.append(new)
		continue
	
	# At this point, 'added' has all names of elements that need to be added, while 'removed' has all elements that need to be removed

	# remove removed cortical areas
	for remove in removed:
		FeagiCacheEvents.cortical_area_removed.emit(_cortical_areas[remove])
		_cortical_areas.erase(remove)
	
	# note: not preallocating here certain things due to reference shenanigans, attempt later when system is stable
	# add added cortical areas
	var new_area_summary: Dictionary
	var new_cortical_type: CorticalArea.CORTICAL_AREA_TYPE
	var new_cortical_name: StringName
	var new_cortical_visibility: bool
	var new_cortical_dimensions: Vector3i
	for add in added:
		# since we only have a input dict with the name and type of morphology, we need to generate placeholder objects
		new_area_summary = _new_listing_with_summaries[add]
		new_cortical_type = CorticalArea.CORTICAL_AREA_TYPE[new_area_summary["type"].to_upper()]
		new_cortical_name = new_area_summary["name"]
		new_cortical_visibility = new_area_summary["visible"]
		new_cortical_dimensions = FEAGIUtils.array_to_vector3i(new_area_summary["dimensions"])
		var adding_cortical_area: CorticalArea = CorticalArea.new(add, new_cortical_name, new_cortical_type, new_cortical_visibility, new_cortical_dimensions)

		# check if 3D and 2D positions exist, if so apply them
		# signals here can emit all they want, they arent connected yet, so theres no chance of feedback loops
		if new_area_summary["position_2d"][0] != null: # assume either all are null or none are
			adding_cortical_area.coordinates_2D = FEAGIUtils.array_to_vector2i(new_area_summary["position_2d"])
		if new_area_summary["position_3d"][0] != null: # assume either all are null or none are
			adding_cortical_area.coordinates_3D = FEAGIUtils.array_to_vector3i(new_area_summary["position_3d"])
		
		_cortical_areas[add] = adding_cortical_area
		FeagiCacheEvents.cortical_area_added.emit(adding_cortical_area)



