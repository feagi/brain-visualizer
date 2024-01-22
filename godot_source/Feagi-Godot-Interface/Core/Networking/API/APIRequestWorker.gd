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

var _polling_check: PollingMethodInterface
var _poll_address: StringName
var _poll_call_method: HTTPClient.Method
var _mid_poll_call: Callable
var _poll_data_to_send: Variant

## Sets up this node with all rpereqs, should only be called once on instantiation
func initialization(interface: NetworkInterface, call_header: PackedStringArray, node_parent: Node) -> void:
	FeagiEvents.genome_is_about_to_reset.connect(_brain_visualizer_resetting)
	request_completed.connect(_call_complete)
	_network_interface_ref = interface
	_timer = $Timer
	_timer.timeout.connect(_poll_call_from_timer)
	_outgoing_headers = call_header
	node_parent.add_child(self)
	name = "New"


## Makes a single call to FEAGI, gets a response, triggers the followup, then queues self for destruction
func single_call(full_request_address: StringName, method: HTTPClient.Method, follow_up_function: Callable, 
	additional_data_to_send: Variant = null, data_to_buffer: Variant = null) -> void:

	_processing_type = CALL_PROCESS_TYPE.SINGLE
	_buffer_data = data_to_buffer
	_follow_up_function = follow_up_function
	name = "single"
	_make_call_to_FEAGI(full_request_address, method, additional_data_to_send)

## Starts polling calls to FEAGI, routinely gets responses until condition defined by polling_check is met
func repeat_polling_call(full_request_address: StringName, method: HTTPClient.Method, follow_up_function: Callable,
	mid_poll_call: Callable, polling_check: PollingMethodInterface, additional_data_to_send: Variant = null, 
	data_to_buffer: Variant = null, polling_gap_seconds: float = 0.5, kill_on_reset = false) -> void:

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
	_killing_on_reset = kill_on_reset
	
	name = "polling"
	
	_make_call_to_FEAGI(full_request_address, method, additional_data_to_send)

## Timer went off - time to poll
func _poll_call_from_timer() -> void:
	_make_call_to_FEAGI(_poll_address, _poll_call_method, _poll_data_to_send)

## Recieved signal that BV is resetting
func _brain_visualizer_resetting() -> void:
	if !_killing_on_reset:
		return
	print("NETWORK: WORKER: BV Reset Detected! Halting Poll Worker!")
	cancel_request()
	_timer.stop()
	_query_for_destruction()

## Sends request to FEAGI, and returns the output by running destination_function when reply is recieved
## data is either a Dictionary or stringable Array, and is sent for POST, PUT, and DELETE requests
## This function is called externally by [SingleCallWorker]
func _make_call_to_FEAGI(requestAddress: StringName, method: HTTPClient.Method, data: Variant = null) -> void:

	if _is_worker_busy(requestAddress):
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
func _is_worker_busy(call_address: String) -> bool:
	match get_http_client_status():
		HTTPClient.Status.STATUS_RESOLVING:
			push_warning("NETWORK: Still trying to resolve FEAGI Hostname! Skipping call to " + call_address)
			return true
		HTTPClient.Status.STATUS_REQUESTING:
			push_warning("NETWORK: Still trying to request previous request! Skipping call to " + call_address)
			return true
		HTTPClient.Status.STATUS_CONNECTING:
			push_warning("NETWORK: Still trying to finish previous request! Skipping call to " + call_address)
			return true
		_:
			return false
		



## If space is available in the [RequestWorker] pool, add self to the end there
## Otherwise, destroy self
func _query_for_destruction() -> void:
	if _network_interface_ref.request_workers_available.size() <= _network_interface_ref.num_workers_to_keep_available:
		_network_interface_ref.request_workers_available.push_back(self)
		name = "Idle"
	else:
		queue_free()





