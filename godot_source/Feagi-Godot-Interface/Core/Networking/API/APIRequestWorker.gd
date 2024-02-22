extends HTTPRequest
class_name  APIRequestWorker
## GET/POST/PUT/DELETE worker for [NetworkInterface]
##
## On initialization, toggles multiThreading, sets internals, and parents itself to a given parent (this does not need to be done seperately)
## Sits idle but when given a network call, will run it then return the output to the given relay function._add_constant_central_force
## After this point, will return to the queue in [NetworkInterface] if there is enough room, otherwise will destroy itself
##

enum CALL_PROCESS_TYPE {
	SINGLE,
	POLLING
}

var _network_interface_ref: NetworkInterface
var _timer: Timer

var _full_address: StringName ## Full web address to call
var _method: HTTPClient.Method ## HTTP method to use
var _data_to_send_to_FEAGI: Variant ## Data (to be JSONified) to send to FEAGI. Used in POST and PUT requests
var _data_to_hold_for_follow_up_function: Variant ## Data to hold on to for the follow_up_function to have access to at the end of the call
var _should_kill_on_genome_reset: bool ## If the worker should stop on a genome reset regardless of what step it was on
var _call_type: APIRequestWorker.CALL_PROCESS_TYPE ## Enum designating the type of call this is
var _follow_up_function: Callable ## Godot function to call at the conclusion of this calls work (be it a single call or ending of a polling call). Must accept an int response code, a PackedByteArray response body, and an additional variant data variable
var _mid_poll_function: Callable ## Same as above, but only applicable for polling calls, the function to run when a poll call was complete but the conditions to end polling have not been met
var _polling_completion_check: PollingMethodInterface ## For polling calls, object used to check if we should stop polling
var _seconds_between_polls: float ## Time (seconds) to wait between poll attempts
var _http_error_call: Callable ## Custom Godot function to call if FEAGI returns a 400 or 500. Can be left empty for no custom action
var _http_error_replacements: Dictionary ## keys mapped to text replacements for any text to replace in an error (key being target minus $, value being replacement)



var _outgoing_headers: PackedStringArray # headers to make requests with
var _processing_type: CALL_PROCESS_TYPE

## Sets up this node with all prereqs, should only be called once on instantiation
func initialization(interface: NetworkInterface, call_header: PackedStringArray, node_parent: Node) -> void:
	FeagiEvents.genome_is_about_to_reset.connect(_brain_visualizer_resetting)
	request_completed.connect(_call_complete)
	_network_interface_ref = interface
	_timer = $Timer
	_timer.timeout.connect(_poll_call_from_timer)
	_outgoing_headers = call_header
	node_parent.add_child(self)
	name = "New"

## Setup and execute the worker as per the request definition
func setup_and_run_from_definition(request_definition: APIRequestWorkerDefinition) -> void:	
	_method = _method
	_full_address = request_definition.full_address
	_data_to_send_to_FEAGI = request_definition.data_to_send_to_FEAGI
	_data_to_hold_for_follow_up_function = request_definition.data_to_hold_for_follow_up_function
	_follow_up_function = request_definition.follow_up_function
	_should_kill_on_genome_reset = request_definition.should_kill_on_genome_reset
	_mid_poll_function = request_definition.mid_poll_function
	_polling_completion_check = request_definition.polling_completion_check
	_seconds_between_polls = request_definition.seconds_between_polls
	_call_type = request_definition.call_type
	_http_error_replacements = request_definition.http_error_replacements
	_http_error_call = request_definition.http_error_call
	
	
	
	match(_call_type):
		CALL_PROCESS_TYPE.SINGLE:
			# single call
			name = "single"
			_processing_type = _call_type
			_make_call_to_FEAGI(_full_address, _method, _data_to_send_to_FEAGI)
			
		CALL_PROCESS_TYPE.POLLING:
			# polling call
			name = "polling"
			_processing_type = _call_type
			_timer.wait_time = _seconds_between_polls
			_timer.start(_seconds_between_polls)
			_make_call_to_FEAGI(_full_address, _method, _data_to_send_to_FEAGI)
		_:
			# unknown call type, just exit
			push_error("Undefined call type from APIRequestWorkerDefinition. Stopping this APIRequestWorker...")
			_query_for_destruction()

## Timer went off - time to poll
func _poll_call_from_timer() -> void:
	_make_call_to_FEAGI(_full_address, _method, _data_to_send_to_FEAGI)

## Recieved signal that BV is resetting
func _brain_visualizer_resetting() -> void:
	if !_should_kill_on_genome_reset:
		return
	
	if !_is_worker_busy("", true):
		# This worker is likely idle, dont bother deleting this
		return
	
	
	print("NETWORK: WORKER: BV Reset Detected! Halting API Worker!")
	cancel_request()
	_timer.stop()
	_query_for_destruction()

## Sends request to FEAGI, and returns the output by running destination_function when reply is recieved
## data is either a Dictionary or stringable Array, and is sent for POST, PUT, and DELETE requests
## This function is called externally by [SingleCallWorker]
func _make_call_to_FEAGI(requestAddress: StringName, method: HTTPClient.Method, data: Variant = null) -> void:

	if _is_worker_busy(requestAddress):
		match _processing_type:
			CALL_PROCESS_TYPE.SINGLE:
				push_error("Skipping Single call to %s and doing call to %s instead due to call being made on an active worker" % [_full_address, requestAddress])
				_query_for_destruction()
			CALL_PROCESS_TYPE.POLLING:
				push_error("Skipping Polling call to %s and doing call to %s instead due to call being made on an active worker" % [_full_address, requestAddress])
				return

	match(method):
		HTTPClient.METHOD_GET:
			request(requestAddress, _outgoing_headers, method)
			return
		HTTPClient.METHOD_POST:
			# uncomment / breakpoint below to easily debug dictionary data
			#var debug_JSON = JSON.stringify(data)
			request(requestAddress, _outgoing_headers, method, JSON.stringify(data))
			return
		HTTPClient.METHOD_PUT:
			# uncomment / breakpoint below to easily debug dictionary data
			#var debug_JSON = JSON.stringify(data)
			request(requestAddress, _outgoing_headers, method, JSON.stringify(data))
			return
		HTTPClient.METHOD_DELETE:
			# uncomment / breakpoint below to easily debug dictionary data
			# var debug_JSON = JSON.stringify(data)
			request(requestAddress, _outgoing_headers, method, JSON.stringify(data))
			return

func _call_complete(_result: HTTPRequest.Result, response_code: int, _incoming_headers: PackedStringArray, body: PackedByteArray):
	
	if response_code != 200:
		_http_generic_error_response_handling(body)
		_query_for_destruction()
		return
	
	match(_processing_type):
		CALL_PROCESS_TYPE.SINGLE:
			# Default, no polling required
			_follow_up_function.call(response_code, body, _data_to_hold_for_follow_up_function)
			_query_for_destruction()
		CALL_PROCESS_TYPE.POLLING:
			# we are polling
			var polling_response: PollingMethodInterface.POLLING_CONFIRMATION = _polling_completion_check.confirm_complete(response_code, body)
			match polling_response:
				PollingMethodInterface.POLLING_CONFIRMATION.COMPLETE:
				# We are done polling!
					if !_follow_up_function.is_null():
						_follow_up_function.call(response_code, body, _data_to_hold_for_follow_up_function)
					_timer.stop()
					_query_for_destruction()
					return
				PollingMethodInterface.POLLING_CONFIRMATION.INCOMPLETE:
					# not done polling, keep going!
					if !_mid_poll_function.is_null():
						# we defined a call to make during polling. use it!
						_mid_poll_function.call(response_code, body, _data_to_hold_for_follow_up_function)
					else:
						print("Continuing to poll " + _full_address)
				PollingMethodInterface.POLLING_CONFIRMATION.ERROR:
					# Something went wrong, stop polling and report
					push_error("NETWORK: Polling endpoint %s has failed! Halting!" % _full_address)
					_timer.stop()
					_query_for_destruction()
					return

## Used to check if the web worker is currently doing anything
func _is_worker_busy(call_address: String, surpress_warning: bool = false) -> bool:
	match get_http_client_status():
		HTTPClient.Status.STATUS_RESOLVING:
			if !surpress_warning:
				push_warning("NETWORK: Still trying to resolve FEAGI Hostname! Skipping call to " + call_address)
			return true
		HTTPClient.Status.STATUS_REQUESTING:
			if !surpress_warning:
				push_warning("NETWORK: Still trying to request previous request to '%s'! Skipping call to '%s'" % [_full_address, call_address])
			return true
		HTTPClient.Status.STATUS_CONNECTING:
			if !surpress_warning:
				push_warning("NETWORK: Still trying to finish previous request to '%s'! Skipping call to '%s'" % [_full_address, call_address])
			return true
		_:
			return false

func _http_generic_error_response_handling(response_body: PackedByteArray) -> void:
	var feagi_error_response: Dictionary = JSON.parse_string(response_body.get_string_from_utf8())
	if "code" not in feagi_error_response:
		## If feagi didnt even send back the dict correctly, something went very wrong
		#TODO action?
		return
	VisConfig.UI_manager.make_error_notification(feagi_error_response["code"], _http_error_replacements)


## If space is available in the [RequestWorker] pool, add self to the end there
## Otherwise, destroy self
func _query_for_destruction() -> void:	
	if _network_interface_ref.API_request_workers_available.size() < _network_interface_ref.num_workers_to_keep_available:
		_network_interface_ref.API_request_workers_available.push_back(self)
		name = "Idle"
	else:
		queue_free()





