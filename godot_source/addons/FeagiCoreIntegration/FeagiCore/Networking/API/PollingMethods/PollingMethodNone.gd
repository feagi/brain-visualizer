extends BasePollingMethod
class_name PollingMethodNone
## Use to skip polling or keep polling forever

var _output_result: POLLING_CONFIRMATION

func _init(output_result: POLLING_CONFIRMATION) -> void:
	_output_result = output_result

## Can't get easier than this
func confirm_complete(_response_code: int, _response_body: PackedByteArray) -> POLLING_CONFIRMATION:
	return _output_result

func external_toggle_polling() -> void:
	if _output_result == POLLING_CONFIRMATION.COMPLETE:
		_output_result = POLLING_CONFIRMATION.INCOMPLETE
	_output_result = POLLING_CONFIRMATION.COMPLETE
