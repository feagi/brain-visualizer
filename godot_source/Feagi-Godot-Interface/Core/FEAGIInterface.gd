extends Node
## Holds all objects responsible for communicating to and recieving data from FEAGI directly
## NOT AUTOLOADED - since we need to interact with the tree, this is on the "FEAGIInterface" node
class_name FEAGIInterface


var calls: CallList

var _network_boostrap: NetworkBootStrap
var _http_worker_pool: APIRequestWorkerPool
var _FEAGI_websocket: FEAGISocket
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
	_http_worker_pool = APIRequestWorkerPool.new(_network_boostrap.feagi_root_web_address, _network_boostrap.DEF_HEADERSTOUSE, self)
	calls = CallList.new(_http_worker_pool, _response_calls)
	_response_calls = ResponseProxyFunctions.new()
	_FEAGI_websocket.new(_network_boostrap.feagi_socket_address)
	_FEAGI_websocket.socket_state_changed.connect(_socket_changed_state)

	FeagiRequests.poll_genome_availability_launch()

## Handles polling websocket
func _process(_delta):
	_FEAGI_websocket.socket_status_poll()

## triggered whenever websocket changes state
func _socket_changed_state(state: WebSocketPeer.State) -> void:
	if state == WebSocketPeer.STATE_CLOSED:
		set_process(false)


