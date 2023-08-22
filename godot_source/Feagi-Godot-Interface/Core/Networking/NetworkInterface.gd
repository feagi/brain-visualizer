extends Object
## Manages all actual network traffic to and from FEAGI itself
##
## Should generally not be called directly from most scripts, This script is intended to be mainly called from TODO
##
class_name NetworkInterface

# Static Network Configuration
const DEF_MINWORKERSAVAILABLE: int = 5
const DEF_HEADERSTOUSE: PackedStringArray = ["Content-Type: application/json"]
const DEF_FEAGI_TLD: StringName = "127.0.0.1"
const DEF_FEAGI_SSL: StringName = "http://"
const DEF_SOCKET_SSL: StringName = "ws://"
const DEF_WEB_PORT: int = 8000
const DEF_SOCKET_PORT: int = 9050
const DEF_SOCKET_MAX_QUEUED_PACKETS: int = 10000000
const DEF_SOCKET_INBOUND_BUFFER_SIZE: int = 10000000
const DEF_SOCKET_BUFFER_SIZE: int = 10000000

const SOCKET_GENOME_UPDATE_FLAG: String = "updated" # FEAGI sends this string via websocket if genome is reloaded / changed

signal socket_state_changed(state: WebSocketPeer.State)

var num_workers_available: int:
	get: return workers_available.size()

var feagi_TLD: StringName
var feagi_SSL: StringName
var feagi_web_port: int
var feagi_socket_port: int
var feagi_root_web_address: StringName
var feagi_root_websocket_address: StringName
var feagi_socket_SSL: StringName
var feagi_socket_address: StringName
var feagi_outgoing_headers: PackedStringArray
var endpoints: AddressList
var num_workers_to_keep_available: int
var workers_available: Array[RequestWorker]
var current_websocket_state: WebSocketPeer.State


var _request_worker_parent: Node
var _multithreading_enabled: bool # cannot be changed after init
var _socket: WebSocketPeer
var _cache_websocket_data: PackedByteArray


## Used to init the network interface
## Required before usage
func init_network(worker_parent_root: Node) -> void:
	#var SSL: String = JavaScriptBridge.eval(""" 
	#function get_port() {
	#    var url_string = window.location.href;
	#    var url = new URL(url_string);
	#    const searchParams = new URLSearchParams(url.search);
	#    const ipAddress = searchParams.get("http_type");
	#    return ipAddress;
	#}
	#get_port();
	#""")
	#if SSL != null: feagi_SSL = DEF_FEAGI_SSL
	
	# TODO for now have hard coded addresses, but later we should switch to above system (essentially import previous method here)
	# TODO ask kevin
	feagi_SSL = DEF_FEAGI_SSL
	feagi_TLD = DEF_FEAGI_TLD
	feagi_web_port = DEF_WEB_PORT
	feagi_socket_port = DEF_SOCKET_PORT
	feagi_socket_SSL = DEF_SOCKET_SSL
	feagi_outgoing_headers = DEF_HEADERSTOUSE
	num_workers_to_keep_available = DEF_MINWORKERSAVAILABLE


	# With collected data, init API
	_request_worker_parent = worker_parent_root
	feagi_root_web_address = feagi_SSL + feagi_TLD + ":" + str(feagi_web_port)

	endpoints = AddressList.new(feagi_root_web_address)
	_spawn_initial_workers()
	_log_connection_address()

	# init WebSocket
	feagi_socket_address = feagi_socket_SSL + feagi_TLD + ":" + str(feagi_socket_port)
	_log_socket_address()
	_socket = WebSocketPeer.new()
	_socket.connect_to_url(feagi_socket_address)
	_socket.inbound_buffer_size = 10000000
	current_websocket_state = WebSocketPeer.STATE_CONNECTING
	


## Makes a GET API call to FEAGI which then runs the given function call (with optional pass through data)
func FEAGI_GET(full_request_address: StringName, function_to_respond_to_FEAGI: Callable, data_to_pass_through: Variant = null) -> void:
	_API_FEAGI(full_request_address, HTTPClient.METHOD_GET , function_to_respond_to_FEAGI, null, data_to_pass_through)


## Makes a POST API call to FEAGI with given data which then runs the given function call (with optional pass through data)
func FEAGI_POST(full_request_address: StringName, function_to_respond_to_FEAGI: Callable, additional_data: Variant, data_to_pass_through: Variant = null) -> void:
	_API_FEAGI(full_request_address, HTTPClient.METHOD_POST , function_to_respond_to_FEAGI, additional_data, data_to_pass_through)


## Makes a PUT API call to FEAGI with given data which then runs the given function call (with optional pass through data)
func FEAGI_PUT(full_request_address: StringName, function_to_respond_to_FEAGI: Callable, additional_data: Variant, data_to_pass_through: Variant = null) -> void:
	_API_FEAGI(full_request_address, HTTPClient.METHOD_PUT , function_to_respond_to_FEAGI, additional_data, data_to_pass_through)


## Makes a DELETE API call to FEAGI with given data which then runs the given function call (with optional pass through data)
func FEAGI_DELETE(full_request_address: StringName, function_to_respond_to_FEAGI: Callable, data_to_pass_through: Variant = null) -> void:
	_API_FEAGI(full_request_address, HTTPClient.METHOD_DELETE , function_to_respond_to_FEAGI, null, data_to_pass_through)

## attempts to send data over websocket
func websocket_send(data: Variant) -> void:
	if current_websocket_state != WebSocketPeer.STATE_OPEN:
		push_warning("Unable to send data to closed socket!")
		return
	_socket.send((data.to_ascii_buffer()).compress(1))


## Makes a API call using an available [RequestWorker] (or if none are available, spawns one first)
func _API_FEAGI(full_request_address: StringName, method: HTTPClient.Method, 
	function_to_respond_to_FEAGI: Callable, additional_data: Variant = null, data_to_pass_through: Variant = null) -> void:

	var worker: RequestWorker
	if num_workers_available > 0:
		worker = workers_available.pop_back()
	else:
		worker = _spawn_worker()
	worker.FEAGI_call(full_request_address, method, function_to_respond_to_FEAGI, additional_data, data_to_pass_through)
	

## Spawns a RequestWorker
func _spawn_worker() -> RequestWorker:
	return RequestWorker.new(_multithreading_enabled, self, feagi_outgoing_headers, _request_worker_parent)


## Spawns initial RequestWorkers
func _spawn_initial_workers() -> void:
	for i in num_workers_to_keep_available:
		workers_available.append(_spawn_worker())


## Prints connection information to log
func _log_connection_address() -> void:
	print("Using FEAGI address " + feagi_root_web_address)

## Prints Websocket connection information to log
func _log_socket_address() -> void:
	print("Using FEAGI websocket address " + feagi_socket_address)

## responsible for polling state of websocket, since its not event driven
func socket_status_poll() -> void:
	_socket.poll()
	match _get_socket_state():
		WebSocketPeer.STATE_OPEN:
			while _socket.get_available_packet_count():
				_cache_websocket_data = _socket.get_packet().decompress(DEF_SOCKET_BUFFER_SIZE, 1)
				if _cache_websocket_data.get_string_from_utf8() == SOCKET_GENOME_UPDATE_FLAG: # This isn't particuarly efficient. Too bad!
					FeagiEvents.genome_was_reset.emit()  # notify that genome was updated
				else:
					# assume its visualization data
					FeagiEvents.retrieved_visualization_data.emit(str_to_var(_cache_websocket_data.get_string_from_ascii()))
		
		WebSocketPeer.STATE_CLOSED:
			var close_code: int = _socket.get_close_code()
			var close_reason: String = _socket.get_close_reason()
			_cache_websocket_data = _socket.get_packet().decompress(DEF_SOCKET_BUFFER_SIZE, 1)
			FeagiEvents.retrieved_visualization_data.emit(str_to_var(_cache_websocket_data.get_string_from_ascii())) # Add to erase neurons
			push_warning("WebSocket closed with code: %d, reason %s. Clean: %s" % [close_code, close_reason, close_code != -1])

## Queries and returns the current socket state. If its changed, updates the cached state and emits a signal of so
func _get_socket_state() -> WebSocketPeer.State:
	var new_state: WebSocketPeer.State = _socket.get_ready_state()
	if new_state == current_websocket_state:
		## no change, doesn't matter which we return
		return new_state
	socket_state_changed.emit(new_state)
	current_websocket_state = new_state
	return new_state
