extends Node
class_name FEAGINetworking
## Handles All Networking to and from FEAGI

# NOTE: For most signals, get them from http_API and websocket_API directly, no need for duplicates

signal ping_recieved(time_sent_ms: int, time_recieved_ms: int)

var http_API: FEAGIHTTPAPI = null
var websocket_API: FEAGIWebSocketAPI = null

var _ping_timer: Timer = null
var _healthcheck_timer: Timer = null #TODO
var _ping_send_time_ms: int ## record of when ping was sent, ping recieve time is subtracted from this to find ping

func _init():
	http_API = FEAGIHTTPAPI.new()
	http_API.name = "FEAGIHTTPAPI"
	add_child(http_API)

	websocket_API = FEAGIWebSocketAPI.new()
	websocket_API.name = "FEAGIWebSocketAPI"
	websocket_API.process_mode = Node.PROCESS_MODE_DISABLED
	websocket_API.feagi_return_ping.connect(_on_return_ping)
	add_child(websocket_API)

# Used to validate if a potential connection to FEAGI would be viable. Activates [FEAGIHTTPAPI] to do a healthcheck to verify
func check_connection_to_FEAGI(feagi_endpoint_details: FeagiEndpointDetails):
	activate_http_API(feagi_endpoint_details.get_api_URL(), feagi_endpoint_details.header)
	http_API.call_list.GET_healthCheck_FEAGI_VALIDATION()

# Sets up (or resets) the HTTP API with required information
func activate_http_API(FEAGI_API_address: StringName, headers: PackedStringArray) -> void:
	http_API.connect_http(FEAGI_API_address, headers)

# Sets up (or resets) the Websocket API with required information
func activate_websocket_APT(FEAGI_websocket_address: StringName) -> void:
	websocket_API.process_mode = Node.PROCESS_MODE_INHERIT
	websocket_API.connect_websocket(FEAGI_websocket_address)

## Completely disconnect all networking systems from FEAGI
func disconnect_networking() -> void:
	# NOTE: Signals will be firing for these for their changing states
	http_API.disconnect_http()
	websocket_API.disconnect_websocket()
		

## Toggle if ping timer is active
func toggle_ping_timer(is_active: bool):
	if FeagiCore.feagi_settings == null:
		push_error("FEAGI NETWORKING: Unable to start ping timer before general settings loaded!")
		return

	if is_active:
		if _ping_timer ==  null:
			_ping_timer = Timer.new()
			add_child(_ping_timer)
			_ping_timer.one_shot = false
			_ping_timer.timeout.connect(_on_ping_timer)
		_ping_timer.wait_time = FeagiCore.feagi_settings.seconds_between_latency_pings
		_ping_timer.start()
	else:
		_ping_timer.queue_free()
		_ping_timer = null

func _on_ping_timer():
	if websocket_API.websocket_state != WebSocketPeer.STATE_OPEN:
		return
	_ping_send_time_ms = Time.get_ticks_msec()
	websocket_API.send_websocket_ping()

func _on_return_ping():
	ping_recieved.emit(_ping_send_time_ms, Time.get_ticks_msec())
