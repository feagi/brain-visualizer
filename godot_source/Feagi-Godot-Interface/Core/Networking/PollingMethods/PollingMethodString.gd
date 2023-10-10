extends PollingMethodInterface
class_name PollingMethodString
## Waits until a certain string is returned

var _searching_string: StringName

func _init(searching_string: StringName) -> void:
    _searching_string = searching_string

func confirm_complete(response_code: int, response_body: PackedByteArray) -> POLLING_CONFIRMATION:
    if response_code != 200:
        return POLLING_CONFIRMATION.ERROR
    var string: StringName = response_body.get_string_from_utf8()
    if string == _searching_string:
        return POLLING_CONFIRMATION.COMPLETE
    return POLLING_CONFIRMATION.INCOMPLETE


