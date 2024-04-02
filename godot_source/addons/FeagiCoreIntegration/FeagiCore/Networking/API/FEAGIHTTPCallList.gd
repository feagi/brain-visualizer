extends RefCounted
class_name FEAGIHTTPCallList
## Callables from godot to make HTTP requests to FEAGI

signal initiate_call_to_FEAGI(request_definition: APIRequestWorkerDefinition)

var _address_list: FEAGIHTTPAddressList

func _init(feagi_root_web_address: StringName):
	_address_list = FEAGIHTTPAddressList.new(feagi_root_web_address)


#region SYSTEM

## returns dict of various feagi health stats
func GET_healthCheck():
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(
		_address_list.GET_system_healthCheck,
		FEAGIHTTPResponses.GET_healthCheck
	)
	initiate_call_to_FEAGI.emit(request)

# A custom version of the above, meant for validating if FEAGI is connectable and healthy on godot launch
func GET_healthCheck_FEAGI_VALIDATION():
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(
		_address_list.GET_system_healthCheck,
		FEAGIHTTPResponses.GET_healthCheck_FEAGI_VALIDATION
	)
	request.http_error_call = FEAGIHTTPResponses.GET_healthCheck_FEAGI_VALIDATION_ERROR
	request.http_unresponsive_call = FEAGIHTTPResponses.GET_healthCheck_FEAGI_VALIDATION_UNRESPONSIVE
	initiate_call_to_FEAGI.emit(request)



#endregion
