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
	FeagiRequests.poll_genome_availability_launch()
	net.socket_state_changed.connect(_socket_changed_state)

## mainly handles polling websocket
func _process(_delta):
	net.socket_status_poll()

## triggered whenever websocket changes state
func _socket_changed_state(state: WebSocketPeer.State) -> void:
	if state == WebSocketPeer.STATE_CLOSED:
		set_process(false)


