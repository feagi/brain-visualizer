extends RefCounted
class_name FEAGIHTTPCallList
## Callables from godot to make HTTP requests to FEAGI

signal initiate_call_to_FEAGI(request_definition: APIRequestWorkerDefinition) ## Connected to [FEAGIHTTPAPI], used to relay all requests to it

var _address_list: FEAGIHTTPAddressList

func _init(feagi_root_web_address: StringName):
	_address_list = FEAGIHTTPAddressList.new(feagi_root_web_address)

#region Cortical Areas

## Gets Summary information for all cortical areas in current genome, calls GET_CorticalMapDetailed upon success
func GET_CorticalArea_Geometry():
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(
		_address_list.GET_corticalArea_corticalArea_geometry,
		FEAGIHTTPResponses.GET_CorticalArea_Geometry
	)
	initiate_call_to_FEAGI.emit(request)

## Gets summary information of how all cortical areas are mapped to each (including details of the morphology used)
func GET_CorticalMapDetailed():
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(
		_address_list.GET_corticalArea_corticalMapDetailed,
		FEAGIHTTPResponses.GET_CorticalMapDetailed
	)
	initiate_call_to_FEAGI.emit(request)

#endregion



#region SYSTEM

# A custom version of the GET_healthCheck, meant for validating if FEAGI is connectable and healthy on godot launch
func GET_healthCheck_FEAGI_VALIDATION():
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(
		_address_list.GET_system_healthCheck,
		FEAGIHTTPResponses.GET_healthCheck_FEAGI_VALIDATION
	)
	request.http_error_call = FEAGIHTTPResponses.GET_healthCheck_FEAGI_VALIDATION_ERROR
	request.http_unresponsive_call = FEAGIHTTPResponses.GET_healthCheck_FEAGI_VALIDATION_UNRESPONSIVE
	initiate_call_to_FEAGI.emit(request)



#endregion
