extends Node
## Holds all objects responsible for communicating to and recieving data from FEAGI directly
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
	initial_FEAGI_calls()


## Calls to be made to FEAGI following initialization
## Put any calls here that need to be made for initial summary data to spawn initial UI elements
func initial_FEAGI_calls() -> void:
	FeagiRequests.refresh_morphology_list()