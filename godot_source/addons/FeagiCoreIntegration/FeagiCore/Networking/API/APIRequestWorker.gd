extends HTTPRequest
class_name  APIRequestWorker
## GET/POST/PUT/DELETE worker for [FEAGIHTTOAPI]
## Upon initialization, will set itself up as per the given [APIRequestWorkerDefinition]
## If endpoint is unresponsive, will attempt again as per FEAGI settings


enum CALL_PROCESS_TYPE {
	SINGLE,
	POLLING # polling is cancer
}

signal worker_done() ## Emitted when a worker is done including done polling)
signal worker_retrieved_latest_poll(output_response: FeagiRequestOutput)  ## Emitted when a worker has recieved the data for its latest poll, but is still polling
signal retrying_connection(current_retry_attempt: int, max_number_retries: int)

var _timer: Timer
var _outgoing_headers: PackedStringArray # headers to make requests with
var _request_definition: APIRequestWorkerDefinition
var _output_response: FeagiRequestOutput
var _number_retries_done: int = 0

## Setup and execute the worker as per the request definition
func setup_and_run_from_definition(call_header: PackedStringArray, request_definition: APIRequestWorkerDefinition) -> void:
	
	#init
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

## Returns whatever the worker got from FEAGI (or didn't if timed out), then deletes the worker
func retrieve_output_and_close() -> FeagiRequestOutput:
	if _output_response == null:
		push_error("FEAGI NETWORK HTTP: Output retrieved before HTTP call was complete! Returning Empty Error Call. This will likely cause issues!")
		_output_response = FeagiRequestOutput.response_error_response([], _request_definition.call_type == CALL_PROCESS_TYPE.POLLING)
	queue_free()
	return _output_response

## Returns the most recent output got from FEAGI (or didn't if timed out), but doesn't delete the worker. Best used for Polling
func retrieve_output_and_continue() -> FeagiRequestOutput:
	if _output_response == null:
		push_error("FEAGI NETWORK HTTP: Output retrieved before any HTTP call was complete! Returning Empty Error Call. This will likely cause issues!")
		return FeagiRequestOutput.response_error_response([], _request_definition.call_type == CALL_PROCESS_TYPE.POLLING)
	return _output_response

## Kills the worker early
func kill_worker() -> void:
	cancel_request()
	queue_free()

## Called when FEAGI returns data from call (or HTTP call timed out)
func _call_complete(_result: HTTPRequest.Result, response_code: int, _incoming_headers: PackedStringArray, body: PackedByteArray):
	
	# NOTE: Tinstances of this object are handled soley by [FEAGIHTTPAPI], so we will allow freeing of this object by that as well! 
	
	# Unresponsive FEAGI 
	if response_code == 0:
		push_warning("FEAGI NETWORK HTTP: FEAGI did not respond %d times on endpoint: %s" % [_number_retries_done, _request_definition.full_address])
		_number_retries_done += 1
		if _number_retries_done > _request_definition.number_of_retries_allowed:
			push_error("FEAGI NETWORK HTTP: FEAGI failed to respond more times than retries allowed! Signaling disconnection")
			_output_response = FeagiRequestOutput.response_no_response(_request_definition.call_type == CALL_PROCESS_TYPE.POLLING)
			worker_done.emit()
			return
		# Retry connection
		retrying_connection.emit(_number_retries_done, _request_definition.number_of_retries_allowed)
		match(_request_definition.call_type):
			CALL_PROCESS_TYPE.SINGLE:
				# single call
				_make_call_to_FEAGI(_request_definition.full_address, _request_definition.method, _request_definition.data_to_send_to_FEAGI)
			CALL_PROCESS_TYPE.POLLING:
				# polling call
				_timer.wait_time = _request_definition.seconds_between_polls
				_timer.start(_request_definition.seconds_between_polls)
				_make_call_to_FEAGI(_request_definition.full_address, _request_definition.method, _request_definition.data_to_send_to_FEAGI)
		return

	# FEAGI responded with an error
	if response_code != 200:
		push_warning("FEAGI NETWORK HTTP: FEAGI responded from endpoint: %s with HTTP error code: %s" % [_request_definition.full_address, response_code])
		_output_response = FeagiRequestOutput.response_error_response(body, _request_definition.call_type == CALL_PROCESS_TYPE.POLLING)
		worker_done.emit()
		return
	
	# FEAGI responded with a success
	match(_request_definition.call_type):
		CALL_PROCESS_TYPE.SINGLE:
			# Single call, nothing else to do
			_output_response = FeagiRequestOutput.response_success(body, false)
			worker_done.emit()
			return
		CALL_PROCESS_TYPE.POLLING:
			# we are polling
			var polling_response: BasePollingMethod.POLLING_CONFIRMATION = _request_definition.polling_completion_check.confirm_complete(response_code, body)
			match polling_response:
				BasePollingMethod.POLLING_CONFIRMATION.COMPLETE:
					# We are done polling!
					_output_response = FeagiRequestOutput.response_success(body, true)
					worker_done.emit()
					_timer.stop()
					return
				BasePollingMethod.POLLING_CONFIRMATION.INCOMPLETE:
					# not done polling, keep going!
					_output_response = FeagiRequestOutput.response_success(body, true)
					worker_retrieved_latest_poll.emit(_output_response)
					return
				BasePollingMethod.POLLING_CONFIRMATION.ERROR:
					#n This actually shouldnt be possible. Report error and close
					push_error("FEAGI NETWORK HTTP: Polling endpoint has failed! Halting!")
					_output_response = FeagiRequestOutput.response_error_response(body, _request_definition.call_type == CALL_PROCESS_TYPE.POLLING)
					worker_done.emit()
					_timer.stop()
					return

