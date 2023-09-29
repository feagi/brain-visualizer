extends PollingMethodInterface
class_name PollingMethodDictionaryValue
# Waits until a dictionary witha  specific key exisits witha  specific value

var _searching_key: StringName
var _searching_value: Variant  ## Be careful that this is of the same type that you expect out of a json

func _init(searching_key: StringName, searching_value: Variant) -> void:
    _searching_key = searching_key
    _searching_value = searching_value

func confirm_complete(_response_code: int, response_body: PackedByteArray) -> bool:
    var dictionary: Dictionary = JSON.parse_string(response_body.get_string_from_utf8())
    if _searching_key not in dictionary.keys(): 
        return false
    return dictionary[_searching_key] == _searching_value
    


