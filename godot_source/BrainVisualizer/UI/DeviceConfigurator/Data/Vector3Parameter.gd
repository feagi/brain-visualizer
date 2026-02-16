extends AbstractParameter
class_name Vector3Parameter

@export var value: Vector3 = Vector3(IntegerParameter.NAN_EQUIVILANT_FOR_INT, IntegerParameter.NAN_EQUIVILANT_FOR_INT, IntegerParameter.NAN_EQUIVILANT_FOR_INT)
@export var default: Vector3 = Vector3(0, 0, 0)

func _init() -> void:
	value_type = TYPE_ARRAY # the type in the json is an array

## Creates the instance of the object given the JSON dict
static func create_from_template_JSON_dict(JSON_dict: Dictionary) -> Vector3Parameter:
	var output: Vector3Parameter = Vector3Parameter.new()
	output.fill_in_metadata_from_template_JSON_dict(JSON_dict)
	if "default" in JSON_dict:
		var arr = JSON_dict["default"]
		if arr is not Array:
			push_error("Invalid default Vector3 for component %s! Unknown type!" % output.label)
		elif len(arr) != 3:
			push_error("Invalid default Vector3 for component %s! Not 3 elements long!" % output.label)
		else:
			output.value = Vector3(arr[0], arr[1], arr[2])
	return output

func _get_value_as_JSON() -> Variant:
	return [value.x, value.y, value.z]
