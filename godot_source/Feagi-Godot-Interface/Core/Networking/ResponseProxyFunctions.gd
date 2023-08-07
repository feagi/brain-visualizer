extends Object
class_name ResponseProxyFunctions


func GET_GE_morphologyList(_response_code: int, response_body: PackedByteArray, _irrelevant_data: Variant) -> void:
    var morphology_list: PackedStringArray = JSON.parse_string(response_body.get_string_from_utf8())
    print(morphology_list)
    pass




