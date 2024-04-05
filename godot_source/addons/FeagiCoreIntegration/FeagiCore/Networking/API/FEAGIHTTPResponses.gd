extends Object # Static so leave this as is
class_name FEAGIHTTPResponses
## The return functions for the callables in [FEAGIHTTPCallList]. 
#Note: All callables must be STATIC

#region Cortical Areas

## Gets Summary information for all cortical areas in current genome
static func GET_CorticalArea_Geometry(response_body: PackedByteArray, _irrelevant_data: Variant):
	var cortical_areas: Dictionary = FEAGIHTTPResponses.byte_array_to_dict(response_body)
	FeagiCore.feagi_local_cache.cortical_areas_cache.update_cortical_area_cache_from_summary(cortical_areas)
	FeagiCore.network.http_API.call_list.GET_CorticalMapDetailed()

## Gets summary information of how all cortical areas are mapped to each (including details of the morphology used)
static func GET_CorticalMapDetailed(response_body: PackedByteArray, _irrelevant_data: Variant):
	pass

#endregion



#region SYSTEM



	
## Special version of the health check function used for validating if feagi is active and working, used for feagi connection attempt
static func GET_healthCheck_FEAGI_VALIDATION(response_body: PackedByteArray, _irrelevant_data: Variant):
	var health_data: Dictionary = FEAGIHTTPResponses.byte_array_to_dict(response_body)
	if !FEAGIHTTPResponses.does_dict_contain_keys(health_data, ["genome_availability"]):
		# if we are missing this key, something is wrong
		FeagiCore.network.http_API.FEAGI_healthcheck_responded(FEAGIHTTPAPI.HTTP_HEALTH.ERROR)
		return
	FeagiCore.feagi_local_cache.update_health_from_FEAGI_dict(health_data) # Notably, will update here if genome is available or not
	FeagiCore.network.http_API.FEAGI_healthcheck_responded(FEAGIHTTPAPI.HTTP_HEALTH.CONNECTABLE)
	
## FEAGI returned an HTTP error
static func GET_healthCheck_FEAGI_VALIDATION_ERROR(_response_body: PackedByteArray, _request_definition: APIRequestWorkerDefinition):
	FeagiCore.network.http_API.FEAGI_healthcheck_responded(FEAGIHTTPAPI.HTTP_HEALTH.ERROR)

## FEAGI doesnt seem to be running at all
static func GET_healthCheck_FEAGI_VALIDATION_UNRESPONSIVE(_request_definition: APIRequestWorkerDefinition):
	FeagiCore.network.http_API.FEAGI_healthcheck_responded(FEAGIHTTPAPI.HTTP_HEALTH.NO_CONNECTION)
	
#endregion




#region godot_internal
# These functions are used for internal processing here

static func byte_array_to_dict(bytes: PackedByteArray) -> Dictionary:
	var string: String = bytes.get_string_from_utf8()
	if string == "":
		return {}
	var dict =  JSON.parse_string(string)
	if dict is Dictionary:
		return dict
	return {}

static func does_dict_contain_keys(dict: Dictionary, keys: Array) -> bool:
	for key in keys:
		if !(dict.has(key)):
			return false
	return true

#endregion
