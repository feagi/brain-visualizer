extends Object
class_name FEAGISocket


const DEF_SOCKET_MAX_QUEUED_PACKETS: int = 10000000
const DEF_SOCKET_INBOUND_BUFFER_SIZE: int = 10000000
const DEF_SOCKET_BUFFER_SIZE: int = 10000000
const SOCKET_GENOME_UPDATE_FLAG: String = "updated" # FEAGI sends this string via websocket if genome is reloaded / changed
const SOCKET_GENEOME_UPDATE_LATENCY: String = "ping"

signal socket_state_changed(state: WebSocketPeer.State)
signal feagi_return_ping()

var websocket_state: WebSocketPeer.State:
	get: return _websocket_state

var _websocket_state: WebSocketPeer.State
var _cache_websocket_data: PackedByteArray
var _socket: WebSocketPeer

func _init(feagi_socket_address: StringName) -> void:
	_socket =  WebSocketPeer.new()
	_socket.connect_to_url(feagi_socket_address)
	_socket.inbound_buffer_size = DEF_SOCKET_INBOUND_BUFFER_SIZE

func send_websocket_ping() -> void:
	websocket_send("ping")

## attempts to send data over websocket
func websocket_send(data: Variant) -> void:
	if _websocket_state != WebSocketPeer.STATE_OPEN:
		push_warning("Unable to send data to closed socket!")
		return
	_socket.send((data.to_ascii_buffer()).compress(1))

## responsible for polling state of websocket, since its not event driven. This must be called by _process() of a node for this object to function
func socket_status_poll() -> void:
	_socket.poll()
	_refresh_socket_state()
	match _websocket_state:
		WebSocketPeer.STATE_OPEN:
			while _socket.get_available_packet_count():
				_cache_websocket_data = _socket.get_packet().decompress(DEF_SOCKET_BUFFER_SIZE, 1)
				if _cache_websocket_data.get_string_from_utf8() == SOCKET_GENOME_UPDATE_FLAG: # This isn't particuarly efficient. Too bad!
					print("FEAGI: Genome is being reset!")
					FeagiRequests.hard_reset_genome_from_FEAGI()  # notify that genome was updated
				elif _cache_websocket_data.get_string_from_utf8() == SOCKET_GENEOME_UPDATE_LATENCY:
					feagi_return_ping.emit()
				else:
					# assume its visualization data
					var temp = str_to_var(_cache_websocket_data.get_string_from_ascii())
					if temp ==  null: return
					FeagiEvents.retrieved_visualization_data.emit(str_to_var(_cache_websocket_data.get_string_from_ascii()))
		
		WebSocketPeer.STATE_CLOSED:
			var close_code: int = _socket.get_close_code()
			var close_reason: String = _socket.get_close_reason()
			_cache_websocket_data = _socket.get_packet().decompress(DEF_SOCKET_BUFFER_SIZE, 1)
			FeagiEvents.retrieved_visualization_data.emit(str_to_var(_cache_websocket_data.get_string_from_ascii())) # Add to erase neurons
			push_warning("WebSocket closed with code: %d, reason %s. Clean: %s" % [close_code, close_reason, close_code != -1])

func _refresh_socket_state() -> void:
	var new_state: WebSocketPeer.State = _socket.get_ready_state()
	if new_state == _websocket_state:
		## no change, doesn't matter which we return
		return
	_websocket_state = new_state
	socket_state_changed.emit(new_state)


