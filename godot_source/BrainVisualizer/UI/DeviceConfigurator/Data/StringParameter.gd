extends AbstractParameter
class_name StringParameter

@export var value: StringName

func _init() -> void:
	value_type = TYPE_STRING

## Creates the instance of the object given the JSON dict
static func create_from_template_JSON_dict(JSON_dict: Dictionary) -> StringParameter:
	var output: StringParameter = StringParameter.new()
	output.fill_in_metadata_from_template_JSON_dict(JSON_dict)
	return output

func _get_value_as_JSON() -> Variant:
	return value
