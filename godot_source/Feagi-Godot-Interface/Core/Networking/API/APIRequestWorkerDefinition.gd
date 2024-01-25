extends Object
class_name APIRequestWorkerDefinition
## A set of instructions for [APIRequestWorker]


var full_address: StringName ## Full web address to call
var method: HTTPClient.Method ## HTTP method to use
var data_to_send_to_FEAGI: Variant ## Data (to be JSONified) to send to FEAGI. Used in POST and PUT requests
var data_to_hold_for_follow_up_function: Variant ## Data to hold on to for the follow_up_function to have access to at the end of the call
var should_kill_on_genome_reset: bool ## If the worker should stop on a genome reset regardless of what step it was on
var call_type: APIRequestWorker.CALL_PROCESS_TYPE ## Enum designating the type of call this is
var follow_up_function: Callable ## Godot function to call at the conclusion of this calls work (be it a single call or ending of a polling call). Must accept an int response code, a PackedByteArray response body, and an additional variant data variable
var mid_poll_function: Callable ## Same as above, but only applicable for polling calls, the function to run when a poll call was complete but the conditions to end polling have not been met
var polling_completion_check: PollingMethodInterface ## For polling calls, object used to check if we should stop polling
var seconds_between_polls: float ## Time (seconds) to wait between poll attempts

func _init() -> void:
	## Dont create an instance of this object with new(), instead use one of the below static factories
	pass

## Simple constructor for a simple single GET request
static func define_single_GET_call(
	define_full_address: StringName,
	define_follow_up_function: Callable,
	define_should_kill_on_genome_reset: bool = true
	) -> APIRequestWorkerDefinition:
		
		var output = APIRequestWorkerDefinition.new()
		output.full_address = define_full_address
		output.follow_up_function = define_follow_up_function
		output.should_kill_on_genome_reset = define_should_kill_on_genome_reset
		output.method = HTTPClient.Method.METHOD_GET
		output.data_to_send_to_FEAGI = null
		output.data_to_hold_for_follow_up_function = null
		output.call_type = APIRequestWorker.CALL_PROCESS_TYPE.SINGLE
		return output

## In-depth constructor for single calls
static func define_single_call(
	define_full_address: StringName,
	define_method: HTTPClient.Method,
	define_data_to_send_to_FEAGI: Variant,
	define_data_to_hold_for_follow_up_function: Variant,
	define_follow_up_function: Callable,
	define_should_kill_on_genome_reset: bool = true
	) -> APIRequestWorkerDefinition:
	
		var output = APIRequestWorkerDefinition.new()
		output.method = define_method
		output.full_address = define_full_address
		output.data_to_send_to_FEAGI = define_data_to_send_to_FEAGI
		output.data_to_hold_for_follow_up_function = define_data_to_hold_for_follow_up_function
		output.follow_up_function = define_follow_up_function
		output.should_kill_on_genome_reset = define_should_kill_on_genome_reset
		output.call_type = APIRequestWorker.CALL_PROCESS_TYPE.SINGLE
		return output

## Constructor for polling calls. Default 'define_polling_completion_check' is set to poll forever. Default 'define_mid_poll_function' is Callable() (Invalid, IE no mid poll function)
static func define_polling_call(
	define_full_address: StringName,
	define_method: HTTPClient.Method,
	define_data_to_send_to_FEAGI: Variant,
	define_data_to_hold_for_follow_up_function: Variant,
	define_follow_up_function: Callable,
	define_seconds_between_polls: float, 
	define_polling_completion_check: PollingMethodInterface = PollingMethodNone.new(PollingMethodInterface.POLLING_CONFIRMATION.INCOMPLETE),
	define_mid_poll_function: Callable = Callable(), 
	define_should_kill_on_genome_reset: bool = true
	) -> APIRequestWorkerDefinition:
	
		var output = APIRequestWorkerDefinition.new()
		output.method = define_method
		output.full_address = define_full_address
		output.data_to_send_to_FEAGI = define_data_to_send_to_FEAGI
		output.data_to_hold_for_follow_up_function = define_data_to_hold_for_follow_up_function
		output.follow_up_function = define_follow_up_function
		output.should_kill_on_genome_reset = define_should_kill_on_genome_reset
		output.mid_poll_function = define_mid_poll_function
		output.polling_completion_check = define_polling_completion_check
		output.seconds_between_polls = define_seconds_between_polls
		output.call_type = APIRequestWorker.CALL_PROCESS_TYPE.POLLING
		return output
