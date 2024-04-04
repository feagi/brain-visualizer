extends Node
class_name FEAGIWebSocketAPI

const DEF_SOCKET_INBOUND_BUFFER_SIZE: int = 10000000
const DEF_SOCKET_BUFFER_SIZE: int = 10000000
const DEF_PING_INTERVAL_SECONDS: float = 2.0
const SOCKET_GENOME_UPDATE_FLAG: String = "updated" # FEAGI sends this string via websocket if genome is reloaded / changed
const SOCKET_GENEOME_UPDATE_LATENCY: String = "ping"

signal socket_state_changed(state: WebSocketPeer.State)
signal feagi_return_ping()
signal feagi_requesting_reset()
#TODO: As we move more functionality here, we need a generic event signal, or an equivilant to [FEAGIHTTPResponses]

var websocket_state: WebSocketPeer.State:
	get: return _socket.get_ready_state()

var _cache_websocket_data: PackedByteArray # outside to void reallocation penalties
var _socket: WebSocketPeer
var _socket_prev_state: WebSocketPeer.State = WebSocketPeer.State.STATE_CLOSED

func _process(delta: float):
	_socket.poll()
	_refresh_socket_state()
	match(_socket_prev_state):
		WebSocketPeer.State.STATE_CONNECTING:
			# Currently connecting to feagi, waiting for FEAGI to confirm
			pass
		WebSocketPeer.State.STATE_OPEN:
			# Connection active with FEAGI
			while _socket.get_available_packet_count():
				_cache_websocket_data = _socket.get_packet().decompress(DEF_SOCKET_BUFFER_SIZE, 1) # for some reason, using the enum instead of the number causes this break
				if _cache_websocket_data.get_string_from_utf8() == SOCKET_GENOME_UPDATE_FLAG: # This isn't particuarly efficient. Too bad!
					print("FEAGI Websocket: Recieved Request from FEAGI to reset genome!")
					feagi_requesting_reset.emit()
				elif _cache_websocket_data.get_string_from_utf8() == SOCKET_GENEOME_UPDATE_LATENCY:
					feagi_return_ping.emit()
				else:
					# assume its visualization data
					var temp = str_to_var(_cache_websocket_data.get_string_from_ascii())
					if temp ==  null:
						return
					# TODO send up data
					
					#FeagiEvents.retrieved_visualization_data.emit(str_to_var(_cache_websocket_data.get_string_from_ascii()))
		WebSocketPeer.State.STATE_CLOSING:
			# Closing connection to FEAGI, waiting for FEAGI to respond to close request
			pass
		WebSocketPeer.State.STATE_CLOSED:
			# Closed Connection to FEAGI
			var close_code: int = _socket.get_close_code()
			var close_reason: String = _socket.get_close_reason()
			if  _socket.get_available_packet_count() > 0:
				# There was some remenant data
				_cache_websocket_data = _socket.get_packet().decompress(DEF_SOCKET_BUFFER_SIZE, 1)
			#TODO FeagiEvents.retrieved_visualization_data.emit(str_to_var(_cache_websocket_data.get_string_from_ascii())) # Add to erase neurons
			push_warning("FEAGI Websocket: Closed with code: %d, reason %s. Clean: %s" % [close_code, close_reason, close_code != -1])
			set_process(false)

## Initializes and attempts to concect the websocket
func connect_websocket(feagi_socket_address: StringName) -> void:
	print("attempt connect")
	if _socket == null:
		_socket =  WebSocketPeer.new()
		_socket.inbound_buffer_size = DEF_SOCKET_INBOUND_BUFFER_SIZE
	_refresh_socket_state()
	if _socket_prev_state != WebSocketPeer.STATE_CLOSED:
		push_warning("FEAGI Websocket: Cannot initate a new connection when websocket is not closed!")
		return
	_socket.connect_to_url(feagi_socket_address)

## Force closes the socket. This does cause 'socket_state_changed' to fire
func disconnect_websocket() -> void:
	if _socket == null:
		return
	_socket.close()

## attempts to send data over websocket
func websocket_send(data: Variant) -> void:
	if _socket_prev_state != WebSocketPeer.STATE_OPEN:
		push_warning("FEAGI Websocket: Unable to send data to closed socket!")
		return
	_socket.send((data.to_ascii_buffer()).compress(1)) # for some reason, using the enum instead of the number causes this break

# attempts to send a ping over websocket
func send_websocket_ping() -> void:
	websocket_send(SOCKET_GENEOME_UPDATE_LATENCY)

func _refresh_socket_state() -> void:
	if _socket_prev_state == _socket.get_ready_state():
		## no change, doesn't matter which we return
		return
	_socket_prev_state = _socket.get_ready_state()
	print(_socket_prev_state)
	socket_state_changed.emit(_socket_prev_state)
