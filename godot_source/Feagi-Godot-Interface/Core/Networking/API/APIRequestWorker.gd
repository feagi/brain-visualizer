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

var _outgoing_headers: PackedStringArray # headers to make requests with
var _processing_type: CALL_PROCESS_TYPE
var _buffer_data: Variant
var _follow_up_function: Callable
var _killing_on_reset: bool
var _initial_call_address: StringName
var _polling_check: PollingMethodInterface
var _poll_address: StringName
var _poll_call_method: HTTPClient.Method
var _mid_poll_call: Callable
var _poll_data_to_send: Variant
var _http_error_call: Callable
var _http_error_replacements: Dictionary

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
	
	#_http_error_call = request_definition.http_error_call
	#_http_error_replacements = request_definition.http_error_replacements
	
	match(request_definition.call_type):
		CALL_PROCESS_TYPE.SINGLE:
			# single call
			name = "single"
			_processing_type = request_definition.call_type
			_buffer_data = request_definition.data_to_hold_for_follow_up_function
			_follow_up_function = request_definition.follow_up_function
			_killing_on_reset = request_definition.should_kill_on_genome_reset
			_initial_call_address = request_definition.full_address
			_make_call_to_FEAGI(request_definition.full_address, request_definition.method, request_definition.data_to_send_to_FEAGI)
			
		CALL_PROCESS_TYPE.POLLING:
			# polling call
			name = "polling"
			_processing_type = request_definition.call_type
			_buffer_data = request_definition.data_to_hold_for_follow_up_function
			_follow_up_function = request_definition.follow_up_function
			_killing_on_reset = request_definition.should_kill_on_genome_reset
			_initial_call_address = request_definition.full_address
			_timer.wait_time = request_definition.seconds_between_polls
			_timer.start(request_definition.seconds_between_polls)
			_poll_address = request_definition.full_address
			_poll_call_method = request_definition.method
			_poll_data_to_send = request_definition.data_to_send_to_FEAGI
			_polling_check = request_definition.polling_completion_check
			_mid_poll_call = request_definition.mid_poll_function
			_make_call_to_FEAGI(request_definition.full_address, request_definition.method, request_definition.data_to_send_to_FEAGI)
		_:
			# unknown call type, just exit
			push_error("Undefined call type from APIRequestWorkerDefinition. Stopping this APIRequestWorker...")
			_query_for_destruction()

## Timer went off - time to poll
func _poll_call_from_timer() -> void:
	_make_call_to_FEAGI(_poll_address, _poll_call_method, _poll_data_to_send)

## Recieved signal that BV is resetting
func _brain_visualizer_resetting() -> void:
	if !_killing_on_reset:
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
				push_error("Skipping Single call to %s and doing call to %s instead due to call being made on an active worker" % [_initial_call_address, requestAddress])
				_query_for_destruction()
			CALL_PROCESS_TYPE.POLLING:
				push_error("Skipping Polling call to %s and doing call to %s instead due to call being made on an active worker" % [_initial_call_address, requestAddress])
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

func _call_complete(_result: HTTPRequest.Result, response_code: int, _incoming_headers: PackedStringArray, body: PackedByteArray):
	
	if response_code != 200:
		_http_generic_error_response_handling(body)
		_query_for_destruction()
		return
	
	match(_processing_type):
		CALL_PROCESS_TYPE.SINGLE:
			# Default, no polling required
			_follow_up_function.call(response_code, body, _buffer_data)
			_query_for_destruction()
		CALL_PROCESS_TYPE.POLLING:
			# we are polling
			var polling_response: PollingMethodInterface.POLLING_CONFIRMATION = _polling_check.confirm_complete(response_code, body)
			match polling_response:
				PollingMethodInterface.POLLING_CONFIRMATION.COMPLETE:
				# We are done polling!
					if !_follow_up_function.is_null():
						_follow_up_function.call(response_code, body, _buffer_data)
					_timer.stop()
					_query_for_destruction()
					return
				PollingMethodInterface.POLLING_CONFIRMATION.INCOMPLETE:
					# not done polling, keep going!
					if !_mid_poll_call.is_null():
						# we defined a call to make during polling. use it!
						_mid_poll_call.call(response_code, body, _buffer_data)
					else:
						print("Continuing to poll " + _poll_address)
				PollingMethodInterface.POLLING_CONFIRMATION.ERROR:
					# Something went wrong, stop polling and report
					push_error("NETWORK: Polling endpoint %s has failed! Halting!" % _poll_address)
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
				push_warning("NETWORK: Still trying to request previous request to '%s'! Skipping call to '%s'" % [_initial_call_address, call_address])
			return true
		HTTPClient.Status.STATUS_CONNECTING:
			if !surpress_warning:
				push_warning("NETWORK: Still trying to finish previous request to '%s'! Skipping call to '%s'" % [_initial_call_address, call_address])
			return true
		_:
			return false

func _http_generic_error_response_handling(response_body: PackedByteArray) -> void:
	var feagi_error_response: Dictionary = JSON.parse_string(response_body.get_string_from_utf8())
	if "code" not in feagi_error_response.keys():
		## If feagi didnt even send back the dict correctly, something went very wrong
		#TODO action?
		return
	var error_code_identifier: StringName = feagi_error_response["code"]
	#VisConfig.UI_manager.make_error_notification(error_code_identifier, _http_error_replacements)

## If space is available in the [RequestWorker] pool, add self to the end there
## Otherwise, destroy self
func _query_for_destruction() -> void:	
	if _network_interface_ref.API_request_workers_available.size() < _network_interface_ref.num_workers_to_keep_available:
		_network_interface_ref.API_request_workers_available.push_back(self)
		name = "Idle"
		_buffer_data = null
		_initial_call_address = ""
		_polling_check = null
		_poll_address = ""
		_poll_data_to_send = null
	else:
		queue_free()





