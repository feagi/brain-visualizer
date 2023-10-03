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
const SOCKET_GENEOME_UPDATE_LATENCY: String = "ping"

signal socket_state_changed(state: WebSocketPeer.State)

var num_request_workers_available: int:
	get: return request_workers_available.size()

var current_websocket_status: WebSocketPeer.State:
	get: return _get_socket_state()

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
var request_workers_available: Array[RequestWorker]
var current_websocket_state: WebSocketPeer.State


var _request_worker_parent: Node
var _socket: WebSocketPeer
var _cache_websocket_data: PackedByteArray
var _request_worker_prefab: PackedScene = preload("res://Feagi-Godot-Interface/Core/Networking/Workers/SingleCallWorker.tscn")

## Used to init the network interface
## Required before usage
func init_network(worker_parent_root: Node) -> void:
	var ip_result = JavaScriptBridge.eval(""" 
		function getIPAddress() {
			var url_string = window.location.href;
			var url = new URL(url_string);
			const searchParams = new URLSearchParams(url.search);
			const ipAddress = searchParams.get("ip_address");
			return ipAddress;
		}
		getIPAddress();
		""")
	var port_disabled = JavaScriptBridge.eval(""" 
		function get_port() {
			var url_string = window.location.href;
			var url = new URL(url_string);
			const searchParams = new URLSearchParams(url.search);
			const ipAddress = searchParams.get("port_disabled");
			return ipAddress;
		}
		get_port();
		""")
	var websocket_url = JavaScriptBridge.eval(""" 
		function get_port() {
			var url_string = window.location.href;
			var url = new URL(url_string);
			const searchParams = new URLSearchParams(url.search);
			const ipAddress = searchParams.get("websocket_url");
			return ipAddress;
		}
		get_port();
		""")
	var http_type = JavaScriptBridge.eval(""" 
		function get_port() {
			var url_string = window.location.href;
			var url = new URL(url_string);
			const searchParams = new URLSearchParams(url.search);
			const ipAddress = searchParams.get("http_type");
			return ipAddress;
		}
		get_port();
		""")
	if http_type != null:
		feagi_SSL = http_type
	else:
		feagi_SSL= DEF_FEAGI_SSL
	if ip_result != null:
		feagi_TLD = ip_result
	else:
		feagi_TLD = DEF_FEAGI_TLD
	feagi_web_port = DEF_WEB_PORT
	feagi_socket_port = DEF_SOCKET_PORT
	feagi_socket_SSL = DEF_SOCKET_SSL
	feagi_outgoing_headers = DEF_HEADERSTOUSE
	num_workers_to_keep_available = DEF_MINWORKERSAVAILABLE


	# With collected data, init API
	_request_worker_parent = worker_parent_root
	if port_disabled != null:
		if port_disabled.to_lower() == "true":
			feagi_root_web_address = feagi_SSL + feagi_TLD
		else:
			feagi_root_web_address = feagi_SSL + feagi_TLD + ":" + str(feagi_web_port)
	else:
		feagi_root_web_address = feagi_SSL + feagi_TLD + ":" + str(feagi_web_port)

	endpoints = AddressList.new(feagi_root_web_address)
	_spawn_initial_workers()
	_log_connection_address()

	# init WebSocket
	if websocket_url != null:
		feagi_socket_address = websocket_url
	else:
		feagi_socket_address = feagi_socket_SSL + feagi_TLD + ":" + str(feagi_socket_port)
	_log_socket_address()
	_socket = WebSocketPeer.new()
	_socket.connect_to_url(feagi_socket_address)
	_socket.inbound_buffer_size = 1000000
	current_websocket_state = WebSocketPeer.STATE_CONNECTING

func single_FEAGI_request(full_request_address: StringName, call_method: HTTPClient.Method, function_to_respond_to_FEAGI: Callable, 
	additional_data: Variant = null, data_to_pass_through: Variant = null):

	var worker: RequestWorker = _grab_worker()
	worker.single_call(full_request_address, call_method, function_to_respond_to_FEAGI, additional_data, data_to_pass_through)

func polling_FEAGI_request(full_request_address: StringName, method: HTTPClient.Method, follow_up_function: Callable,
	polling_check: PollingMethodInterface, additional_data_to_send: Variant = null, 
	data_to_buffer: Variant = null, polling_gap_seconds: float = 0.5, mid_poll_call: Callable = Callable()) -> void:

	var worker: RequestWorker = _grab_worker()
	worker.polling_call(full_request_address, method, follow_up_function, polling_check, additional_data_to_send, data_to_buffer, polling_gap_seconds, mid_poll_call)


## attempts to send data over websocket
func websocket_send(data: Variant) -> void:
	if current_websocket_state != WebSocketPeer.STATE_OPEN:
		push_warning("Unable to send data to closed socket!")
		return
	_socket.send((data.to_ascii_buffer()).compress(1))


## Grabs either an available [RequestWorker] (or if none are available, spawns one first)
func _grab_worker() -> RequestWorker:
	var worker: RequestWorker
	if num_request_workers_available > 0:
		worker = request_workers_available.pop_back()
	else:
		worker = _spawn_worker()
	return worker
	

## Spawns a RequestWorker
func _spawn_worker() -> RequestWorker:
	var worker: RequestWorker = _request_worker_prefab.instantiate()
	worker.initialization(self, DEF_HEADERSTOUSE, _request_worker_parent)
	return worker


## Spawns initial RequestWorkers
func _spawn_initial_workers() -> void:
	for i in num_workers_to_keep_available:
		request_workers_available.append(_spawn_worker())


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
					print("FEAGI: Genome is being reset!")
					FeagiRequests.hard_reset_genome_from_FEAGI()  # notify that genome was updated
				elif _cache_websocket_data.get_string_from_utf8() == SOCKET_GENEOME_UPDATE_LATENCY:
					FeagiEvents.retrieved_latest_ping.emit(Time.get_ticks_msec())
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
