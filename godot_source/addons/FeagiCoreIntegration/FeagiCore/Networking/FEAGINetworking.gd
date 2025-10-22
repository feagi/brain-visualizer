extends Node
class_name FEAGINetworking
## Handles All Networking to and from FEAGI

# NOTE: For most signals, get them from http_API and websocket_API directly, no need for duplicates

enum CONNECTION_STATE {
	DISCONNECTED,
	INITIAL_HTTP_PROBING,
	INITIAL_WS_PROBING,
	HEALTHY,
	RETRYING_HTTP,
	RETRYING_WS,
	RETRYING_HTTP_WS
}

signal connection_state_changed(prev_state: CONNECTION_STATE, current_state: CONNECTION_STATE)
signal genome_reset_request_recieved()


var http_API: FEAGIHTTPAPI = null
var websocket_API: FEAGIWebSocketAPI = null
var connection_state: CONNECTION_STATE:
	get: return _connection_state

var _connection_state: CONNECTION_STATE = CONNECTION_STATE.DISCONNECTED

func _init():
	http_API = FEAGIHTTPAPI.new()
	http_API.name = "FEAGIHTTPAPI"
	add_child(http_API)

	websocket_API = FEAGIWebSocketAPI.new()
	websocket_API.name = "FEAGIWebSocketAPI"
	websocket_API.process_mode = Node.PROCESS_MODE_DISABLED
	websocket_API.feagi_requesting_reset.connect(func() : genome_reset_request_recieved.emit())
	add_child(websocket_API)

## Used to validate if a potential connection to FEAGI would be viable. Activates [FEAGIHTTPAPI] to do a healthcheck to verify.
## If viable, proceeds with connection. Returns if sucessful
func attempt_connection(feagi_endpoint_details: FeagiEndpointDetails) -> bool:
	if _connection_state != CONNECTION_STATE.DISCONNECTED:
		push_error("FEAGI NETWORK: Unable to commence a new connection when one is active in some form already!")
		return false
	
	# We dont want prior connections from HTTP or WS to set off other code paths, remove signal connections
	if http_API.FEAGI_http_health_changed.is_connected(_HTTP_health_changed):
		http_API.FEAGI_http_health_changed.disconnect(_HTTP_health_changed)
	if websocket_API.FEAGI_socket_health_changed.is_connected(_WS_health_changed):
		websocket_API.FEAGI_socket_health_changed.disconnect(_WS_health_changed)
	
	print("FEAGI NETWORK: Attempting to load new connection...")
	
	# Check HTTP connectivity
	_connection_state = CONNECTION_STATE.INITIAL_HTTP_PROBING
	connection_state_changed.emit(CONNECTION_STATE.DISCONNECTED,  CONNECTION_STATE.INITIAL_HTTP_PROBING)
	print("FEAGI NETWORK: Testing HTTP endpoint at %s" % feagi_endpoint_details.full_http_address)
	http_API.setup(feagi_endpoint_details.full_http_address, feagi_endpoint_details.header)
	http_API.confirm_connectivity() # NOTE: confirm_connectivity will never allow its health to be set as retrying, so we dont neet to worry about that
	
	await http_API.FEAGI_http_health_changed
	
	if http_API.http_health in [http_API.HTTP_HEALTH.NO_CONNECTION, http_API.HTTP_HEALTH.ERROR]:
		_connection_state = CONNECTION_STATE.DISCONNECTED
		connection_state_changed.emit(CONNECTION_STATE.INITIAL_HTTP_PROBING, CONNECTION_STATE.DISCONNECTED)
		push_error("FEAGI NETWORK: Unable to commence a new connection as there was no HTTP response at endpoint %s" % feagi_endpoint_details.full_http_address)
		return false
	
	# Check Websocket connectivity
	_connection_state = CONNECTION_STATE.INITIAL_WS_PROBING
	connection_state_changed.emit(CONNECTION_STATE.INITIAL_HTTP_PROBING,  CONNECTION_STATE.INITIAL_WS_PROBING)
	print("FEAGI NETWORK: Testing WS endpoint at %s" % feagi_endpoint_details.full_websocket_address)
	websocket_API.setup(feagi_endpoint_details.full_websocket_address)
	websocket_API.process_mode = Node.PROCESS_MODE_INHERIT
	websocket_API.connect_websocket()
	
	# NOTE: Since websocket startup can have its health set to retrying, we stay in a loop until we get a sucess or failure
	while true:
		await websocket_API.FEAGI_socket_health_changed
		if websocket_API.socket_health != websocket_API.WEBSOCKET_HEALTH.RETRYING:
			break
	
	if websocket_API.socket_health == websocket_API.WEBSOCKET_HEALTH.NO_CONNECTION:
		_connection_state = CONNECTION_STATE.DISCONNECTED
		http_API.disconnect_http() # HTTP is active, so lets ensure its disabled
		connection_state_changed.emit(CONNECTION_STATE.INITIAL_WS_PROBING, CONNECTION_STATE.DISCONNECTED)
		push_error("FEAGI NETWORK: Unable to commence a new connection as there was no WS response at endpoint %s" % feagi_endpoint_details.full_websocket_address)
		return false
	
	# both HTTP and WS are functioning! We ae good to go!
	# connect signals for future changes
	#http_API.FEAGI_http_health_changed.connect(_HTTP_health_changed)
	websocket_API.FEAGI_socket_health_changed.connect(_WS_health_changed)
	
	return true
	
## Completely disconnect all networking systems from FEAGI
func disconnect_networking() -> void:
	# NOTE: Signals will NOT be firing for these for their changing states
	_change_connection_state(CONNECTION_STATE.DISCONNECTED)


func _HTTP_health_changed(_prev_health: FEAGIHTTPAPI.HTTP_HEALTH, current_health: FEAGIHTTPAPI.HTTP_HEALTH) -> void:
	match current_health:
		FEAGIHTTPAPI.HTTP_HEALTH.NO_CONNECTION:
			# Only relevant time this fires is if a retrying worker fails to recover
			# NOTE: Technically also if on "confirm_connectivity" we time out, however the signal to this method is not active during that time
			# Ergo, only path to this is from HTTP_HEALTH.RETRYING
			_change_connection_state(CONNECTION_STATE.DISCONNECTED)
		
		FEAGIHTTPAPI.HTTP_HEALTH.ERROR:
			# NOTE: Not possible to get this since this is only fired during "confirm_connectivity"
			push_error("FEAGI NETWORK: Impossible condition HTTPERROR. Please report this issue if you see it!")
		
		FEAGIHTTPAPI.HTTP_HEALTH.CONNECTABLE:
			# Besides during "confirm_connectivity" (which is never connected to this), this only comes from a retrying worker recovering
			# Only path to this is from HTTP_HEALTH.RETRYING
			_change_connection_state(CONNECTION_STATE.HEALTHY)
		
		FEAGIHTTPAPI.HTTP_HEALTH.RETRYING:
			# Only path to this is from HTTP_HEALTH.CONNECTABLE
			_change_connection_state(CONNECTION_STATE.RETRYING_HTTP)


func _WS_health_changed(_previous_health: FEAGIWebSocketAPI.WEBSOCKET_HEALTH, current_health: FEAGIWebSocketAPI.WEBSOCKET_HEALTH) -> void:
	match current_health:
		FEAGIWebSocketAPI.WEBSOCKET_HEALTH.NO_CONNECTION:
			# Only path to this is from WEBSOCKET_HEALTH.RETRYING (again, "confirm_connectivity" has this method disconnected)
			_change_connection_state(CONNECTION_STATE.DISCONNECTED)
		
		FEAGIWebSocketAPI.WEBSOCKET_HEALTH.CONNECTED:
			# Only path to this is from WEBSOCKET_HEALTH.RETRYING (again, "confirm_connectivity" has this method disconnected)
			_change_connection_state(CONNECTION_STATE.HEALTHY)
		
		FEAGIWebSocketAPI.WEBSOCKET_HEALTH.RETRYING:
			 # Only path to this is from WEBSOCKET_HEALTH.CONNECTED
			_change_connection_state(CONNECTION_STATE.RETRYING_WS)


func _change_connection_state(new_state: CONNECTION_STATE) -> void:
	var prev_state: CONNECTION_STATE = _connection_state
	# NOTE: Due to WS and HTTP possibly failing/recovering at similar times, we may do some silly things between switching from 1 or both them failing in the enum value
	var scanning_state: CONNECTION_STATE = new_state # NOTE: Since we may manipulate new_state, we dont want to mess up the match case
	match(scanning_state):
		CONNECTION_STATE.DISCONNECTED:
			# Either user requested this or something failed
			# Ensure everything is disconnected
			# NOTE: These APIs will not emit disconnection signals from this
			http_API.disconnect_http()
			websocket_API.disconnect_websocket()
		CONNECTION_STATE.INITIAL_HTTP_PROBING: # not possible:
			return
		CONNECTION_STATE.INITIAL_WS_PROBING: # not possible:
			return
		CONNECTION_STATE.HEALTHY:
			if prev_state == CONNECTION_STATE.RETRYING_HTTP_WS: # 2 things were broken, one got fixed
				if http_API.http_health != FEAGIHTTPAPI.HTTP_HEALTH.CONNECTABLE:
					new_state = CONNECTION_STATE.RETRYING_HTTP
				elif websocket_API.socket_health != FEAGIWebSocketAPI.WEBSOCKET_HEALTH.CONNECTED:
					new_state = CONNECTION_STATE.RETRYING_WS
		CONNECTION_STATE.RETRYING_HTTP:
			if prev_state == CONNECTION_STATE.RETRYING_WS: # are both actually broken?
				new_state = CONNECTION_STATE.RETRYING_HTTP_WS
		CONNECTION_STATE.RETRYING_WS:
			if prev_state == CONNECTION_STATE.RETRYING_HTTP: # are both actually broken?
				new_state = CONNECTION_STATE.RETRYING_HTTP_WS
	
	_connection_state = new_state
	connection_state_changed.emit(prev_state, new_state)
