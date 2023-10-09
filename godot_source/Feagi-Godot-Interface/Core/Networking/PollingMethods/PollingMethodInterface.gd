extends Object
class_name PollingMethodInterface
## More or less an interface for PollingMethod objects
## What do we need from the network call response body to confirm completion?

func confirm_complete(_response_code: int, _response_body: PackedByteArray) -> bool:
    push_error("Do not use PollingMethodInterface directly, use one of its children")
    return true




