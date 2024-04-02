extends RefCounted
class_name FEAGIHTTPCallList
## Callables from godot to make HTTP requests to FEAGI

signal initiate_call_to_FEAGI(request_definition: APIRequestWorkerDefinition)

var _address_list: FEAGIHTTPAddressList

func _init(feagi_root_web_address: StringName, response_functions: FEAGIHTTPResponses):
	_address_list = FEAGIHTTPAddressList.new(feagi_root_web_address)


#region SYSTEM

## returns dict of various feagi health stats
func GET_healthCheck(response_function: Callable = FEAGIHTTPResponses.GET_healthCheck):
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(
		_address_list.GET_system_healthCheck,
		response_function
	)
	initiate_call_to_FEAGI.emit(request)




#endregion
