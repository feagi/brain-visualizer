extends AbstractParameter
class_name BooleanParameter

@export var value: bool = false
@export var default: bool = false

func _init() -> void:
	value_type = TYPE_BOOL

## Creates the instance of the object given the JSON dict
static func create_from_template_JSON_dict(JSON_dict: Dictionary) -> BooleanParameter:
	var output: BooleanParameter = BooleanParameter.new()
	output.fill_in_metadata_from_template_JSON_dict(JSON_dict)
	if "default" in JSON_dict:
		output.default = JSON_dict["default"]
	return output
	
func _get_value_as_JSON() -> Variant:
	return value
