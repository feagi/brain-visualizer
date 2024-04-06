extends Object
class_name FEAGIHTTPCallList
## Static Callables from godot to make HTTP requests to FEAGI

#WARNING: Calling any function here when HTTP (and thus addres list) is not initialized will cause a crash!

#region Cortical Areas

## Gets Summary information for all cortical areas in current genome, calls GET_CorticalMapDetailed upon success
static func GET_CorticalArea_Geometry() -> APIRequestWorkerDefinition:
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(
		FeagiCore.network.http_API.address_list.GET_corticalArea_corticalArea_geometry,
	)
	return request

## Gets summary information of how all cortical areas are mapped to each (including details of the morphology used)
static func GET_CorticalMapDetailed() -> APIRequestWorkerDefinition:
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(
		FeagiCore.network.http_API.address_list.GET_corticalArea_corticalMapDetailed,
	)
	return request

#endregion



#region SYSTEM

# A custom version of the GET_healthCheck, meant for validating if FEAGI is connectable and healthy on godot launch
static func GET_healthCheck_FEAGI_VALIDATION() -> APIRequestWorkerDefinition:
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(
		FeagiCore.network.http_API.address_list.GET_system_healthCheck,
	)
	return request


#endregion

