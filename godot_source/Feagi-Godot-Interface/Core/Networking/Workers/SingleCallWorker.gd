extends Node
class_name SingleCallWorker

enum POLLING_STATUS {
	NONE,
	WILL_POLL,
	POLLING
}

signal initial_call_complete(result: Result, response_code: int, _incoming_headers: PackedStringArray, body: PackedByteArray)
signal polling_call_complete(result: Result, response_code: int, _incoming_headers: PackedStringArray, body: PackedByteArray)

var _call_package: CallPackage
var _request_worker: RequestWorker
var _polling_state: POLLING_STATUS = POLLING_STATUS.NONE
var _network_interface_ref: NetworkInterface


func setup_and_call(interface: NetworkInterface, call_package: CallPackage, call_header: PackedStringArray) -> void:
	_call_package = call_package
	_request_worker = $RequestWorker
	_request_worker.request_completed.connect(_call_complete)
	_request_worker.outgoing_headers = call_header
	_network_interface_ref = interface
	if _call_package.is_polling:
		_polling_state = POLLING_STATUS.WILL_POLL
	else:
		_polling_state = POLLING_STATUS.NONE
	_make_call()


func _make_call() -> void:
	_request_worker.FEAGI_call(
		_call_package.complete_URL,
		_call_package.call_method,
		_call_package.data_to_send)
		

func _call_complete(result: HTTPRequest.Result, response_code: int, incoming_headers: PackedStringArray, body: PackedByteArray):
	match(_polling_state):
		POLLING_STATUS.NONE:
			# Default, no polling required
			if call_package.initial_response_function.is_valid():
				_call_package.initial_response_function.call(response_code, body)
			initial_call_complete.emit(result, response_code, incoming_headers, body)
			query_for_destruction()
		POLLING_STATUS.WILL_POLL:
			# First call before starting to poll



## If space is available in the [RequestWorker] pool, add self to the end there
## Otherwise, destroy self
func query_for_destruction() -> void:
	if _network_interface_ref.num_request_workers_available <= _network_interface_ref.num_workers_to_keep_available:
		_network_interface_ref.request_workers_available.push_back(self)
	else:
		queue_free()

