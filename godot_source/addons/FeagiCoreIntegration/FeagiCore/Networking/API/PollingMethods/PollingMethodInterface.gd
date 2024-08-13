extends RefCounted
class_name BasePollingMethod
## More or less an interface for PollingMethod objects
## What do we need from the network call response body to confirm completion?

## Return of the confirmation, if polling is complete (stop), incomplete (needs to continue), or error'd (stop with special logic)
enum POLLING_CONFIRMATION {
	COMPLETE,
	INCOMPLETE,
	ERROR
}

func confirm_complete(_response_code: int, _response_body: PackedByteArray) -> POLLING_CONFIRMATION:
	push_error("Do not use PollingMethodInterface directly, use one of its children")
	return POLLING_CONFIRMATION.ERROR




