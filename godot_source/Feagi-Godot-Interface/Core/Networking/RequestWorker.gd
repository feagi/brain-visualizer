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

func _init(should_use_threads: bool, interface: NetworkInterface, web_headers: PackedStringArray, parent_target: Node):
	use_threads = should_use_threads # use built in multithreading - MUST be disabled on web exports
	network_interface = interface
	outgoing_headers = web_headers
	parent_target.add_child(self)

## Sends request to FEAGI, and returns the output by running destination_function when reply is recieved
## data is either a Dictionary or stringable Array, and is sent for POST, PUT, and DELETE requests
## This function is called externally by [SingleCallWorker]
func FEAGI_call(requestAddress: StringName, method: HTTPClient.Method, data: Variant = null) -> void:

	match(method):
		HTTPClient.METHOD_GET:
			request(requestAddress, outgoing_headers, method)
			return
		HTTPClient.METHOD_POST:
			# uncomment / breakpoint below to easily debug dictionary data
			#var debug_JSON = JSON.stringify(data)
			request(requestAddress, outgoing_headers, method, JSON.stringify(data))
			return
		HTTPClient.METHOD_PUT:
			# uncomment / breakpoint below to easily debug dictionary data
			#var debug_JSON = JSON.stringify(data)
			request(requestAddress, outgoing_headers, method, JSON.stringify(data))
			return
		HTTPClient.METHOD_DELETE:
			# uncomment / breakpoint below to easily debug dictionary data
			# var debug_JSON = JSON.stringify(data)
			request(requestAddress, outgoing_headers, method, JSON.stringify(data))
			return
	@warning_ignore("assert_always_false")
	assert(false, "Invalid HTTP request type")



## If space is available in the [RequestWorker] pool, add self to the end there
## Otherwise, destroy self
func QueryForDestruction() -> void:
	if network_interface.num_request_workers_available <= network_interface.num_workers_to_keep_available:
		network_interface.request_workers_available.push_back(self)
	else:
		queue_free()

