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
	var morpholgies_and_types: Dictionary = _body_to_dictionary(response_body)
	FeagiCache.morphology_cache.update_morphology_cache_from_summary(morpholgies_and_types)

## returns a dict of the mapping of cortical areas
func GET_GE_corticalMap(_response_code: int, response_body: PackedByteArray, _irrelevant_data: Variant) -> void:
	var cortical_map: Dictionary = _body_to_dictionary(response_body)
	FeagiCache.connections_cache.mass_set_connections(cortical_map)

## returns a dict of all the properties of a specific cortical area, then triggers a cache update for it
func GET_GE_corticalArea(_response_code: int, response_body: PackedByteArray, _irrelevant_data: Variant) -> void:
	var cortical_area_properties: Dictionary = _body_to_dictionary(response_body)
	FeagiCache.cortical_areas_cache.update_cortical_area_from_dict(cortical_area_properties)


func GET_GE_CorticalArea_geometry(_response_code: int, response_body: PackedByteArray, _irrelevant_data: Variant) -> void:
	var cortical_area_summary: Dictionary = _body_to_dictionary(response_body)
	FeagiCache.cortical_areas_cache.update_cortical_area_cache_from_summary(cortical_area_summary)
	FeagiRequests.refresh_connection_list()

func GET_GE_circuits(_response_code: int, response_body: PackedByteArray, _irrelevant_data: Variant) -> void:
	FeagiCache.available_circuits = _body_to_string_array(response_body)

func GET_BU_stimulationPeriod(_response_code: int, response_body: PackedByteArray, _irrelevant_data: Variant) -> void:
	FeagiCache.delay_between_bursts = _body_to_float(response_body)

func POST_GE_customCorticalArea(_response_code: int, response_body: PackedByteArray, other_properties: Dictionary) -> void:
	# returns a dict of cortical ID
	if _response_code == 422:
		push_error("Unable to process new custom cortical area dict, skipping!")
		return
	
	var cortical_ID_raw: Dictionary = _body_to_dictionary(response_body)
	var is_2D_coordinates_defined: bool = false
	var coordinates_2D: Vector2 = Vector2(0,0)
	if "coordinates_2d" in other_properties.keys():
		is_2D_coordinates_defined = true
		coordinates_2D = other_properties["coordinates_2d"]
	
	FeagiCache.cortical_areas_cache.add_cortical_area(
		cortical_ID_raw["cortical_id"],
		other_properties["cortical_name"],
		other_properties["coordinates_3d"],
		other_properties["cortical_dimensions"],
		is_2D_coordinates_defined,
		coordinates_2D,
		other_properties["cortical_type"]
	)

func POST_FE_burstEngine(_response_code: int, _response_body: PackedByteArray, _irrelevant_data: Variant) -> void:
	# no real error handling from FEAGI right now, so we cannot do anything here
	pass

func PUT_GE_mappingProperties(_response_code: int, _response_body: PackedByteArray, _irrelevant_data: Variant) -> void:
	pass

func PUT_GE_corticalArea(_response_code: int, _response_body: PackedByteArray, changed_cortical_ID: StringName) -> void:
	if _response_code == 422:
		push_error("Unable to process new properties for %s, skipping!" % [changed_cortical_ID])
		return
	
	# Property change accepted, pull latest details
	FeagiRequests.refresh_cortical_area(changed_cortical_ID)
	pass

## returns nothing, so we passthrough the deleted cortical ID
func DELETE_GE_corticalArea(_response_code: int, _response_body: PackedByteArray, deleted_cortical_ID: StringName) -> void:
	FeagiCache.connections_cache.cortical_area_deleted(deleted_cortical_ID)
	FeagiCache.cortical_areas_cache.remove_cortical_area(deleted_cortical_ID)






func _body_to_string_array(response_body: PackedByteArray) -> PackedStringArray:
	return JSON.parse_string(response_body.get_string_from_utf8())

func _body_to_dictionary(response_body: PackedByteArray) -> Dictionary:
	return JSON.parse_string(response_body.get_string_from_utf8())

func _body_to_float(response_body: PackedByteArray) -> float:
	return (str(response_body.get_string_from_utf8())).to_float()
