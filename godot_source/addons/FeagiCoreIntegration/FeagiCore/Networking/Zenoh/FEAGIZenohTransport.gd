extends Node
class_name FEAGIZenohTransport
## Data stream transport for feagi-core servers, over zenoh websocket through the FeagiZenohClient
## extension. Used when the legacy WebSocket agent cannot connect.
##
## There is no heartbeat. BV announces itself with a liveliness token for as long as it is
## connected, and the server counts as up for as long as its own token is seen.

enum ZENOH_HEALTH {
	NO_CONNECTION,
	CONNECTED,
	RETRYING
}

## Port feagi-core's designer brain server serves zenoh websocket on
const DEFAULT_ZENOH_PORT: int = 7446
## How long connecting may take, including the server's token first being seen
const CONNECT_TIMEOUT_SECONDS: float = 15.0
## How long the server's token may be gone before the connection is given up on
const SERVER_LOSS_TIMEOUT_SECONDS: float = 10.0

signal zenoh_health_changed(previous_health: ZENOH_HEALTH, current_health: ZENOH_HEALTH)
## Fired once per connect_zenoh(), when it either connected or gave up
signal connect_attempt_finished(success: bool)

var health: ZENOH_HEALTH:
	get: return _health
## Error of the last failed connect, empty otherwise
var last_error: String:
	get: return _last_error

## Receives every visualization packet this transport delivers. Set by [FEAGINetworking].
var visualization_sink: FEAGIVisualizationSink = null

var _client: RefCounted = null
var _health: ZENOH_HEALTH = ZENOH_HEALTH.NO_CONNECTION
var _last_error: String = ""
var _is_connecting: bool = false
var _connect_started_ms: int = 0
var _server_missing_since_ms: int = 0


func _init() -> void:
	set_process(false)


## Whether the FeagiZenohClient extension is loaded
static func is_available() -> bool:
	return ClassDB.class_exists("FeagiZenohClient")


## The zenoh websocket address of the FEAGI at [param full_http_address]: its host on
## [constant DEFAULT_ZENOH_PORT]. The FEAGI_ZENOH_ENDPOINT environment variable overrides it.
static func resolve_server_address(full_http_address: String) -> String:
	var configured := OS.get_environment("FEAGI_ZENOH_ENDPOINT").strip_edges()
	if configured != "":
		return configured
	var host := full_http_address.strip_edges()
	for scheme in ["https://", "http://"]:
		if host.begins_with(scheme):
			host = host.substr(scheme.length())
	host = host.get_slice("/", 0)
	if host.begins_with("["):
		host = host.get_slice("]", 0) + "]" # IPv6, keep the brackets
	else:
		host = host.get_slice(":", 0)
	if host == "":
		host = "127.0.0.1"
	return "%s:%d" % [host, DEFAULT_ZENOH_PORT]


## Starts connecting to [param server_address]. [signal connect_attempt_finished] fires with the
## outcome. Packets on the FEAGI_ZENOH_VISUALIZATION_KEY key expression, if set, go to the sink.
func connect_zenoh(server_address: String) -> void:
	disconnect_zenoh()
	_last_error = ""
	if not is_available():
		_finish_connect_attempt(false, "FeagiZenohClient extension unavailable")
		return
	_client = ClassDB.instantiate("FeagiZenohClient")
	if _client == null:
		_finish_connect_attempt(false, "Failed to instantiate FeagiZenohClient")
		return
	var visualization_key := OS.get_environment("FEAGI_ZENOH_VISUALIZATION_KEY").strip_edges()
	if not _client.connect_zenoh(server_address, visualization_key):
		_finish_connect_attempt(false, str(_client.poll_state().get("error", "connect refused")))
		return
	_is_connecting = true
	_connect_started_ms = Time.get_ticks_msec()
	set_process(true)


## Connects, and waits until connected or given up on. Returns whether it connected.
func connect_and_wait(server_address: String) -> bool:
	connect_zenoh(server_address)
	if not _is_connecting:
		return _health == ZENOH_HEALTH.CONNECTED
	return await connect_attempt_finished


## Leaves the network. Does not fire [signal zenoh_health_changed], like the WebSocket API.
func disconnect_zenoh() -> void:
	set_process(false)
	_is_connecting = false
	_server_missing_since_ms = 0
	_health = ZENOH_HEALTH.NO_CONNECTION
	if _client != null:
		_client.disconnect_zenoh()
		_client = null


func _process(_delta: float) -> void:
	if _client == null:
		set_process(false)
		return
	var status: Dictionary = _client.poll_state()
	var state: String = str(status.get("state", "idle"))
	var now_ms := Time.get_ticks_msec()

	if _is_connecting:
		match state:
			"connected":
				_set_health(ZENOH_HEALTH.CONNECTED)
				_finish_connect_attempt(true, "")
			"failed":
				_give_up(str(status.get("error", "unknown zenoh error")))
			_:
				# Still opening the session, or waiting for the server's token to arrive
				if now_ms - _connect_started_ms > int(CONNECT_TIMEOUT_SECONDS * 1000.0):
					_give_up("No FEAGI server token seen within %.0fs (state %s)" % [CONNECT_TIMEOUT_SECONDS, state])
		return

	match state:
		"connected":
			_server_missing_since_ms = 0
			_set_health(ZENOH_HEALTH.CONNECTED)
			var packet: PackedByteArray = _client.take_visualization_packet()
			if packet.size() > 0 and visualization_sink != null:
				visualization_sink.ingest_packet(packet)
		"waiting_for_server":
			# The server's token is gone (it stopped, or the link dropped). zenoh reconnects on its own
			if _server_missing_since_ms == 0:
				_server_missing_since_ms = now_ms
				print("[ZENOH] FEAGI server token gone - waiting up to %.0fs for it to return" % SERVER_LOSS_TIMEOUT_SECONDS)
			_set_health(ZENOH_HEALTH.RETRYING)
			if now_ms - _server_missing_since_ms > int(SERVER_LOSS_TIMEOUT_SECONDS * 1000.0):
				_give_up("FEAGI server token gone for over %.0fs" % SERVER_LOSS_TIMEOUT_SECONDS)
		_:
			_give_up(str(status.get("error", "zenoh connection lost (state %s)" % state)))


func _give_up(error: String) -> void:
	var was_connecting := _is_connecting
	if _client != null:
		_client.disconnect_zenoh()
		_client = null
	set_process(false)
	_server_missing_since_ms = 0
	if was_connecting:
		_health = ZENOH_HEALTH.NO_CONNECTION
		_finish_connect_attempt(false, error)
	else:
		_last_error = error
		push_warning("[ZENOH] %s" % error)
		_set_health(ZENOH_HEALTH.NO_CONNECTION)


func _finish_connect_attempt(success: bool, error: String) -> void:
	_is_connecting = false
	_last_error = error
	if not success:
		push_warning("[ZENOH] Connect failed: %s" % error)
	connect_attempt_finished.emit(success)


func _set_health(new_health: ZENOH_HEALTH) -> void:
	var prev_health := _health
	if prev_health == new_health:
		return
	_health = new_health
	zenoh_health_changed.emit(prev_health, new_health)
