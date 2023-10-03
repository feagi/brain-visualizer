extends HTTPRequest
class_name  RequestWorker
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

var _polling_check: PollingMethodInterface
var _poll_address: StringName
var _poll_call_method: HTTPClient.Method
var _mid_poll_call: Callable
var _poll_data_to_send: Variant

## Sets up this node with all rpereqs, should only be called once on instantiation
func initialization(interface: NetworkInterface, call_header: PackedStringArray, node_parent: Node) -> void:
	request_completed.connect(_call_complete)
	_network_interface_ref = interface
	_timer = $Timer
	_timer.timeout.connect(_poll_call_from_timer)
	_outgoing_headers = call_header
	node_parent.add_child(self)


## Makes a single call to FEAGI, gets a response, triggers the followup, then queues self for destruction
func single_call(full_request_address: StringName, method: HTTPClient.Method, follow_up_function: Callable, 
	additional_data_to_send: Variant = null, data_to_buffer: Variant = null) -> void:

	_processing_type = CALL_PROCESS_TYPE.SINGLE
	_buffer_data = data_to_buffer
	_follow_up_function = follow_up_function
	_make_call_to_FEAGI(full_request_address, method, additional_data_to_send)

## Starts polling calls to FEAGI, routinely gets responses until condition defined by polling_check is met
func repeat_polling_call(full_request_address: StringName, method: HTTPClient.Method, follow_up_function: Callable,
	mid_poll_call: Callable, polling_check: PollingMethodInterface, additional_data_to_send: Variant = null, 
	data_to_buffer: Variant = null, polling_gap_seconds: float = 0.5) -> void:

	_processing_type = CALL_PROCESS_TYPE.POLLING
	_buffer_data = data_to_buffer
	_follow_up_function = follow_up_function
	_timer.wait_time = polling_gap_seconds
	_timer.start(polling_gap_seconds)
	_poll_address = full_request_address
	_poll_call_method = method
	_poll_data_to_send = additional_data_to_send
	_polling_check = polling_check
	_mid_poll_call = mid_poll_call

	_make_call_to_FEAGI(full_request_address, method, additional_data_to_send)

func _poll_call_from_timer() -> void:
	_make_call_to_FEAGI(_poll_address, _poll_call_method, _poll_data_to_send)


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
	@warning_ignore("assert_always_false")
	assert(false, "Invalid HTTP request type")

func _call_complete(_result: HTTPRequest.Result, response_code: int, _incoming_headers: PackedStringArray, body: PackedByteArray):
	match(_processing_type):
		CALL_PROCESS_TYPE.SINGLE:
			# Default, no polling required
			_follow_up_function.call(response_code, body, _buffer_data)
			_query_for_destruction()
		CALL_PROCESS_TYPE.POLLING:
			# we are polling
			if _polling_check.confirm_complete(response_code, body):
				# We are done polling!
				if !_follow_up_function.is_null():
					_follow_up_function.call(response_code, body, _buffer_data)
				_timer.stop()
				_query_for_destruction()
				return
			# not done polling, keep going!
			else:
				if !_mid_poll_call.is_null():
					# we defined a call to make during polling. use it!
					_mid_poll_call.call(response_code, body, _buffer_data)
				else:
					print("Continuing to poll " + _poll_address)
			

## If space is available in the [RequestWorker] pool, add self to the end there
## Otherwise, destroy self
func _query_for_destruction() -> void:
	if _network_interface_ref.num_request_workers_available <= _network_interface_ref.num_workers_to_keep_available:
		_network_interface_ref.request_workers_available.push_back(self)
	else:
		queue_free()





