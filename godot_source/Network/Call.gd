extends Object
class_name Call
# Seperate script to hold actual network call functions through the networkAPI


var _net: SimpleNetworkAPI

func _init(networkAPIReference: SimpleNetworkAPI):
	_net = networkAPIReference

# TODO add error handling should network fail!
func GET(address: String, proxiedFunction, stringToAppend: String = ""):
	_net.Call(address + stringToAppend, HTTPClient.METHOD_GET, proxiedFunction)

func POST(address: String, proxiedFunction, data2Send):
	_net.Call(address, HTTPClient.METHOD_POST, proxiedFunction, data2Send)

func PUT(address: String, proxiedFunction, data2Send):
	_net.Call(address, HTTPClient.METHOD_PUT, proxiedFunction, data2Send)
	
func DELETE(address: String, proxiedFunction):
	_net.Call(address, HTTPClient.METHOD_DELETE, proxiedFunction)
