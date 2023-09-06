extends Object
class_name ResponseProxyFunctions
## All responses from FEAGI calls go through these calls


# UNUSED
### Get list of morphologies
#func GET_GE_morphologyList(_response_code: int, response_body: PackedByteArray, _irrelevant_data: Variant) -> void:
#    var morphology_list: PackedStringArray = _body_to_string_array(response_body)
#    print(morphology_list)




## returns dict of morphology names keyd to their type string
func GET_MO_list_types(_response_code: int, response_body: PackedByteArray, _irrelevant_data: Variant) -> void:
	var morphologies_and_types: Dictionary = _body_to_dictionary(response_body)
	FeagiCache.morphology_cache.update_morphology_cache_from_summary(morphologies_and_types)
	FeagiEvents.retrieved_latest_morphology_listing.emit(morphologies_and_types.keys())

## returns a dict of the mapping of cortical areas
func GET_GE_corticalMap(_response_code: int, response_body: PackedByteArray, _irrelevant_data: Variant) -> void:
	var cortical_map: Dictionary = _body_to_dictionary(response_body)
	for source_cortical_ID in cortical_map.keys():
		if cortical_map[source_cortical_ID] == {}:
			continue # no efferent connections for the current searching source cortical ID
		if source_cortical_ID not in FeagiCache.cortical_areas_cache.cortical_areas.keys():
			push_error("Retrieved mapping from nonexistant cortical area %s! Skipping!" % source_cortical_ID)
			continue
		
		# This function is not particuarly efficient. Too Bad!
		# no typing of these arrays due to type cast shenanigans. Be careful!
		var source_area: CorticalArea = FeagiCache.cortical_areas_cache.cortical_areas[source_cortical_ID]
		var connections_requested: Array = cortical_map[source_cortical_ID].keys()
		var efferent_connections_already_set: Array = source_area.efferent_connections_with_count.keys()
		var efferents_to_add: Array = FEAGIUtils.find_missing_elements(connections_requested, efferent_connections_already_set)
		var efferents_to_remove: Array = FEAGIUtils.find_missing_elements(efferent_connections_already_set, connections_requested)
		var efferents_to_update: Array = FEAGIUtils.find_union(efferent_connections_already_set, connections_requested)
		

		for add_ID in efferents_to_add:
			source_area.set_efferent_connection(FeagiCache.cortical_areas_cache.cortical_areas[add_ID], cortical_map[source_cortical_ID][add_ID])
		
		for remove_ID in efferents_to_remove:
			source_area.remove_efferent_connection(FeagiCache.cortical_areas_cache.cortical_areas[remove_ID])

		for check_ID in efferents_to_update:
			source_area.set_efferent_connection(FeagiCache.cortical_areas_cache.cortical_areas[check_ID], cortical_map[source_cortical_ID][check_ID])

## returns a dict of all the properties of a specific cortical area, then triggers a cache update for it
func GET_GE_corticalArea(_response_code: int, response_body: PackedByteArray, _irrelevant_data: Variant) -> void:
	if _response_code == 422:
		push_error("Unable to retrieve cortical area information! Skipping!")
		return
	var cortical_area_properties: Dictionary = _body_to_dictionary(response_body)
	print("Recieved from FEAGI latest cortical info for " + cortical_area_properties["cortical_id"])
	FeagiCache.cortical_areas_cache.update_cortical_area_from_dict(cortical_area_properties)


func GET_GE_CorticalArea_geometry(_response_code: int, response_body: PackedByteArray, _irrelevant_data: Variant) -> void:
	var cortical_area_summary: Dictionary = _body_to_dictionary(response_body)
	FeagiCache.cortical_areas_cache.update_cortical_area_cache_from_summary(cortical_area_summary)
	FeagiRequests.refresh_connection_list()

func GET_GE_circuits(_response_code: int, response_body: PackedByteArray, _irrelevant_data: Variant) -> void:
	FeagiCache.available_circuits = _body_to_string_array(response_body)

func GET_GE_circuitsize(_response_code: int, response_body: PackedByteArray, circuit_name: StringName) -> void:
	var size_array: Array[int] = FEAGIUtils.untyped_array_to_int_array(_body_to_untyped_array(response_body))
	FeagiEvents.retrieved_circuit_size.emit(circuit_name, FEAGIUtils.array_to_vector3i(size_array))
	
func GET_GE_mappingProperties(_response_code: int, response_body: PackedByteArray, source_destination_ID_str: Array) -> void:
	if source_destination_ID_str[0] not in FeagiCache.cortical_areas_cache.cortical_areas.keys() or source_destination_ID_str[1] not in FeagiCache.cortical_areas_cache.cortical_areas.keys():
		# This is INCREDIBLY unlikely, but the cortical area referenced by the mapping was deleted right before we got this response back
		push_error("Retrieved cortical mapping refers to a cortical area no longer in the cache! Skipping!")
		return
	var raw_mapping_properties: Array = _body_to_untyped_array(response_body)
	var source_area: CorticalArea =  FeagiCache.cortical_areas_cache.cortical_areas[source_destination_ID_str[0]]
	var destination_area: CorticalArea =  FeagiCache.cortical_areas_cache.cortical_areas[source_destination_ID_str[1]]
	source_area.set_efferent_mapping_properties_from_FEAGI(raw_mapping_properties, destination_area)

func GET_GE_morphologyUsage(Usage_response_code: int, response_body: PackedByteArray, _irrelevant_data: Variant) -> void:
	var morphology_usuage = response_body.get_string_from_utf8() #TODO this should be outputting an array, not a string. Leaving for now due to time constraints but this needs to be fixed + morphology manager updated to use an array
	FeagiEvents.retrieved_latest_usuage_of_morphology.emit(morphology_usuage)

func GET_GE_morphology(_response_code: int, response_body: PackedByteArray, _irrelevant_data: Variant) -> void:
	if _response_code == 404:
		push_error("FEAGI was unable to find the requested morphology details. Skipping!")
		return
	var morphology_dict: Dictionary = _body_to_dictionary(response_body)
	FeagiCache.morphology_cache.update_morphology_by_dict(morphology_dict)

func GET_BU_stimulationPeriod(_response_code: int, response_body: PackedByteArray, _irrelevant_data: Variant) -> void:
	FeagiCache.delay_between_bursts = _body_to_float(response_body)

func POST_GE_customCorticalArea(_response_code: int, response_body: PackedByteArray, other_properties: Dictionary) -> void:
	# returns a dict of cortical ID
	if _response_code == 422:
		push_error("Unable to process new custom cortical area dict, skipping!")
		return

	var cortical_ID_raw: Dictionary = _body_to_dictionary(response_body)

	if "cortical_id" not in cortical_ID_raw.keys():
		push_error("FEAGI did not respond with a cortical ID when trying to generate a custom cortical area, something likely went wrong")
		return

	var is_2D_coordinates_defined: bool = false
	var coordinates_2D: Vector2 = Vector2(0,0)
	if cortical_ID_raw['cortical_id'] != null:
		if "coordinates_2d" in other_properties.keys():
			is_2D_coordinates_defined = true
			coordinates_2D = other_properties["coordinates_2d"]
		
		FeagiCache.cortical_areas_cache.add_cortical_area(
			cortical_ID_raw["cortical_id"],
			other_properties["cortical_name"],
			other_properties["coordinates_3d"]	,
			other_properties["cortical_dimensions"],
			is_2D_coordinates_defined,
			coordinates_2D,
			other_properties["cortical_type"]
		)

func POST_FE_burstEngine(_response_code: int, _response_body: PackedByteArray, _irrelevant_data: Variant) -> void:
	# no real error handling from FEAGI right now, so we cannot do anything here
	pass

func POST_GE_morphology(_response_code: int, _response_body: PackedByteArray, requested_properties: Dictionary) -> void:
	if _response_code == 422:
		push_error("Unable to process add morphology %s, skipping!" % [requested_properties["morphology_name"]])
		return
	FeagiCache.morphology_cache.add_morphology_by_dict(requested_properties)
	

func PUT_GE_mappingProperties(_response_code: int, _response_body: PackedByteArray, src_dst_data: Dictionary) -> void:
	if _response_code == 422:
		push_error("Unable to process new mappings! Skipping!")
		return
	var cortical_src: CorticalArea = src_dst_data["src"]
	var cortical_dst: CorticalArea = src_dst_data["dst"]
	print("FEAGI sucessfully updated the mapping between %s and %s" % [cortical_src.cortical_ID, cortical_dst.cortical_ID])
	var mapping_count: int = src_dst_data["count"]
	if mapping_count == 0:
		# we removed the mapping
		cortical_src.remove_efferent_connection(cortical_dst)
		return
	# assume we add / modify the mapping
	cortical_src.set_efferent_connection(cortical_dst, mapping_count)



func PUT_GE_corticalArea(_response_code: int, _response_body: PackedByteArray, changed_cortical_ID: StringName) -> void:
	if _response_code == 422:
		push_error("Unable to process new properties for %s, skipping!" % [changed_cortical_ID])
		return
	
	# Property change accepted, pull latest details
	FeagiRequests.refresh_cortical_area(changed_cortical_ID)
	pass

## returns nothing, so we passthrough the deleted cortical ID
func DELETE_GE_corticalArea(_response_code: int, _response_body: PackedByteArray, deleted_cortical_ID: StringName) -> void:
	print("FEAGI confirmed deletion of cortical area " + deleted_cortical_ID)
	FeagiCache.cortical_areas_cache.remove_cortical_area(deleted_cortical_ID)

func DELETE_GE_morphology(_response_code: int, _response_body: PackedByteArray, deleted_morphology_name: StringName) -> void:
	print("FEAGI confirmed deletion of morphology " + deleted_morphology_name)
	FeagiCache.morphology_cache.remove_morphology(deleted_morphology_name)


func _body_to_untyped_array(response_body: PackedByteArray) -> Array:
	var data = response_body.get_string_from_utf8()
	return JSON.parse_string(data)

func _body_to_string_array(response_body: PackedByteArray) -> PackedStringArray:
	return JSON.parse_string(response_body.get_string_from_utf8())

func _body_to_dictionary(response_body: PackedByteArray) -> Dictionary:
	return JSON.parse_string(response_body.get_string_from_utf8())

func _body_to_float(response_body: PackedByteArray) -> float:
	return (str(response_body.get_string_from_utf8())).to_float()


