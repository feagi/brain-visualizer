extends RefCounted
class_name APIRequestWorkerDefinition
## A set of instructions for [APIRequestWorker]

# Often Required
var full_address: StringName ## Full web address to call
var method: HTTPClient.Method ## HTTP method to use
var data_to_send_to_FEAGI: Variant = null## Data (to be JSONified) to send to FEAGI. Used in POST and PUT requests

# Often required for polling
var polling_completion_check: BasePollingMethod ## For polling calls, object used to check if we should stop polling

# Optional, and to be seperately set. Otherwise these defaults are used
var mid_poll_function: Callable = Callable() ## Same as follow_up_function, but optional and only applicable for polling calls, the function to run when a poll call was complete but the conditions to end polling have not been met
var seconds_between_polls: float = 5.0## Time (seconds) to wait between poll attempts
var http_timeout: float = 10.0 ## How many seconds to wait before declaring a call as timed out and FEAGI unresponsive
# Internal
var call_type: APIRequestWorker.CALL_PROCESS_TYPE ## Enum designating the type of call this is

## Simple constructor for a simple single GET request
static func define_single_GET_call(
	define_full_address: StringName,
	) -> APIRequestWorkerDefinition:
		var output = APIRequestWorkerDefinition.new()
		output.full_address = define_full_address
		output.method = HTTPClient.Method.METHOD_GET
		output.call_type = APIRequestWorker.CALL_PROCESS_TYPE.SINGLE
		return output

## In-depth constructor for single calls
static func define_single_call(
	define_full_address: StringName,
	define_method: HTTPClient.Method,
	define_data_to_send_to_FEAGI: Variant,
	) -> APIRequestWorkerDefinition:
	
		var output = APIRequestWorkerDefinition.new()
		output.method = define_method
		output.full_address = define_full_address
		output.data_to_send_to_FEAGI = define_data_to_send_to_FEAGI
		output.call_type = APIRequestWorker.CALL_PROCESS_TYPE.SINGLE
		return output

## Constructor for polling calls. Default 'define_polling_completion_check' is set to poll forever. Default 'define_mid_poll_function' is Callable() (Invalid, IE no mid poll function)
static func define_polling_call(
	define_full_address: StringName,
	define_method: HTTPClient.Method,
	define_data_to_send_to_FEAGI: Variant,
	define_polling_completion_check: BasePollingMethod = PollingMethodNone.new(BasePollingMethod.POLLING_CONFIRMATION.INCOMPLETE),
	) -> APIRequestWorkerDefinition:
	
		var output = APIRequestWorkerDefinition.new()
		output.method = define_method
		output.full_address = define_full_address
		output.data_to_send_to_FEAGI = define_data_to_send_to_FEAGI
		output.polling_completion_check = define_polling_completion_check
		output.call_type = APIRequestWorker.CALL_PROCESS_TYPE.POLLING
		return output
