extends RefCounted
class_name CorticalAreasCache
## Stores all cortical areas available in the genome

signal cortical_area_added(cortical_area: BaseCorticalArea)
signal cortical_area_about_to_be_removed(cortical_area: BaseCorticalArea) ## We need this generic signal since dropdown popups cannot do individual reference processing
signal cortical_area_mass_updated(cortical_area: BaseCorticalArea)
signal cortical_area_mappings_changed(source: BaseCorticalArea, destination: BaseCorticalArea)

## All stored cortical areas, key'd by ID string
var available_cortical_areas: Dictionary:
	get: return _available_cortical_areas

var _available_cortical_areas: Dictionary = {}

#region Add, Remove, and Edit Single Cortical Areas
## Adds a cortical area of type core by ID and emits a signal that this was done. Should only be called from FEAGI!
func add_core_cortical_area(cortical_ID: StringName, cortical_name: StringName, coordinates_3D: Vector3i, dimensions: Vector3i, is_coordinate_2D_defined: bool, coordinates_2D: Vector2i, FEAGI_details: Dictionary = {}, is_visible: bool = true) -> void:
	var new_area: CoreCorticalArea = CoreCorticalArea.new(cortical_ID, cortical_name, dimensions, is_visible)
	new_area.coordinates_3D = coordinates_3D
	if is_coordinate_2D_defined:
		new_area.coordinates_2D = coordinates_2D
	new_area.FEAGI_apply_detail_dictionary(FEAGI_details)
	_available_cortical_areas[cortical_ID] = new_area
	new_area.efferent_mapping_retrieved_from_feagi.connect(_mapping_updated)
	print("FEAGI CACHE: Added core cortical area %s" % cortical_ID)
	cortical_area_added.emit(new_area)

## Adds a cortical area of type custom by ID and emits a signal that this was done. Should only be called from FEAGI!
func add_custom_cortical_area(cortical_ID: StringName, cortical_name: StringName, coordinates_3D: Vector3i, dimensions: Vector3i, is_coordinate_2D_defined: bool, coordinates_2D: Vector2i, FEAGI_details: Dictionary = {}, is_visible: bool = true) -> void:
	var new_area: CustomCorticalArea = CustomCorticalArea.new(cortical_ID, cortical_name, dimensions, is_visible)
	new_area.coordinates_3D = coordinates_3D
	if is_coordinate_2D_defined:
		new_area.coordinates_2D = coordinates_2D
	new_area.FEAGI_apply_detail_dictionary(FEAGI_details)
	_available_cortical_areas[cortical_ID] = new_area
	new_area.efferent_mapping_retrieved_from_feagi.connect(_mapping_updated)
	print("FEAGI CACHE: Added custom cortical area %s" % cortical_ID)
	cortical_area_added.emit(new_area)

## Adds a cortical area of type IPU by ID and emits a signal that this was done. Should only be called from FEAGI!
func add_input_cortical_area(cortical_ID: StringName, template: CorticalTemplate, coordinates_3D: Vector3i, is_coordinate_2D_defined: bool, coordinates_2D: Vector2i, FEAGI_details: Dictionary = {}, is_visible: bool = true) -> void:
	var new_area: IPUCorticalArea = IPUCorticalArea.create_from_template(cortical_ID, template, is_visible)
	new_area.coordinates_3D = coordinates_3D
	if is_coordinate_2D_defined:
		new_area.coordinates_2D = coordinates_2D
	new_area.FEAGI_apply_detail_dictionary(FEAGI_details)
	_available_cortical_areas[cortical_ID] = new_area
	new_area.efferent_mapping_retrieved_from_feagi.connect(_mapping_updated)
	print("FEAGI CACHE: Added input cortical area %s" % cortical_ID)
	cortical_area_added.emit(new_area)

## Adds a cortical area of type IPU (without a template) by ID and emits a signal that this was done. Should only be called from FEAGI!
func add_input_cortical_area_without_template(cortical_ID: StringName, cortical_name: StringName, coordinates_3D: Vector3i, dimensions: Vector3i, is_coordinate_2D_defined: bool, coordinates_2D: Vector2i, FEAGI_details: Dictionary = {}, is_visible: bool = true) -> void:
	var new_area: IPUCorticalArea = IPUCorticalArea.new(cortical_ID, cortical_name, dimensions, is_visible)
	new_area.coordinates_3D = coordinates_3D
	if is_coordinate_2D_defined:
		new_area.coordinates_2D = coordinates_2D
	new_area.FEAGI_apply_detail_dictionary(FEAGI_details)
	_available_cortical_areas[cortical_ID] = new_area
	new_area.efferent_mapping_retrieved_from_feagi.connect(_mapping_updated)
	print("FEAGI CACHE: Added input cortical area %s" % cortical_ID)
	cortical_area_added.emit(new_area)

## Adds a cortical area of type OPU by ID and emits a signal that this was done. Should only be called from FEAGI!
func add_output_cortical_area(cortical_ID: StringName, template: CorticalTemplate, coordinates_3D: Vector3i, is_coordinate_2D_defined: bool, coordinates_2D: Vector2i, FEAGI_details: Dictionary = {}, is_visible: bool = true) -> void:
	var new_area: OPUCorticalArea = OPUCorticalArea.create_from_template(cortical_ID, template, is_visible)
	new_area.coordinates_3D = coordinates_3D
	if is_coordinate_2D_defined:
		new_area.coordinates_2D = coordinates_2D
	new_area.FEAGI_apply_detail_dictionary(FEAGI_details)
	_available_cortical_areas[cortical_ID] = new_area
	new_area.efferent_mapping_retrieved_from_feagi.connect(_mapping_updated)
	print("FEAGI CACHE: Added output cortical area %s" % cortical_ID)
	cortical_area_added.emit(new_area)

## Adds a cortical area of type OPU (without a template) by ID and emits a signal that this was done. Should only be called from FEAGI!
func add_output_cortical_area_without_template(cortical_ID: StringName, cortical_name: StringName, coordinates_3D: Vector3i, dimensions: Vector3i, is_coordinate_2D_defined: bool, coordinates_2D: Vector2i, FEAGI_details: Dictionary = {}, is_visible: bool = true) -> void:
	var new_area: OPUCorticalArea = OPUCorticalArea.new(cortical_ID, cortical_name, dimensions, is_visible)
	new_area.coordinates_3D = coordinates_3D
	if is_coordinate_2D_defined:
		new_area.coordinates_2D = coordinates_2D
	new_area.FEAGI_apply_detail_dictionary(FEAGI_details)
	_available_cortical_areas[cortical_ID] = new_area
	new_area.efferent_mapping_retrieved_from_feagi.connect(_mapping_updated)
	print("FEAGI CACHE: Added output cortical area %s" % cortical_ID)
	cortical_area_added.emit(new_area)

## Adds a cortical area of type memory by ID and emits a signal that this was done. Should only be called from FEAGI!
func add_memory_cortical_area(cortical_ID: StringName, cortical_name: StringName, coordinates_3D: Vector3i, dimensions: Vector3i, is_coordinate_2D_defined: bool, coordinates_2D: Vector2i, FEAGI_details: Dictionary = {}, is_visible: bool = true) -> void:
	var new_area: MemoryCorticalArea = MemoryCorticalArea.new(cortical_ID, cortical_name, dimensions, is_visible)
	new_area.coordinates_3D = coordinates_3D
	if is_coordinate_2D_defined:
		new_area.coordinates_2D = coordinates_2D
	new_area.FEAGI_apply_detail_dictionary(FEAGI_details)
	_available_cortical_areas[cortical_ID] = new_area
	new_area.efferent_mapping_retrieved_from_feagi.connect(_mapping_updated)
	print("FEAGI CACHE: Added memory cortical area %s" % cortical_ID)
	cortical_area_added.emit(new_area)

## Adds a cortical area as per the FEAGI dictionary. Skips over any templates for IPU and OPU and directly creates the object
func add_cortical_area_from_dict(feagi_dictionary: Dictionary, override_cortical_ID: StringName = "") -> void:
	if override_cortical_ID != &"":
		# Some dictionary responses do not include the ID. This allows adding it if that is the case
		feagi_dictionary["cortical_id"] = override_cortical_ID
	var type: BaseCorticalArea.CORTICAL_AREA_TYPE = BaseCorticalArea.cortical_type_str_to_type(feagi_dictionary["cortical_group"])
	var subtype: StringName = feagi_dictionary["cortical_sub_group"]
	if type == BaseCorticalArea.CORTICAL_AREA_TYPE.CUSTOM and subtype == "MEMORY":
		type = BaseCorticalArea.CORTICAL_AREA_TYPE.MEMORY
	var cortical_ID: StringName = feagi_dictionary["cortical_id"]
	var name: StringName = feagi_dictionary["cortical_name"]
	var visibility: bool = true
	if "visible" in feagi_dictionary.keys():
		visibility = feagi_dictionary["visible"]
	var dimensions: Vector3i = FEAGIUtils.array_to_vector3i(feagi_dictionary["cortical_dimensions"])
	var position_3D: Vector3i = FEAGIUtils.array_to_vector3i(feagi_dictionary["coordinates_3d"])
	var position_2D: Vector2i = Vector2i(0,0)
	var position_2D_defined: bool = false
	if "coordinates_2d" in feagi_dictionary.keys():
		position_2D_defined = feagi_dictionary["coordinates_2d"][0] != null
		if position_2D_defined:
			position_2D =  FEAGIUtils.array_to_vector2i(feagi_dictionary["coordinates_2d"])

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
			push_error("FEAGI CACHE: Unable to spawn cortical area of unknown type! Skipping!")

## Updates a cortical area by ID and emits a signal that this was done. Should only be called from FEAGI!
func update_cortical_area_from_dict(all_cortical_area_properties: Dictionary) -> void:
	if "cortical_id" not in all_cortical_area_properties.keys():
		push_error("No Cortical Area ID defined in input Dict to update! Skipping!")
		return
	
	if all_cortical_area_properties["cortical_id"] not in _available_cortical_areas.keys():
		push_error("No Cortical Area by ID of %s to update! Skipping!" % all_cortical_area_properties["cortical_id"])
		return
	
	var changing_ID: StringName = all_cortical_area_properties["cortical_id"]
	
	_available_cortical_areas[changing_ID].FEAGI_apply_full_dictionary(all_cortical_area_properties)
	cortical_area_mass_updated.emit(_available_cortical_areas[changing_ID])

## Removes a cortical area by ID and emits a signal that this was done. Should only be called from FEAGI!
func remove_cortical_area(removed_cortical_ID: StringName) -> void:
	if removed_cortical_ID not in _available_cortical_areas.keys():
		push_error("Attempted to remove cortical area " + removed_cortical_ID + " when already non existant in cache")
		return
	_available_cortical_areas[removed_cortical_ID].FEAGI_delete_cortical_area()
	cortical_area_about_to_be_removed.emit(_available_cortical_areas[removed_cortical_ID])
	print("FEAGI CACHE: Removing cortical area %s" % removed_cortical_ID)
	_available_cortical_areas.erase(removed_cortical_ID)
	
#endregion

#region filtering
## Returns an array of cortical areas whose name contains a given substring
## WARNING: Do NOT use this for backend data operations, this is better suited for UI name filtering operations
func search_for_available_cortical_areas_by_name(search_term: StringName) -> Array[BaseCorticalArea]:
	var lowercase_search: StringName = search_term.to_lower()
	var output: Array[BaseCorticalArea] = []
	for cortical_area in _available_cortical_areas.values():
		if cortical_area.name.to_lower().contains(lowercase_search):
			output.append(cortical_area)
	return output

## Returns an array of cortical areas of given cortical type
func search_for_available_cortical_areas_by_type(searching_cortical_type: BaseCorticalArea.CORTICAL_AREA_TYPE) -> Array[BaseCorticalArea]:
	var output: Array[BaseCorticalArea] = []
	for cortical_area in _available_cortical_areas.values():
		if cortical_area.group == searching_cortical_type:
			output.append(cortical_area)
	return output

## Returns an array of all the names of the cortical areas
func get_all_cortical_area_names() -> Array[StringName]:
	var output: Array[StringName] = []
	for cortical_area in _available_cortical_areas.values():
		output.append(cortical_area.cortical_ID)
	return output
#endregion

#region Mass Operations
## Goes over a dictionary of cortical areas and adds / removes the cached listing as needed. Should only be called from FEAGI
func update_cortical_area_cache_from_summary(_new_listing_with_summaries: Dictionary) -> void:
	print("FEAGI CACHE: Replacing cortical areas cache...")
	#TODO edit cortical areas?
	# TODO: Possible optimizations used packedStringArrays and less duplications
	var new_listing: Array[StringName] = []
	new_listing.assign(_new_listing_with_summaries.keys())
	var removed: Array[StringName] = []
	removed.assign(_available_cortical_areas.keys().duplicate())
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
		new_area_summary["cortical_id"] = add
		add_cortical_area_from_dict(new_area_summary)


## Applies mass update of 2d locations to cortical areas. Only call from FEAGI
func FEAGI_mass_update_2D_positions(IDs_to_locations: Dictionary) -> void:
	for cortical_ID in IDs_to_locations.keys():
		if !(cortical_ID in _available_cortical_areas.keys()):
			push_error("Unable to update position of %s due to this cortical area missing in cache" % cortical_ID)
			continue
		_available_cortical_areas[cortical_ID].coordinates_2D = IDs_to_locations[cortical_ID]

## Removes all cached cortical areas (and their connections). Should only be called during a reset
func hard_wipe_available_cortical_areas():
	print("CACHE: Wiping cortical areas and connections...")
	var all_cortical_area_IDs: Array = _available_cortical_areas.keys()
	for cortical_area_ID in all_cortical_area_IDs:
		remove_cortical_area(cortical_area_ID)
	print("CACHE: Wiping cortical areas and connection wipe complete!")
#endregion

#region queries
## Returns true if a cortical area exists with a given name (NOT ID)
func exist_cortical_area_of_name(searching_name: StringName) -> bool:
	for cortical_area in _available_cortical_areas.values():
		if cortical_area.name.to_lower().contains(searching_name.to_lower()):
			return true
	return false
#endregion

#region Internal

func _mapping_updated(mapping_properties: MappingProperties) -> void:
	cortical_area_mappings_changed.emit(mapping_properties.source_cortical_area, mapping_properties.destination_cortical_area)



#endregion

