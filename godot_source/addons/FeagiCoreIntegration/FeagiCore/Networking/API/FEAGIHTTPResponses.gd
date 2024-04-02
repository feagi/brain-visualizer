extends Object # Static so leave this as is
class_name FEAGIHTTPResponses
## The return functions for the callables in [FEAGIHTTPCallList]. 
#Note: All callables must be STATIC

#region SYSTEM



static func GET_healthCheck(response_body: PackedByteArray, _irrelevant_data: Variant):
	
	pass
	

# special version of the above function used for validating if feagi is active and working, used for feagi connection attempt
static func GET_healthCheck_FEAGI_VALIDATION(response_body: PackedByteArray, _irrelevant_data: Variant):
	print("response!")
	push_warning("response!")

static func GET_healthCheck_FEAGI_VALIDATION_ERROR(_response_body: PackedByteArray, _request_definition: APIRequestWorkerDefinition):
	print("Error")
	
static func GET_healthCheck_FEAGI_VALIDATION_UNRESPONSIVE(_request_definition: APIRequestWorkerDefinition):
	print("NO CONNECTION")
	push_warning("NO CONNECTION")
	
#endregion




#region godot_internal




#endregion
