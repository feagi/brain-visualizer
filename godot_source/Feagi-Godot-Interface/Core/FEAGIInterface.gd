extends Node
## Holds all objects responsible for communicating to and recieving data from FEAGI directly
## NOT AUTOLOADED - since we need to interact with the tree, this is on the "FEAGIInterface" node
class_name FEAGIInterface


var calls: CallList
var FEAGI_websocket: FEAGISocket
var FEAGI_RTC: FEAGIRTC

var _network_boostrap: NetworkBootStrap
var _http_worker_pool: APIRequestWorkerPool
var _response_calls: ResponseProxyFunctions

## First stage network intialization
func _ready():
	# Init Network Objects
	FeagiRequests._feagi_interface = self # hacky, but sets the interface reference of the [FeagiRequests] autoload to this non-autoloaded node
	# boostrap network properties, gets the URL / port of FEAGI
	_network_boostrap = NetworkBootStrap.new()
	_network_boostrap.base_network_initialization_completed.connect(second_stage_network_initialization)
	_network_boostrap.init_network() ## Retrieves what the URL / ports are
	


func second_stage_network_initialization() -> void:
	var timer: Timer =  $PingTimer
	_http_worker_pool = APIRequestWorkerPool.new(_network_boostrap.feagi_root_web_address, _network_boostrap.DEF_HEADERSTOUSE, self)
	_response_calls = ResponseProxyFunctions.new()
	calls = CallList.new(_http_worker_pool, _response_calls, _network_boostrap.feagi_root_web_address)
	FEAGI_websocket = FEAGISocket.new(_network_boostrap.feagi_socket_address, timer)
	FEAGI_websocket.socket_state_changed.connect(_socket_changed_state)
	
	var stun_urls: Array[StringName] = []
	var turn_urls: Array[StringName] = []
	stun_urls.assign([_network_boostrap.DEF_FEAGI_TLD + ":" + str(_network_boostrap.DEF_RTC_PORT)])
	turn_urls.assign([_network_boostrap.DEF_FEAGI_TLD + ":" + str(_network_boostrap.DEF_RTC_PORT)])
	FEAGI_RTC = FEAGIRTC.new(stun_urls, turn_urls, _network_boostrap.DEF_RTC_LABEL, _network_boostrap.DEF_RTC_channel)
	

	FeagiRequests.poll_genome_availability_launch()

## Handles polling websocket
func _process(_delta):
	FEAGI_websocket.socket_status_poll()
	FEAGI_RTC.poll()

## triggered whenever websocket changes state
func _socket_changed_state(state: WebSocketPeer.State) -> void:
	#if state == WebSocketPeer.STATE_CLOSED:
	#	set_process(false)
	pass # come up with better logic later to better support rtc

func _physics_process(delta):
	FEAGI_RTC.send_data("Testing".to_utf8_buffer())


