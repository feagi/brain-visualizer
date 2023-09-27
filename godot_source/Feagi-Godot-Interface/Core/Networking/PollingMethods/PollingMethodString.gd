extends PollingMethodInterface
class_name PollingMethodString
## Waits until a certain string is returned

var _searching_string: StringName

func _init(searching_string: StringName) -> void:
    _searching_string = searching_string

func confirm_complete(response_body: PackedByteArray) -> bool:
    var string: StringName = response_body.get_string_from_utf8()
    return string == _searching_string


