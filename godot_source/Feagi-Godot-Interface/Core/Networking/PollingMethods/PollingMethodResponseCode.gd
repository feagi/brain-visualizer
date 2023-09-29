extends PollingMethodInterface
class_name PollingMethodResponseCode
## Use for when we want to check the response code

var _searching_value: int

func _init(searching_value: int) -> void:
    _searching_value = searching_value

func confirm_complete(response_code: int, _response_body: PackedByteArray) -> bool:
    return response_code == _searching_value