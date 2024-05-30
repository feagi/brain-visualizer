extends Object
class_name FEAGIHTTPCallList
## Static Callables from godot to make HTTP requests to FEAGI

#WARNING: Calling any function here when HTTP (and thus addres list) is not initialized will cause a crash!



## Add custom cortical area (or memory, or copies an existing area), this really should be split up from feagis side
static func POST_CustomCorticalArea(name: StringName, position_3d: Vector3i, dimensions: Vector3i, 
	is_coordinate_2D_defined: bool, coordinates_2D: Vector2i = Vector2(0,0), memory_type: bool = false, 
	cortical_ID_to_copy: StringName = "") -> APIRequestWorkerDefinition:
		
	var dict: Dictionary = 	{
			"cortical_name": name,
			"coordinates_3d": FEAGIUtils.vector3i_to_array(position_3d),
			"cortical_dimensions": FEAGIUtils.vector3i_to_array(dimensions),
			"cortical_group": BaseCorticalArea.cortical_type_to_str(BaseCorticalArea.CORTICAL_AREA_TYPE.CUSTOM),
			"cortical_sub_group": "",
			"coordinates_2d": [null, null]
		}
	if is_coordinate_2D_defined:
		dict["coordinates_2d"] = coordinates_2D
	if memory_type:
		dict["sub_group_id"] = "MEMORY"
	if cortical_ID_to_copy != "":
		dict["copy_of"] = cortical_ID_to_copy
	
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_call(
		FeagiCore.network.http_API.address_list.POST_genome_customCorticalArea,
		HTTPClient.METHOD_POST,
		dict
	)
	return request


#endregion



