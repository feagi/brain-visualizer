extends HTTPRequest
class_name  RequestWorker
## GET/POST/PUT/DELETE worker for [NetworkInterface]
##
## On initialization, toggles multiThreading, sets internals, and parents itself to a given parent (this does not need to be done seperately)
## Sits idle but when given a network call, will run it then return the output to the given relay function._add_constant_central_force
## After this point, will return to the queue in [NetworkInterface] if there is enough room, otherwise will destroy itself
##

var network_interface: NetworkInterface
var outgoing_headers: PackedStringArray # headers to make requests with
var data_to_pass_through: Variant = null
var destination_function_to_run: Callable
var cached_called_addresses: StringName # Used in [method RequestWorker._report_error] to print an error

func _init(should_use_threads: bool, interface: NetworkInterface, web_headers: PackedStringArray, parent_target: Node):
	use_threads = should_use_threads # use built in multithreading - MUST be disabled on web exports
	network_interface = interface
	outgoing_headers = web_headers
	parent_target.add_child(self)
	request_completed.connect(_on_request_completed)


## Sends request to FEAGI, and returns the output by running destination_function when reply is recieved
## data is either a Dictionary or stringable Array, and is sent for POST, PUT, and DELETE requests
## pass_through_data is optionally used for any use where additional current context is needed in the delayed response of the destination_function
## This function is called externally by [NetworkInterface]
func FEAGI_call(requestAddress: StringName, method: HTTPClient.Method, destination_function: Callable, data: Variant = null, pass_through_data: Variant = null) -> void:
	destination_function_to_run = destination_function
	if pass_through_data != null: 
		data_to_pass_through = pass_through_data

	match(method):
		HTTPClient.METHOD_GET:
			request(requestAddress, outgoing_headers, method)
			return
		HTTPClient.METHOD_POST:
			request(requestAddress, outgoing_headers, method, JSON.stringify(data))
			return
		HTTPClient.METHOD_PUT:
			request(requestAddress, outgoing_headers, method, JSON.stringify(data))
			return
		HTTPClient.METHOD_DELETE:
			request(requestAddress, outgoing_headers, method, JSON.stringify(data))
			return
	@warning_ignore("assert_always_false")
	assert(false, "Invalid HTTP request type")


## Called on completion of FEAGI request.
## If response was OK, will call the defined passthrough callable and include the body data (as a ByteArray) and the data_to_pass_through (optionally used)
## If response was invalid, will print an error and not continue
func _on_request_completed(result: Result, response_code: int, _incoming_headers: PackedStringArray, body: PackedByteArray) -> void:
	if result == RESULT_SUCCESS:
		# valid response, fire cached Callable
		destination_function_to_run.call(response_code, body, data_to_pass_through)
	else:
		# Something went wrong, report and do not proceed with running the destination function
		_report_error(response_code)
	_QueryForDestruction()


## If space is available in the [RequestWorker] pool, add self to the end there
## Otherwise, destroy self
func _QueryForDestruction() -> void:
	if network_interface.num_workers_available <= network_interface.num_workers_to_keep_available:
		network_interface.workers_available.push_back(self)
	else:
		queue_free()


## Pushes an error (without stopping the program) when a call to FEAGI failed
func _report_error(error_code: int) -> void:
	push_error("FEAGI returned " + str(error_code) + " when communicating with endpoint " + cached_called_addresses)
	# TODO inform user with notification?
