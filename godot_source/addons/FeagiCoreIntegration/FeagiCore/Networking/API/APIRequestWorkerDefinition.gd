extends RefCounted
class_name APIRequestWorkerDefinition
## A set of instructions for [APIRequestWorker]

# Often Required
var full_address: StringName ## Full web address to call
var method: HTTPClient.Method ## HTTP method to use
var data_to_send_to_FEAGI: Variant = null## Data (to be JSONified) to send to FEAGI. Used in POST and PUT requests
var data_to_hold_for_follow_up_function: Variant = null ## Data to hold on to for the follow_up_function to have access to at the end of the call
var follow_up_function: Callable ## Godot function to call at the conclusion of this calls work (be it a single call or ending of a polling call). Must accept an int response code, a PackedByteArray response body, and an additional variant data variable
var http_error_replacements: Dictionary ## keys mapped to text replacements for any text to replace in an error (key being target minus $, value being replacement) during generic error handling

# Often required for polling
var polling_completion_check: BasePollingMethod ## For polling calls, object used to check if we should stop polling

# Optional, and to be seperately set. Otherwise these defaults are used
var mid_poll_function: Callable = Callable() ## Same as follow_up_function, but optional and only applicable for polling calls, the function to run when a poll call was complete but the conditions to end polling have not been met
var seconds_between_polls: float = 5.0## Time (seconds) to wait between poll attempts
var http_error_call: Callable = Callable() ## Custom Godot function to call if FEAGI responded with an error. The call should accept the PackedByteArray from the return body then this object
var http_unresponsive_call: Callable = Callable() ## Custom Godot function to call if FEAGI responded with an error. The call should accept this object
var http_timeout: float = 10.0 ## How many seconds to wait before declaring a call as timed out and FEAGI unresponsive
# Internal
var call_type: APIRequestWorker.CALL_PROCESS_TYPE ## Enum designating the type of call this is

func _init() -> void:
	## Dont create an instance of this object with new(), instead use one of the below static factories
	pass

## Simple constructor for a simple single GET request
static func define_single_GET_call(
	define_full_address: StringName,
	define_follow_up_function: Callable,
	error_replacement = {}
	) -> APIRequestWorkerDefinition:
		
		var output = APIRequestWorkerDefinition.new()
		output.full_address = define_full_address
		output.follow_up_function = define_follow_up_function
		output.http_error_replacements = error_replacement
		output.method = HTTPClient.Method.METHOD_GET
		output.call_type = APIRequestWorker.CALL_PROCESS_TYPE.SINGLE
		return output

## In-depth constructor for single calls
static func define_single_call(
	define_full_address: StringName,
	define_follow_up_function: Callable,
	define_method: HTTPClient.Method,
	define_data_to_send_to_FEAGI: Variant,
	define_data_to_hold_for_follow_up_function: Variant,
	error_replacement = {},
	) -> APIRequestWorkerDefinition:
	
		var output = APIRequestWorkerDefinition.new()
		output.method = define_method
		output.full_address = define_full_address
		output.data_to_send_to_FEAGI = define_data_to_send_to_FEAGI
		output.data_to_hold_for_follow_up_function = define_data_to_hold_for_follow_up_function
		output.follow_up_function = define_follow_up_function
		output.call_type = APIRequestWorker.CALL_PROCESS_TYPE.SINGLE
		output.http_error_replacements = error_replacement
		return output

## Constructor for polling calls. Default 'define_polling_completion_check' is set to poll forever. Default 'define_mid_poll_function' is Callable() (Invalid, IE no mid poll function)
static func define_polling_call(
	define_full_address: StringName,
	define_method: HTTPClient.Method,
	define_data_to_send_to_FEAGI: Variant,
	define_data_to_hold_for_follow_up_function: Variant,
	define_follow_up_function: Callable,
	define_polling_completion_check: BasePollingMethod = PollingMethodNone.new(BasePollingMethod.POLLING_CONFIRMATION.INCOMPLETE),
	error_replacement = {},
	) -> APIRequestWorkerDefinition:
	
		var output = APIRequestWorkerDefinition.new()
		output.method = define_method
		output.full_address = define_full_address
		output.data_to_send_to_FEAGI = define_data_to_send_to_FEAGI
		output.data_to_hold_for_follow_up_function = define_data_to_hold_for_follow_up_function
		output.follow_up_function = define_follow_up_function
		output.polling_completion_check = define_polling_completion_check
		output.call_type = APIRequestWorker.CALL_PROCESS_TYPE.POLLING
		output.http_error_replacements = error_replacement
		return output
