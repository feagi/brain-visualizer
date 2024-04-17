extends BasePollingMethod
class_name PollingMethodDictionaryValue
# Waits until a dictionary witha  specific key exisits with a specific value

var _searching_key: StringName
var _searching_value: Variant  ## Be careful that this is of the same type that you expect out of a json

func _init(searching_key: StringName, searching_value: Variant) -> void:
	_searching_key = searching_key
	_searching_value = searching_value

func confirm_complete(response_code: int, response_body: PackedByteArray) -> POLLING_CONFIRMATION:
	var dictionary: Dictionary = JSON.parse_string(response_body.get_string_from_utf8())
	if _searching_key not in dictionary.keys(): 
		return POLLING_CONFIRMATION.INCOMPLETE
	if dictionary[_searching_key] == _searching_value:
		return POLLING_CONFIRMATION.COMPLETE
	return POLLING_CONFIRMATION.INCOMPLETE
	
