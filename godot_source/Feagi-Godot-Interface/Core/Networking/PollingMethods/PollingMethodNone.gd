extends PollingMethodInterface
class_name PollingMethodNone
## Use for when there is no polling, immediately end the call

## Can't get easier than this
func confirm_complete(_response_code: int, _response_body: PackedByteArray) -> bool:
    return true