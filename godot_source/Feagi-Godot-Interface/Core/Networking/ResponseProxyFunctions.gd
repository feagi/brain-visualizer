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

func GET_GE_CorticalArea_geometry(_response_code: int, response_body: PackedByteArray, _irrelevant_data: Variant) -> void:
    var cortical_area_summary: Dictionary = _body_to_dictionary(response_body)
    


func _body_to_string_array(response_body: PackedByteArray) -> PackedStringArray:
    return JSON.parse_string(response_body.get_string_from_utf8())

func _body_to_dictionary(response_body: PackedByteArray) -> Dictionary:
    return JSON.parse_string(response_body.get_string_from_utf8())