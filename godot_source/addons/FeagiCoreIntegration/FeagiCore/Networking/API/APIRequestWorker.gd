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

signal worker_done() ## Emitted when a worker is done including done polling)
signal worker_retrieved_latest_poll()  ## Emitted when a worker has recieved the data for its latest poll, but is still polling

var _timer: Timer
var _outgoing_headers: PackedStringArray # headers to make requests with
var _request_definition: APIRequestWorkerDefinition
var _output_response: APIRequestWorkerOutput

## Setup and execute the worker as per the request definition
func setup_and_run_from_definition(call_header: PackedStringArray, request_definition: APIRequestWorkerDefinition) -> void:
	
	#init
	request_completed.connect(_call_complete)
	_outgoing_headers = call_header
	_request_definition = request_definition
	timeout = request_definition.http_timeout
	
	# Setup and run call
	match(request_definition.call_type):
		CALL_PROCESS_TYPE.SINGLE:
			# single call
			name = "single"
			_make_call_to_FEAGI(request_definition.full_address, request_definition.method, request_definition.data_to_send_to_FEAGI)
			
		CALL_PROCESS_TYPE.POLLING:
			# polling call
			name = "polling"
			_timer = $Timer
			_timer.timeout.connect(_poll_call_from_timer)
			_timer.wait_time = request_definition.seconds_between_polls
			_timer.start(request_definition.seconds_between_polls)
			_make_call_to_FEAGI(request_definition.full_address, request_definition.method, request_definition.data_to_send_to_FEAGI)

## Timer went off - time to poll
func _poll_call_from_timer() -> void:
	_make_call_to_FEAGI(_request_definition.full_address, _request_definition.method, _request_definition.data_to_send_to_FEAGI)

## Sends request to FEAGI, and returns the output by running destination_function when reply is recieved
## data is either a Dictionary or stringable Array, and is sent for POST, PUT, and DELETE requests
## This function is called externally by [SingleCallWorker]
func _make_call_to_FEAGI(requestAddress: StringName, method: HTTPClient.Method, data: Variant = null) -> void:

	match(method):
		HTTPClient.METHOD_GET:
			request(requestAddress, _outgoing_headers, method)
			return
		HTTPClient.METHOD_POST:
			# uncomment / breakpoint below to easily debug dictionary data
			# var debug_JSON = JSON.stringify(data)
			request(requestAddress, _outgoing_headers, method, JSON.stringify(data))
			return
		HTTPClient.METHOD_PUT:
			# uncomment / breakpoint below to easily debug dictionary data
			# var debug_JSON = JSON.stringify(data)
			request(requestAddress, _outgoing_headers, method, JSON.stringify(data))
			return
		HTTPClient.METHOD_DELETE:
			# uncomment / breakpoint below to easily debug dictionary data
			# var debug_JSON = JSON.stringify(data)
			request(requestAddress, _outgoing_headers, method, JSON.stringify(data))
			return

func retrieve_output_and_close() -> APIRequestWorkerOutput:
	if _output_response == null:
		push_error("FEAGI NETWORK HTTP: Output retrieved before HTTP call was complete! Returning Empty Error Call. This will likely cause issues!")
		_output_response = APIRequestWorkerOutput.response_error_response([], _request_definition.call_type == CALL_PROCESS_TYPE.POLLING)
	queue_free()
	return _output_response

## Called when FEAGI returns data from call (or HTTP call timed out)
func _call_complete(_result: HTTPRequest.Result, response_code: int, _incoming_headers: PackedStringArray, body: PackedByteArray):
	
	# Unresponsive FEAGI 
	if response_code == 0:
		push_warning("FEAGI NETWORK HTTP: FEAGI did not respond on endpoint: %s" % _request_definition.full_address)
		_output_response = APIRequestWorkerOutput.response_no_response(_request_definition.call_type == CALL_PROCESS_TYPE.POLLING)
		worker_done.emit()
		return
	
	# FEAGI responded with an error
	if response_code != 200:
		push_warning("FEAGI NETWORK HTTP: FEAGI responded from endpoint: %s with HTTP error code: %s" % [_request_definition.full_address, response_code])
		_output_response = APIRequestWorkerOutput.response_error_response(body, _request_definition.call_type == CALL_PROCESS_TYPE.POLLING)
		worker_done.emit()
		return
	
	# FEAGI responded with a success
	match(_request_definition.call_type):
		CALL_PROCESS_TYPE.SINGLE:
			# Single call, nothing else to do
			_output_response = APIRequestWorkerOutput.response_success(body, false)
			worker_done.emit()
			return
		CALL_PROCESS_TYPE.POLLING:
			# we are polling
			var polling_response: BasePollingMethod.POLLING_CONFIRMATION = _request_definition.polling_completion_check.confirm_complete(response_code, body)
			match polling_response:
				BasePollingMethod.POLLING_CONFIRMATION.COMPLETE:
					# We are done polling!
					_output_response = APIRequestWorkerOutput.response_success(body, true)
					worker_done.emit()
					_timer.stop()
					return
				BasePollingMethod.POLLING_CONFIRMATION.INCOMPLETE:
					# not done polling, keep going!
					_output_response = APIRequestWorkerOutput.response_success(body, true)
					worker_retrieved_latest_poll.emit()
					return
				BasePollingMethod.POLLING_CONFIRMATION.ERROR:
					#n This actually shouldnt be possible. Report error and close
					push_error("FEAGI NETWORK HTTP: Polling endpoint has failed! Halting!")
					_output_response = APIRequestWorkerOutput.response_error_response(body, _request_definition.call_type == CALL_PROCESS_TYPE.POLLING)
					worker_done.emit()
					_timer.stop()
					return

