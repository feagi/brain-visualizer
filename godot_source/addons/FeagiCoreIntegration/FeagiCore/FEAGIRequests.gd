extends RefCounted
class_name FEAGIRequests

func reload_genome() -> void:
	# Acquire latest data from FEAGI
	var cortical_area_request = FeagiCore.network.http_API.call_list.GET_CorticalArea_Geometry()
	var mappings_request = FeagiCore.network.http_API.call_list.GET_CorticalMapDetailed()
	
	# Get Cortical Area Data
	var cortical_area_worker: APIRequestWorker = FeagiCore.network.http_API.FEAGI_API_Request2(cortical_area_request)
	await cortical_area_worker.worker_done
	var cortical_area_data: APIRequestWorkerOutput = cortical_area_worker.retrieve_output_and_close()
	
	# Get Mapping Data
	var mapping_worker: APIRequestWorker = FeagiCore.network.http_API.FEAGI_API_Request2(mappings_request)
	await mapping_worker.worker_done
	var mapping_data: APIRequestWorkerOutput = mapping_worker.retrieve_output_and_close()
	
	if cortical_area_data.has_errored:
		print("make error")
		return
	if mapping_data.has_errored:
		print("make error")
		return
	
	FeagiCore.feagi_local_cache.cortical_areas_cache.update_cortical_area_cache_from_summary(cortical_area_data.decode_response_as_dict())
	


