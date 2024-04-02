extends Object
class_name FEAGIHTTPResponses
## The return functions for the callables in [FEAGIHTTPCallList]. 
#Note: All callables must be STATIC

#region SYSTEM



static func GET_healthCheck(response_body: PackedByteArray, _irrelevant_data: Variant):
	
	pass
	

# special version of the above function used for validating if feagi is active and working, used for feagi connection attempt
static func GET_healthCheck_STARTUP_VALIDATION(response_body: PackedByteArray, _irrelevant_data: Variant):
	
	pass

#endregion




#region godot_internal




#endregion
