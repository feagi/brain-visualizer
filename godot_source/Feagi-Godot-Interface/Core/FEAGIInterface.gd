extends Node
## Holds all objects responsible for communicating to and recieving data from FEAGI directly
class_name FEAGIInterface

var net: NetworkInterface
var calls: CallList

var _response_calls: ResponseProxyFunctions


func _init():
	net = NetworkInterface.new()
	net.init_network(self) # Grabs addresses and initializes connection details
	_response_calls = ResponseProxyFunctions.new()
	calls = CallList.new(net, _response_calls)

func _ready():
	FeagiRequests._feagi_interface = self
	FeagiRequests.refresh_morphology_list()
