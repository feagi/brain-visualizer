extends PollingMethodInterface
class_name PollingMethodNone
## Use to skip polling or keep polling forever

var _output_bool: bool

func _init(output_bool: bool) -> void:
	_output_bool = output_bool

## Can't get easier than this
func confirm_complete(_response_code: int, _response_body: PackedByteArray) -> bool:
	return _output_bool

func external_toggle_polling() -> void:
	_output_bool = !_output_bool
