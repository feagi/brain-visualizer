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

var _request_definition: APIRequestWorkerDefinition
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
	_request_definition = request_definition
	match(request_definition.call_type):
		CALL_PROCESS_TYPE.SINGLE:
			# single call
			name = "single"
			_processing_type = request_definition.call_type
			_make_call_to_FEAGI(request_definition.full_address, request_definition.method, request_definition.data_to_send_to_FEAGI)
			
		CALL_PROCESS_TYPE.POLLING:
			# polling call
			name = "polling"
			_processing_type = request_definition.call_type
			_timer.wait_time = request_definition.seconds_between_polls
			_timer.start(request_definition.seconds_between_polls)
			_make_call_to_FEAGI(request_definition.full_address, request_definition.method, request_definition.data_to_send_to_FEAGI)
		_:
			# unknown call type, just exit
			push_error("Undefined call type from APIRequestWorkerDefinition. Stopping this APIRequestWorker...")
			_query_for_destruction()

## Timer went off - time to poll
func _poll_call_from_timer() -> void:
	_make_call_to_FEAGI(_request_definition.full_address, _request_definition.method, _request_definition.data_to_send_to_FEAGI)

## Recieved signal that BV is resetting
func _brain_visualizer_resetting() -> void:
	if !_request_definition.should_kill_on_genome_reset:
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
				push_error("Skipping Single call to %s and doing call to %s instead due to call being made on an active worker" % [_request_definition.full_address, requestAddress])
				_query_for_destruction()
			CALL_PROCESS_TYPE.POLLING:
				push_error("Skipping Polling call to %s and doing call to %s instead due to call being made on an active worker" % [_request_definition.full_address, requestAddress])
				return

	match(method):
		HTTPClient.METHOD_GET:
			request(requestAddress, _outgoing_headers, method)
			return
		HTTPClient.METHOD_POST:
			# uncomment / breakpoint below to easily debug dictionary data
			var debug_JSON = JSON.stringify(data)
			request(requestAddress, _outgoing_headers, method, JSON.stringify(data))
			return
		HTTPClient.METHOD_PUT:
			# uncomment / breakpoint below to easily debug dictionary data
			var debug_JSON = JSON.stringify(data)
			request(requestAddress, _outgoing_headers, method, JSON.stringify(data))
			return
		HTTPClient.METHOD_DELETE:
			# uncomment / breakpoint below to easily debug dictionary data
			# var debug_JSON = JSON.stringify(data)
			request(requestAddress, _outgoing_headers, method, JSON.stringify(data))
			return

func _call_complete(result: HTTPRequest.Result, response_code: int, _incoming_headers: PackedStringArray, body: PackedByteArray):
	if result == 400:
		_http_400_generic_handling(body)
		_query_for_destruction()
		return
	if result == 500:
		_http_500_generic_handling(body)
		_query_for_destruction()
		return
	
	
	
	match(_processing_type):
		CALL_PROCESS_TYPE.SINGLE:
			# Default, no polling required
			_request_definition.follow_up_function.call(response_code, body, _request_definition.data_to_hold_for_follow_up_function)
			_query_for_destruction()
		CALL_PROCESS_TYPE.POLLING:
			# we are polling
			var polling_response: PollingMethodInterface.POLLING_CONFIRMATION = _request_definition.polling_completion_check.confirm_complete(response_code, body)
			match polling_response:
				PollingMethodInterface.POLLING_CONFIRMATION.COMPLETE:
				# We are done polling!
					if !_request_definition.follow_up_function.is_null():
						_request_definition.follow_up_function.call(response_code, body, _request_definition.data_to_hold_for_follow_up_function)
					_timer.stop()
					_query_for_destruction()
					return
				PollingMethodInterface.POLLING_CONFIRMATION.INCOMPLETE:
					# not done polling, keep going!
					if !_request_definition.mid_poll_function.is_null():
						# we defined a call to make during polling. use it!
						_request_definition.mid_poll_function.call(response_code, body, _request_definition.data_to_hold_for_follow_up_function)
					else:
						print("Continuing to poll " + _request_definition.full_address)
				PollingMethodInterface.POLLING_CONFIRMATION.ERROR:
					# Something went wrong, stop polling and report
					push_error("NETWORK: Polling endpoint %s has failed! Halting!" % _request_definition.full_address)
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
				push_warning("NETWORK: Still trying to request previous request to '%s'! Skipping call to '%s'" % [_request_definition.full_address, call_address])
			return true
		HTTPClient.Status.STATUS_CONNECTING:
			if !surpress_warning:
				push_warning("NETWORK: Still trying to finish previous request to '%s'! Skipping call to '%s'" % [_request_definition.full_address, call_address])
			return true
		_:
			return false

func _http_400_generic_handling(body: PackedByteArray) -> void:
	pass

func _http_500_generic_handling(body: PackedByteArray) -> void:
	pass

## If space is available in the [RequestWorker] pool, add self to the end there
## Otherwise, destroy self
func _query_for_destruction() -> void:	
	if _network_interface_ref.API_request_workers_available.size() < _network_interface_ref.num_workers_to_keep_available:
		_network_interface_ref.API_request_workers_available.push_back(self)
		name = "Idle"
	else:
		free()





