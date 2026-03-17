extends AbstractParameter
class_name EnumParameter
## Represents a fixed set of allowed string options.

@export var options: Array[StringName] = []
@export var value: StringName

func _init() -> void:
	value_type = TYPE_STRING

## Creates the instance of the object given the JSON dict.
static func create_from_template_JSON_dict(JSON_dict: Dictionary) -> EnumParameter:
	var output: EnumParameter = EnumParameter.new()
	output.fill_in_metadata_from_template_JSON_dict(JSON_dict)
	if "options" in JSON_dict:
		output.options = JSON_dict["options"]
	if "default" in JSON_dict:
		output.value = JSON_dict["default"]
	return output

## Returns the value of the object in a format that can be written in JSON.
func _get_value_as_JSON() -> Variant:
	return value
