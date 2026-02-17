extends AbstractParameter
class_name IntegerParameter

const NAN_EQUIVILANT_FOR_INT: int = -9929731 # treating this as NAN for comparisons. Yes this is stupid practice. Hopefully this number never occurs in our work

@export var value: int = NAN_EQUIVILANT_FOR_INT
@export var default: int = 0
@export var minimum: int = 0
@export var maximum: int = 100

func _init() -> void:
	value_type = TYPE_INT

## Creates the instance of the object given the JSON dict
static func create_from_template_JSON_dict(JSON_dict: Dictionary) -> IntegerParameter:
	var output: IntegerParameter = IntegerParameter.new()
	output.fill_in_metadata_from_template_JSON_dict(JSON_dict)
	if "default" in JSON_dict:
		output.default = JSON_dict["default"]
	if "minimum" in JSON_dict:
		output.default = JSON_dict["minimum"]
	if "maximum" in JSON_dict:
		output.default = JSON_dict["maximum"]
	return output

func _get_value_as_JSON() -> Variant:
	return value
