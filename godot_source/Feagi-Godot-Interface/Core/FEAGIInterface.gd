extends Node
## Holds all objects responsible for communicating to and recieving data from FEAGI directly
## NOT AUTOLOADED - since we need to interact with the tree, this is on the "FEAGIInterface" node
class_name FEAGIInterface

var net: NetworkInterface
var calls: CallList

var _response_calls: ResponseProxyFunctions


func _init():
	# Init Network Objects
	net = NetworkInterface.new()
	net.init_network(self) # Grabs addresses and initializes connection details
	_response_calls = ResponseProxyFunctions.new()
	calls = CallList.new(net, _response_calls)
	FeagiRequests._feagi_interface = self

## Runs after _init
func _ready():
	_initial_FEAGI_calls()
	net.socket_state_changed.connect(_socket_changed_state)

## mainly handles polling websocket
func _process(_delta):
	net.socket_status_poll()

## Calls to be made to FEAGI following initialization
## Put any calls here that need to be made for initial summary data to spawn initial UI elements
func _initial_FEAGI_calls() -> void:
	FeagiRequests.refresh_morphology_list()
	FeagiRequests.refresh_cortical_areas()



## triggered whenever websocket changes state
func _socket_changed_state(state: WebSocketPeer.State) -> void:
	if state == WebSocketPeer.STATE_CLOSED:
		set_process(false)


