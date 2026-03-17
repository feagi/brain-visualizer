extends AbstractParameter
class_name PercentageParameter

@export var value: int = IntegerParameter.NAN_EQUIVILANT_FOR_INT # out of 100
@export var default: int = 0
@export var minimum: int = 0
@export var maximum: int = 100

func _init() -> void:
	value_type = TYPE_INT # the type in JSON is an int

## Creates the instance of the object given the JSON dict
static func create_from_template_JSON_dict(JSON_dict: Dictionary) -> PercentageParameter:
	var output: PercentageParameter = PercentageParameter.new()
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
