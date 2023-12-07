extends Object
class_name CorticalAreasCache
## Stores all cortical areas available in the genome

var cortical_areas: Dictionary:
	get: return _cortical_areas

var _cortical_areas: Dictionary = {}

## Adds a cortical area of type core by ID and emits a signal that this was done. Should only be called from FEAGI!
func add_core_cortical_area(cortical_ID: StringName, cortical_name: StringName, coordinates_3D: Vector3i, dimensions: Vector3i, is_coordinate_2D_defined: bool, coordinates_2D: Vector2i, FEAGI_details: Dictionary = {}, is_visible: bool = true) -> void:
	var new_area: CoreCorticalArea = CoreCorticalArea.new(cortical_ID, cortical_name, dimensions, is_visible)
	new_area.coordinates_3D = coordinates_3D
	if is_coordinate_2D_defined:
		new_area.coordinates_2D = coordinates_2D
	new_area.FEAGI_apply_detail_dictionary(FEAGI_details)
	_cortical_areas[cortical_ID] = new_area
	FeagiCacheEvents.cortical_area_added.emit(_cortical_areas[cortical_ID])

## Adds a cortical area of type custom by ID and emits a signal that this was done. Should only be called from FEAGI!
func add_custom_cortical_area(cortical_ID: StringName, cortical_name: StringName, coordinates_3D: Vector3i, dimensions: Vector3i, is_coordinate_2D_defined: bool, coordinates_2D: Vector2i, FEAGI_details: Dictionary = {}, is_visible: bool = true) -> void:
	var new_area: CustomCorticalArea = CustomCorticalArea.new(cortical_ID, cortical_name, dimensions, is_visible)
	new_area.coordinates_3D = coordinates_3D
	if is_coordinate_2D_defined:
		new_area.coordinates_2D = coordinates_2D
	new_area.FEAGI_apply_detail_dictionary(FEAGI_details)
	_cortical_areas[cortical_ID] = new_area
	FeagiCacheEvents.cortical_area_added.emit(_cortical_areas[cortical_ID])

## Adds a cortical area of type IPU by ID and emits a signal that this was done. Should only be called from FEAGI!
func add_input_cortical_area(cortical_ID: StringName, template: CorticalTemplate, coordinates_3D: Vector3i, is_coordinate_2D_defined: bool, coordinates_2D: Vector2i, FEAGI_details: Dictionary = {}, is_visible: bool = true) -> void:
	var new_area: IPUCorticalArea = IPUCorticalArea.create_from_template(cortical_ID, template, is_visible)
	new_area.coordinates_3D = coordinates_3D
	if is_coordinate_2D_defined:
		new_area.coordinates_2D = coordinates_2D
	new_area.FEAGI_apply_detail_dictionary(FEAGI_details)
	_cortical_areas[cortical_ID] = new_area
	FeagiCacheEvents.cortical_area_added.emit(_cortical_areas[cortical_ID])

## Adds a cortical area of type IPU (without a template) by ID and emits a signal that this was done. Should only be called from FEAGI!
func add_input_cortical_area_without_template(cortical_ID: StringName, cortical_name: StringName, coordinates_3D: Vector3i, dimensions: Vector3i, is_coordinate_2D_defined: bool, coordinates_2D: Vector2i, FEAGI_details: Dictionary = {}, is_visible: bool = true) -> void:
	var new_area: IPUCorticalArea = IPUCorticalArea.new(cortical_ID, cortical_name, dimensions, is_visible)
	new_area.coordinates_3D = coordinates_3D
	if is_coordinate_2D_defined:
		new_area.coordinates_2D = coordinates_2D
	new_area.FEAGI_apply_detail_dictionary(FEAGI_details)
	_cortical_areas[cortical_ID] = new_area
	FeagiCacheEvents.cortical_area_added.emit(_cortical_areas[cortical_ID])

## Adds a cortical area of type OPU by ID and emits a signal that this was done. Should only be called from FEAGI!
func add_output_cortical_area(cortical_ID: StringName, template: CorticalTemplate, coordinates_3D: Vector3i, is_coordinate_2D_defined: bool, coordinates_2D: Vector2i, FEAGI_details: Dictionary = {}, is_visible: bool = true) -> void:
	var new_area: OPUCorticalArea = OPUCorticalArea.create_from_template(cortical_ID, template, is_visible)
	new_area.coordinates_3D = coordinates_3D
	if is_coordinate_2D_defined:
		new_area.coordinates_2D = coordinates_2D
	new_area.FEAGI_apply_detail_dictionary(FEAGI_details)
	_cortical_areas[cortical_ID] = new_area
	FeagiCacheEvents.cortical_area_added.emit(_cortical_areas[cortical_ID])

## Adds a cortical area of type OPU (without a template) by ID and emits a signal that this was done. Should only be called from FEAGI!
func add_output_cortical_area_without_template(cortical_ID: StringName, cortical_name: StringName, coordinates_3D: Vector3i, dimensions: Vector3i, is_coordinate_2D_defined: bool, coordinates_2D: Vector2i, FEAGI_details: Dictionary = {}, is_visible: bool = true) -> void:
	var new_area: OPUCorticalArea = OPUCorticalArea.new(cortical_ID, cortical_name, dimensions, is_visible)
	new_area.coordinates_3D = coordinates_3D
	if is_coordinate_2D_defined:
		new_area.coordinates_2D = coordinates_2D
	new_area.FEAGI_apply_detail_dictionary(FEAGI_details)
	_cortical_areas[cortical_ID] = new_area
	FeagiCacheEvents.cortical_area_added.emit(_cortical_areas[cortical_ID])

## Adds a cortical area of type memory by ID and emits a signal that this was done. Should only be called from FEAGI!
func add_memory_cortical_area(cortical_ID: StringName, cortical_name: StringName, coordinates_3D: Vector3i, dimensions: Vector3i, is_coordinate_2D_defined: bool, coordinates_2D: Vector2i, FEAGI_details: Dictionary = {}, is_visible: bool = true) -> void:
	var new_area: MemoryCorticalArea = MemoryCorticalArea.new(cortical_ID, cortical_name, dimensions, is_visible)
	new_area.coordinates_3D = coordinates_3D
	if is_coordinate_2D_defined:
		new_area.coordinates_2D = coordinates_2D
	new_area.FEAGI_apply_detail_dictionary(FEAGI_details)
	_cortical_areas[cortical_ID] = new_area
	FeagiCacheEvents.cortical_area_added.emit(_cortical_areas[cortical_ID])

## Adds a cortical area as per the FEAGI dictionary. Skips over any templates for IPU and OPU and directly creates the object
func add_cortical_area_from_dict(feagi_dictionary: Dictionary) -> void:
	var type: BaseCorticalArea.CORTICAL_AREA_TYPE = BaseCorticalArea.cortical_type_str_to_type(feagi_dictionary["type"])
	var cortical_ID: StringName = feagi_dictionary["cortical_id"]
	var name: StringName = feagi_dictionary["name"]
	var visibility: bool = feagi_dictionary["visible"]
	var dimensions: Vector3i = FEAGIUtils.array_to_vector3i(feagi_dictionary["dimensions"])
	var position_3D: Vector3i = FEAGIUtils.array_to_vector3i(feagi_dictionary["position_3d"])
	var position_2D: Vector2i = Vector2i(0,0)
	var position_2D_defined: bool = feagi_dictionary["position_2d"][0] != null
	
	match type:
		BaseCorticalArea.CORTICAL_AREA_TYPE.CORE:
			add_core_cortical_area(cortical_ID, name, position_3D, dimensions, position_2D_defined, position_2D, feagi_dictionary, visibility)
		BaseCorticalArea.CORTICAL_AREA_TYPE.CUSTOM:
			add_custom_cortical_area(cortical_ID, name, position_3D, dimensions, position_2D_defined, position_2D, feagi_dictionary, visibility)
		BaseCorticalArea.CORTICAL_AREA_TYPE.IPU:
			add_input_cortical_area_without_template(cortical_ID, name, position_3D, dimensions, position_2D_defined, position_2D, feagi_dictionary, visibility)
		BaseCorticalArea.CORTICAL_AREA_TYPE.OPU:
			add_output_cortical_area_without_template(cortical_ID, name, position_3D, dimensions, position_2D_defined, position_2D, feagi_dictionary, visibility)
		BaseCorticalArea.CORTICAL_AREA_TYPE.MEMORY:
			add_memory_cortical_area(cortical_ID, name, position_3D, dimensions, position_2D_defined, position_2D, feagi_dictionary, visibility)
		_:
			push_error("CORE: Unable to spawn cortical area of unknown type! Skipping!")

## Updates a cortical area by ID and emits a signal that this was done. Should only be called from FEAGI!
func update_cortical_area_from_dict(all_cortical_area_properties: Dictionary) -> void:
	var changing_ID: StringName = all_cortical_area_properties["cortical_id"]
	if changing_ID not in _cortical_areas.keys():
		push_error("Cortical area of ID %s does not exist in memory! Unable to Update! Skipping" % [all_cortical_area_properties["cortical_id"]])
		return
	
	var updated_name: StringName = all_cortical_area_properties["cortical_name"]
	var updated_visibility: bool = all_cortical_area_properties["cortical_visibility"]
	var updated_cortical_dimensions: Vector3i = FEAGIUtils.array_to_vector3i(all_cortical_area_properties["cortical_dimensions"])
	
	# these properties already have redudancy checking
	_cortical_areas[changing_ID].name = updated_name
	_cortical_areas[changing_ID].cortical_visibility = updated_visibility
	_cortical_areas[changing_ID].dimensions = updated_cortical_dimensions

	# coordinates may or may not be specified, check the dictionary properly
	if all_cortical_area_properties["cortical_coordinates_2d"][0] != null: # assume either all are null or none are
		_cortical_areas[changing_ID].coordinates_2D = FEAGIUtils.array_to_vector2i(all_cortical_area_properties["cortical_coordinates_2d"])
	if all_cortical_area_properties["cortical_coordinates"][0] != null: # assume either all are null or none are
		_cortical_areas[changing_ID].coordinates_3D = FEAGIUtils.array_to_vector3i(all_cortical_area_properties["cortical_coordinates"])
	
	_cortical_areas[changing_ID].apply_details_dict(all_cortical_area_properties)
	FeagiCacheEvents.cortical_area_updated.emit(_cortical_areas[changing_ID])

## Removes a cortical area by ID and emits a signal that this was done. Should only be called from FEAGI!
func remove_cortical_area(removed_cortical_ID: StringName) -> void:
	if removed_cortical_ID not in _cortical_areas.keys():
		push_error("Attempted to remove cortical area " + removed_cortical_ID + " when already non existant in cache")
		return
	_cortical_areas[removed_cortical_ID].FEAGI_delete_cortical_area()
	FeagiCacheEvents.cortical_area_removed.emit(_cortical_areas[removed_cortical_ID])
	_cortical_areas.erase(removed_cortical_ID)

## Returns an array of cortical areas whose name contains a given substring
## WARNING: Do NOT use this for backend data operations, this is better suited for UI name filtering operations
func search_for_cortical_areas_by_name(search_term: StringName) -> Array[BaseCorticalArea]:
	var output: Array[BaseCorticalArea] = []
	for cortical_area in _cortical_areas.values():
		if cortical_area.name.to_lower().contains(search_term.to_lower()):
			output.append(cortical_area)
	return output

## Returns an array of cortical areas of given cortical type
func search_for_cortical_areas_by_type(searching_cortical_type: BaseCorticalArea.CORTICAL_AREA_TYPE) -> Array[BaseCorticalArea]:
	var output: Array[BaseCorticalArea] = []
	for cortical_area in _cortical_areas.values():
		if cortical_area.group == searching_cortical_type:
			output.append(cortical_area)
	return output

## Returns an array of all the names of the cortical areas
func get_all_cortical_area_names() -> Array[StringName]:
	var output: Array[StringName] = []
	for cortical_area in _cortical_areas.values():
		output.append(cortical_area.cortical_ID)
	return output

## Goes over a dictionary of cortical areas and adds / removes the cached listing as needed. Should only be called from FEAGI
func update_cortical_area_cache_from_summary(_new_listing_with_summaries: Dictionary) -> void:

	# TODO: Possible optimizations used packedStringArrays and less duplications
	var new_listing: Array[StringName] = _new_listing_with_summaries.keys()
	var removed: Array[StringName] = _cortical_areas.keys().duplicate()
	var added: Array[StringName] = []
	var search: int # init here to reduce GC

	# Build arrays of areas that need removal and what needs adding
	for new: StringName in new_listing:
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
	for remove: StringName in removed:
		remove_cortical_area(remove)
	
	# note: not preallocating here certain things due to reference shenanigans, attempt later when system is stable
	# add added cortical areas
	var new_area_summary: Dictionary
	for add in added:
		# since we only have a input dict with the name and type of morphology, we need to generate placeholder objects
		new_area_summary = _new_listing_with_summaries[add]
		add_cortical_area_from_dict(new_area_summary)

## Applies mass update of 2d locations to cortical areas. Only call from FEAGI
func FEAGI_mass_update_2D_positions(IDs_to_locations: Dictionary) -> void:
	for cortical_ID in IDs_to_locations.keys():
		if !(cortical_ID in _cortical_areas.keys()):
			push_error("Unable to update position of %s due to this cortical area missing in cache" % cortical_ID)
			continue
		_cortical_areas[cortical_ID].coordinates_2D = IDs_to_locations[cortical_ID]

## Removes all cached cortical areas (and their connections). Should only be called during a reset
func hard_wipe_cortical_areas():
	print("CACHE: Wiping cortical areas and connections...")
	var all_cortical_area_IDs: Array = _cortical_areas.keys()
	for cortical_area_ID in all_cortical_area_IDs:
		remove_cortical_area(cortical_area_ID)
	print("CACHE: Wiping cortical areas and connection wipe complete!")
