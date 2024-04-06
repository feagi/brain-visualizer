extends RefCounted
class_name FEAGIRequests

## Reloads the genome, returns if sucessful
func reload_genome() -> bool:
	if FeagiCore.genome_load_state != FeagiCore.GENOME_LOAD_STATE.RELOADING_GENOME_FROM_FEAGI:
		push_error("FEAGI Requests: Please reload the genome from core, not from here directly, to avoid issues")
		return false
	
	var cortical_area_request: APIRequestWorkerDefinition = FEAGIHTTPCallList.GET_CorticalArea_Geometry()
	var morphologies_request: APIRequestWorkerDefinition = FEAGIHTTPCallList.GET_morphologies()
	var mappings_request: APIRequestWorkerDefinition = FEAGIHTTPCallList.GET_CorticalMapDetailed()
	
	# Get Cortical Area Data
	var cortical_area_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(cortical_area_request)
	await cortical_area_worker.worker_done
	var cortical_area_data: APIRequestWorkerOutput = cortical_area_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(cortical_area_data):
		return false

	# Get Morphologies
	var morphologies_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(morphologies_request)
	await morphologies_worker.worker_done
	var morphologies_data: APIRequestWorkerOutput = morphologies_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(morphologies_data):
		return false

	# Get Mapping Data
	var mapping_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(mappings_request)
	await mapping_worker.worker_done
	var mapping_data: APIRequestWorkerOutput = mapping_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(mapping_data):
		return false
	
	FeagiCore.feagi_local_cache.replace_whole_genome(
		cortical_area_data.decode_response_as_dict(),
		morphologies_data.decode_response_as_dict(),
		mapping_data.decode_response_as_dict()
	)
	return true


## Used for error automated error handling of HTTP requests, outputs booleans to set up easy early returns
func _return_if_HTTP_failed_and_automatically_handle(output: APIRequestWorkerOutput) -> bool:
	if output.has_timed_out:
		print("TODO generic timeout handling")
		return true
	if output.has_errored:
		print("TODO generic error handling")
		return true
	return false
