extends Object # Static so leave this as is
class_name FEAGIHTTPResponses
## The return functions for the callables in [FEAGIHTTPCallList]. 
#Note: All callables must be STATIC

#region SYSTEM



	
## Special version of the health check function used for validating if feagi is active and working, used for feagi connection attempt
static func GET_healthCheck_FEAGI_VALIDATION(response_body: PackedByteArray, _irrelevant_data: Variant):
	var health_data: Dictionary = FEAGIHTTPResponses.byte_array_to_dict(response_body)
	if !FEAGIHTTPResponses.does_dict_contain_keys(health_data, ["genome_availability"]):
		# if we are missing this key, something is wrong
		FeagiCore.FEAGI_retrieve_connection_check_results(FeagiCore.CONNECTION_CHECK_RESULTS.UNKNOWN_RESPONSE)
		return
	if health_data["genome_availability"]:
		FeagiCore.FEAGI_retrieve_connection_check_results(FeagiCore.CONNECTION_CHECK_RESULTS.HEALTHY)
	else:
		FeagiCore.FEAGI_retrieve_connection_check_results(FeagiCore.CONNECTION_CHECK_RESULTS.HEALTHY_BUT_NO_GENOME)

## FEAGI returned an HTTP error
static func GET_healthCheck_FEAGI_VALIDATION_ERROR(_response_body: PackedByteArray, _request_definition: APIRequestWorkerDefinition):
	FeagiCore.FEAGI_retrieve_connection_check_results(FeagiCore.CONNECTION_CHECK_RESULTS.UNKNOWN_RESPONSE)

## FEAGI doesnt seem to be running at all
static func GET_healthCheck_FEAGI_VALIDATION_UNRESPONSIVE(_request_definition: APIRequestWorkerDefinition):
	FeagiCore.FEAGI_retrieve_connection_check_results(FeagiCore.CONNECTION_CHECK_RESULTS.NO_RESPONSE)
	
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
