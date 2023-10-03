extends PollingMethodInterface
class_name PollingMethodNone
## Use for when there is no polling, immediately end the call with the init bool

var _output_bool: bool

func _init(output_bool: bool) -> void:
    _output_bool = output_bool

## Can't get easier than this
func confirm_complete(_response_code: int, _response_body: PackedByteArray) -> bool:
    return true