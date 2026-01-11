extends RefCounted
class_name FEAGIRequests

#region Genome and FEAGI general

# WARNING: You probably don't want to call this directly!
## Runs a single (non-polling) healthcheck update
func single_health_check_call(update_cache_with_result: bool = false) -> FeagiRequestOutput:
	# Check if network components are properly initialized
	if not FeagiCore.network:
		push_error("FEAGI Requests: FeagiCore.network is null")
		return FeagiRequestOutput.requirement_fail("NETWORK_NULL")
	
	if not FeagiCore.network.http_API:
		push_error("FEAGI Requests: FeagiCore.network.http_API is null")
		return FeagiRequestOutput.requirement_fail("HTTP_API_NULL")
	
	if not FeagiCore.network.http_API.address_list:
		push_error("FEAGI Requests: FeagiCore.network.http_API.address_list is null")
		return FeagiRequestOutput.requirement_fail("ADDRESS_LIST_NULL")
	
	var health_check_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(FeagiCore.network.http_API.address_list.GET_system_healthCheck)
	var health_check_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(health_check_request)
	
	await health_check_worker.worker_done
	
	var response_data: FeagiRequestOutput = health_check_worker.retrieve_output_and_close()
	if response_data.success and update_cache_with_result:
		FeagiCore.feagi_local_cache.update_health_from_FEAGI_dict(response_data.decode_response_as_dict())
	return response_data

## FAST initial health check for startup - bypasses global timeout/retry settings for instant response
func fast_initial_health_check() -> FeagiRequestOutput:
	# Check if network components are properly initialized
	if not FeagiCore.network:
		push_error("FEAGI Requests: FeagiCore.network is null")
		return FeagiRequestOutput.requirement_fail("NETWORK_NULL")
	
	if not FeagiCore.network.http_API:
		push_error("FEAGI Requests: FeagiCore.network.http_API is null")
		return FeagiRequestOutput.requirement_fail("HTTP_API_NULL")
	
	if not FeagiCore.network.http_API.address_list:
		push_error("FEAGI Requests: FeagiCore.network.http_API.address_list is null")
		return FeagiRequestOutput.requirement_fail("ADDRESS_LIST_NULL")
	
	# Create FAST health check - manual settings to bypass global defaults
	var health_url: StringName = FeagiCore.network.http_API.address_list.GET_system_healthCheck
	var fast_health_check_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.new()
	fast_health_check_request.full_address = health_url
	fast_health_check_request.method = HTTPClient.Method.METHOD_GET
	fast_health_check_request.call_type = APIRequestWorker.CALL_PROCESS_TYPE.SINGLE
	fast_health_check_request.data_to_send_to_FEAGI = null
	
	# FAST settings for startup (but with increased timeout for large injections)
	# Increased from 2.0 to 15.0 to tolerate large sensory injections that may block burst loop
	# Large NIfTI frames can take 5-10 seconds to inject, causing temporary API unresponsiveness
	fast_health_check_request.http_timeout = 15.0  # Increased timeout: 15 seconds to handle large injections
	fast_health_check_request.number_of_retries_allowed = 1
	
	var health_check_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(fast_health_check_request)
	await health_check_worker.worker_done
	
	var response_data: FeagiRequestOutput = health_check_worker.retrieve_output_and_close()
	return response_data


#WARNING: You probably dont want to call this directly. Use FeagiCore.request_reload_genome() instead!
## Reloads the genome, returns if sucessful
func save_genome(file_path: String = "") -> FeagiRequestOutput:
	print("FEAGI REQUEST: Saving genome to disk...")
	
	# Network component checks
	var network_check = _check_network_components_ready()
	if network_check != null:
		return network_check
	
	# Prepare request body
	var request_body = {}
	if file_path != "":
		request_body["file_path"] = file_path
	
	# Make POST request to save genome
	var save_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_POST_call(
		FeagiCore.network.http_API.address_list.POST_genome_save,
		request_body
	)
	var save_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(save_request)
	await save_worker.worker_done
	var save_output: FeagiRequestOutput = save_worker.retrieve_output_and_close()
	
	if save_output.has_errored:
		push_error("FEAGI REQUEST: Failed to save genome!")
		print("FEAGI REQUEST: ❌ Genome save failed")
		return save_output
	
	print("FEAGI REQUEST: ✅ Genome saved successfully")
	return save_output

func reload_genome() -> FeagiRequestOutput:
	print("FEAGI REQUEST: [3D_SCENE_DEBUG] reload_genome() called - starting genome data retrieval...")
	
	# Network component checks
	var network_check = _check_network_components_ready()
	if network_check != null:
		return network_check
	
	var cortical_area_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(FeagiCore.network.http_API.address_list.GET_corticalArea_corticalArea_geometry)
	var morphologies_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(FeagiCore.network.http_API.address_list.GET_morphology_morphologies)
	var mappings_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(FeagiCore.network.http_API.address_list.GET_corticalArea_corticalMapDetailed)
	var region_request:APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(FeagiCore.network.http_API.address_list.GET_region_regionsMembers)
	# Use dedicated IPU/OPU type endpoints instead of generic cortical_types
	var ipu_types_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(FeagiCore.network.http_API.address_list.GET_corticalAreas_ipu_types)
	var opu_types_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(FeagiCore.network.http_API.address_list.GET_corticalAreas_opu_types)
	var agent_list_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(FeagiCore.network.http_API.address_list.GET_agent_list)
	
	# Get Cortical Area Data
	print("FEAGI REQUEST: [3D_SCENE_DEBUG] Step 1/7: Requesting cortical area data...")
	print("FEAGI REQUEST: [3D_SCENE_DEBUG] 🌐 Making HTTP call to: %s" % FeagiCore.network.http_API.address_list.GET_corticalArea_corticalArea_geometry)
	var cortical_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(cortical_area_request)
	print("FEAGI REQUEST: [3D_SCENE_DEBUG] 🌐 HTTP call initiated, waiting for response...")
	await cortical_worker.worker_done
	print("FEAGI REQUEST: [3D_SCENE_DEBUG] 🌐 HTTP call completed, retrieving data...")
	var cortical_data: FeagiRequestOutput = cortical_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(cortical_data):
		print("FEAGI REQUEST: [3D_SCENE_DEBUG] ❌ FAILED at Step 1: Cortical area data request failed!")
		push_error("FEAGI Requests: Unable to grab FEAGI cortical summary data!")
		return cortical_data
	print("FEAGI REQUEST: [3D_SCENE_DEBUG] ✅ Step 1 complete: Cortical area data retrieved")

	# Get Morphologies
	print("FEAGI REQUEST: [3D_SCENE_DEBUG] Step 2/7: Requesting morphology data...")
	var morphologies_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(morphologies_request)
	await morphologies_worker.worker_done
	var morphologies_data: FeagiRequestOutput = morphologies_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(morphologies_data):
		print("FEAGI REQUEST: [3D_SCENE_DEBUG] ❌ FAILED at Step 2: Morphology data request failed!")
		push_error("FEAGI Requests: Unable to grab FEAGI morphology summary data!")
		return morphologies_data
	print("FEAGI REQUEST: [3D_SCENE_DEBUG] ✅ Step 2 complete: Morphology data retrieved")

	# Get Mapping Data
	print("FEAGI REQUEST: [3D_SCENE_DEBUG] Step 3/7: Requesting mapping data...")
	var mapping_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(mappings_request)
	await mapping_worker.worker_done
	var mapping_data: FeagiRequestOutput = mapping_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(mapping_data):
		print("FEAGI REQUEST: [3D_SCENE_DEBUG] ❌ FAILED at Step 3: Mapping data request failed!")
		push_error("FEAGI Requests: Unable to grab FEAGI mapping summary data!")
		return mapping_data
	print("FEAGI REQUEST: [3D_SCENE_DEBUG] ✅ Step 3 complete: Mapping data retrieved")
	
	# Get Region Data
	print("FEAGI REQUEST: [3D_SCENE_DEBUG] Step 4/7: Requesting region data...")
	var region_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(region_request)
	await region_worker.worker_done
	var region_data: FeagiRequestOutput = region_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(region_data):
		print("FEAGI REQUEST: [3D_SCENE_DEBUG] ❌ FAILED at Step 4: Region data request failed!")
		push_error("FEAGI Requests: Unable to grab FEAGI region data!")
		return region_data
	print("FEAGI REQUEST: [3D_SCENE_DEBUG] ✅ Step 4 complete: Region data retrieved")
	
	print("FEAGI REQUEST: [3D_SCENE_DEBUG] Step 5/7: Replacing genome cache with new data...")
	FeagiCore.feagi_local_cache.replace_whole_genome(
		cortical_data.decode_response_as_dict(),
		morphologies_data.decode_response_as_dict(),
		mapping_data.decode_response_as_dict(),
		region_data.decode_response_as_dict()
	)
	print("FEAGI REQUEST: [3D_SCENE_DEBUG] ✅ Step 5 complete: Genome cache updated")
	
	# Get Template Data from dedicated IPU/OPU endpoints
	print("FEAGI REQUEST: [3D_SCENE_DEBUG] Step 6/7: Requesting template data...")
	print("FEAGI REQUEST: [3D_SCENE_DEBUG]   6a: Requesting IPU types...")
	var ipu_types_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(ipu_types_request)
	await ipu_types_worker.worker_done
	var ipu_types_data: FeagiRequestOutput = ipu_types_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(ipu_types_data):
		print("FEAGI REQUEST: [3D_SCENE_DEBUG] ❌ FAILED at Step 6a: IPU types request failed!")
		push_error("FEAGI Requests: Unable to grab FEAGI IPU types data!")
		return ipu_types_data
	
	print("FEAGI REQUEST: [3D_SCENE_DEBUG]   6b: Requesting OPU types...")
	var opu_types_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(opu_types_request)
	await opu_types_worker.worker_done
	var opu_types_data: FeagiRequestOutput = opu_types_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(opu_types_data):
		print("FEAGI REQUEST: [3D_SCENE_DEBUG] ❌ FAILED at Step 6b: OPU types request failed!")
		push_error("FEAGI Requests: Unable to grab FEAGI OPU types data!")
		return opu_types_data
	
	# Transform responses into format expected by cache
	var ipu_types_dict: Dictionary = ipu_types_data.decode_response_as_dict()
	var opu_types_dict: Dictionary = opu_types_data.decode_response_as_dict()
	
	# name_to_id_mapping maps type_id -> [cortical_instance_ids] from current genome
	# This will be built from genome data, not from templates (templates just define available types)
	var ipu_name_mapping: Dictionary = {}
	var opu_name_mapping: Dictionary = {}
	
	# Aggregate into expected structure
	var aggregated_templates: Dictionary = {
		"types": {
			"IPU": {
				"supported_devices": ipu_types_dict,
				"name_to_id_mapping": ipu_name_mapping  # Empty for now - will be populated from genome
			},
			"OPU": {
				"supported_devices": opu_types_dict,
				"name_to_id_mapping": opu_name_mapping  # Empty for now - will be populated from genome
			}
		}
	}
	
	# Template data loaded successfully
	FeagiCore.feagi_local_cache.update_templates_from_FEAGI(aggregated_templates)
	print("FEAGI REQUEST: [3D_SCENE_DEBUG] ✅ Step 6 complete: Template data retrieved")
	
	# Other stuff (asyncronous)
	print("FEAGI REQUEST: [3D_SCENE_DEBUG] Starting asynchronous requests for burst settings...")
	get_burst_delay()
	get_supression_threshold()
	get_skip_rate()
	get_plasticity_queue_depth()
	
	# Get agent list
	print("FEAGI REQUEST: [3D_SCENE_DEBUG] Step 7/7: Processing agent data...")
	FeagiCore.feagi_local_cache.clear_configuration_jsons()
	var agent_list_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(agent_list_request)
	await agent_list_worker.worker_done
	var agent_list_data: FeagiRequestOutput = agent_list_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(agent_list_data):
		print("FEAGI REQUEST: [3D_SCENE_DEBUG] ❌ FAILED at Step 7: Agent list request failed!")
		push_error("FEAGI Requests: Unable to grab FEAGI agent summary data!")
		return agent_list_data
	var agents: Array = agent_list_data.decode_response_as_array()
	print("FEAGI REQUEST: [3D_SCENE_DEBUG] Found ", agents.size(), " agents, processing individual agent data...")
	for agent in agents:
		if str(agent).begins_with("bv_"):
			continue
		print("FEAGI REQUEST: [3D_SCENE_DEBUG] Processing agent: ", agent)
		var agent_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(FeagiCore.network.http_API.address_list.GET_agent_properties + "?agent_id=" + str(agent))
		var agent_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(agent_request)
		await agent_worker.worker_done
		var agent_data: FeagiRequestOutput = agent_worker.retrieve_output_and_close()
		if _return_if_HTTP_failed_and_automatically_handle(agent_data):
			print("FEAGI REQUEST: [3D_SCENE_DEBUG] ❌ Failed to get data for agent: ", agent)
			push_error("unable to return agent data for %s!" % str(agent))
			return agent_data
		var agent_dict: Dictionary = agent_data.decode_response_as_dict()
		agent_dict["capabilities"]["agent_ID"] = str(agent)
		FeagiCore.feagi_local_cache.append_configuration_json(agent_dict["capabilities"])
	print("FEAGI REQUEST: [3D_SCENE_DEBUG] ✅ Step 7 complete: Agent data processed")
	
	print("FEAGI REQUEST: [3D_SCENE_DEBUG] ✅ ALL STEPS COMPLETE: Genome reload finished successfully!")
	return FeagiRequestOutput.generic_success() # use generic success since we made multiple calls
	

## Retrieves FEAGIs Burst Rate
func get_burst_delay() -> FeagiRequestOutput:
	print("FEAGI REQUEST: Request getting delay between bursts")
	
	# Define Request
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(FeagiCore.network.http_API.address_list.GET_burstEngine_simulationTimestep)
	
	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		push_error("FEAGI Requests: Unable to grab FEAGI Burst rate delay!")
		return FEAGI_response_data
	var response: String = FEAGI_response_data.decode_response_as_string()
	print("FEAGI REQUEST: Successfully retrieved delay between bursts as %f" % response.to_float())
	FeagiCore.feagi_retrieved_burst_rate(response.to_float())
	return FEAGI_response_data


## Set the burst rate
func update_burst_delay(new_delay_between_bursts: float) -> FeagiRequestOutput:
	print("🔥 FEAGI REQUEST: update_burst_delay called with %s seconds" % new_delay_between_bursts)
	
	# Requirement checking
	if !FeagiCore.can_interact_with_feagi():
		print("🔥 FEAGI REQUEST: ERROR - can_interact_with_feagi() returned false!")
		print("🔥 FEAGI REQUEST: Current genome state: %s" % FeagiCore.GENOME_LOAD_STATE.keys()[FeagiCore.genome_load_state])
		print("🔥 FEAGI REQUEST: Required state: GENOME_READY")
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	print("🔥 FEAGI REQUEST: can_interact_with_feagi() check passed")
	
	# Check network components are ready
	var network_check_result = _check_network_components_ready()
	if network_check_result != null:
		print("🔥 FEAGI REQUEST: ERROR - network components not ready! Result: %s" % network_check_result)
		push_error("FEAGI Requests: Network components not ready for update_burst_delay!")
		return network_check_result
	print("🔥 FEAGI REQUEST: network components check passed")
	
	if new_delay_between_bursts <= 0.0:
		print("🔥 FEAGI REQUEST: ERROR - delay <= 0.0: %s" % new_delay_between_bursts)
		push_error("FEAGI Requests: Cannot set delay between bursts to 0 or less!")
		return FeagiRequestOutput.requirement_fail("IMPOSSIBLE_BURST_DELAY")
	print("🔥 FEAGI REQUEST: All checks passed, proceeding with API call...")
	print("FEAGI REQUEST: Request setting delay between bursts to %s" % new_delay_between_bursts)
	
	# Define Request
	var dict_to_send: Dictionary = 	{ "simulation_timestep": new_delay_between_bursts}
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_POST_call(FeagiCore.network.http_API.address_list.POST_feagi_burstEngine, dict_to_send)
	
	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		push_error("FEAGI Requests: Unable to update FEAGI burst rate delay!")
		return FEAGI_response_data
	print("FEAGI REQUEST: Successfully updated delay between bursts to %d" % new_delay_between_bursts)
	FeagiCore.feagi_retrieved_burst_rate(new_delay_between_bursts)
	return FEAGI_response_data

## Retrieves plasticity queue depth
func get_plasticity_queue_depth() -> FeagiRequestOutput:
	print("FEAGI REQUEST: Request getting plasticity queue depth")
	
	# Define Request
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(FeagiCore.network.http_API.address_list.GET_neuroplasticity_plasticityQueueDepth)
	
	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		push_error("FEAGI Requests: Unable to grab FEAGI plasticity queue depth!")
		return FEAGI_response_data
	var response: String = FEAGI_response_data.decode_response_as_string()
	print("FEAGI REQUEST: Successfully retrieved plasticity queue depth as %d" % response.to_int())
	
	FeagiCore.feagi_local_cache.update_plasticity_queue_depth(response.to_int())
	return FEAGI_response_data

## Set the plasticity queue depth
func update_plasticity_queue_depth(new_depth: int) -> FeagiRequestOutput:
	# Requirement checking
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	if new_depth <= 0:
		push_error("FEAGI Requests: Cannot set plasticity queue depth to 0 or less!")
		return FeagiRequestOutput.requirement_fail("IMPOSSIBLE_PLASTICITY_QUEUE_DEPTH")
	print("FEAGI REQUEST: Request setting plasticity queue depth to to %s" % str(new_depth))
	
	# Define Request
	var dict_to_send: Dictionary = {} # We are doing this the dumb way again
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_PUT_call(FeagiCore.network.http_API.address_list.PUT_neuroplasticity_plasticityQueueDepth + "?queue_depth=" + str(new_depth), dict_to_send)
	
	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		push_error("FEAGI Requests: Unable to update FEAGI plasticity queue depth!")
		return FEAGI_response_data
	print("FEAGI REQUEST: Successfully updated plasticity queue depth to %d" % new_depth)
	FeagiCore.feagi_local_cache.update_plasticity_queue_depth(new_depth)
	return FEAGI_response_data

## Retrieves FEAGIs Skip Rate
func get_skip_rate() -> FeagiRequestOutput:
	print("FEAGI REQUEST: Request getting skip_rate")
	
	# Define Request
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(FeagiCore.network.http_API.address_list.GET_system_corticalAreaVisualizationSkipRate)
	
	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		push_error("FEAGI Requests: Unable to grab FEAGI skip rate!")
		return FEAGI_response_data
	var response: String = FEAGI_response_data.decode_response_as_string()
	print("FEAGI REQUEST: Successfully retrieved skip rate as %d" % response.to_int())
	FeagiCore.feagi_recieved_skip_rate(response.to_int())
	return FEAGI_response_data



## Sets the skip rate
func change_skip_rate(new_skip_rate: int) -> FeagiRequestOutput:
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	
	# Define Request
	var dict_to_send: Dictionary = 	{ "burst_duration": new_skip_rate}
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_PUT_call(FeagiCore.network.http_API.address_list.PUT_system_corticalAreaVisualizationSkipRate, dict_to_send)
	
	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		push_error("FEAGI Requests: Unable to update FEAGI skip rate!")
		return FEAGI_response_data
	print("FEAGI REQUEST: Successfully updated skip rate to %d" % new_skip_rate)
	FeagiCore.feagi_recieved_skip_rate(new_skip_rate)
	return FEAGI_response_data

## Retrieves FEAGIs Skip Rate
func get_supression_threshold() -> FeagiRequestOutput:
	print("FEAGI REQUEST: Request getting supression threshold")
	
	# Define Request
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(FeagiCore.network.http_API.address_list.GET_system_corticalAreaVisualizationSupressionThreshold)
	
	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		push_error("FEAGI Requests: Unable to grab FEAGI supression threshold!")
		return FEAGI_response_data
	var response: String = FEAGI_response_data.decode_response_as_string()
	print("FEAGI REQUEST: Successfully retrieved skip rate as %d" % response.to_int())
	FeagiCore.feagi_recieved_supression_threshold(response.to_int())
	return FEAGI_response_data



## Sets the skip rate
func change_supression_threshold(new_skip_rate: int) -> FeagiRequestOutput:
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	
	# Define Request
	var dict_to_send: Dictionary = 	{ "burst_duration": new_skip_rate}
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_PUT_call(FeagiCore.network.http_API.address_list.PUT_system_corticalAreaVisualizationSupressionThreshold, dict_to_send)
	
	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		push_error("FEAGI Requests: Unable to update FEAGI skip rate!")
		return FEAGI_response_data
	print("FEAGI REQUEST: Successfully updated supression threshold to %d" % new_skip_rate)
	FeagiCore.feagi_recieved_supression_threshold(new_skip_rate)
	return FEAGI_response_data

func retrieve_vision_tuning_parameters() -> FeagiRequestOutput:
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(FeagiCore.network.http_API.address_list.GET_input_vision)
	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	return FEAGI_response_data

func send_vision_tuning_parameters(parameters: Dictionary) -> FeagiRequestOutput:
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_POST_call(FeagiCore.network.http_API.address_list.POST_input_vision, parameters)
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	return FEAGI_response_data

#endregion
#region Regions summary (lightweight)

## Fetches the regions summary (members, inputs, outputs) without reloading the entire genome
func get_regions_summary() -> FeagiRequestOutput:
	# Network component checks
	var network_check = _check_network_components_ready()
	if network_check != null:
		return network_check
	
	var region_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(FeagiCore.network.http_API.address_list.GET_region_regionsMembers)
	var region_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(region_request)
	await region_worker.worker_done
	var region_data: FeagiRequestOutput = region_worker.retrieve_output_and_close()
	_return_if_HTTP_failed_and_automatically_handle(region_data)
	return region_data

#endregion

#region Mapping summary (lightweight)

## Fetches the cortical mapping summary without reloading the entire genome
func get_mapping_summary() -> FeagiRequestOutput:
	# Network component checks
	var network_check = _check_network_components_ready()
	if network_check != null:
		return network_check
	
	var mappings_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(FeagiCore.network.http_API.address_list.GET_corticalArea_corticalMapDetailed)
	var mapping_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(mappings_request)
	await mapping_worker.worker_done
	var mapping_data: FeagiRequestOutput = mapping_worker.retrieve_output_and_close()
	_return_if_HTTP_failed_and_automatically_handle(mapping_data)
	return mapping_data

#endregion


## Mass move a bunch of genome objects at once (FIXED: Use correct API endpoints for each object type)
func mass_move_genome_objects_2D(genome_objects_mapped_to_new_locations_as_vector2is: Dictionary) -> FeagiRequestOutput:
	# Requirement checking
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	for move in genome_objects_mapped_to_new_locations_as_vector2is.keys():
		if !genome_objects_mapped_to_new_locations_as_vector2is[move] is Vector2i:
			push_error("FEAGI Requests: Value does not seem to be a Vector2i!" % move)
			return FeagiRequestOutput.requirement_fail("INVALID_VALUE")
		#TODO ID check
	
	# CRITICAL FIX: Separate cortical areas from brain regions to use correct API endpoints
	var cortical_areas_to_move: Array[AbstractCorticalArea] = []
	var cortical_area_positions: Dictionary = {}
	var brain_regions_to_move: Dictionary = {}
	
	# Separate objects by type
	for genome_object in genome_objects_mapped_to_new_locations_as_vector2is.keys():
		var new_position = genome_objects_mapped_to_new_locations_as_vector2is[genome_object]
		
		if genome_object is AbstractCorticalArea:
			# Cortical areas: Use /v1/cortical_area/multi/cortical_area endpoint
			var cortical_area = genome_object as AbstractCorticalArea
			cortical_areas_to_move.append(cortical_area)
			cortical_area_positions[cortical_area] = new_position
			print("FEAGI REQUEST: Will update cortical area %s position using cortical_area API" % cortical_area.cortical_ID)
		elif genome_object is BrainRegion:
			# Brain regions: Use /v1/region/relocate_members endpoint  
			var brain_region = genome_object as BrainRegion
			brain_regions_to_move[brain_region] = new_position
			print("FEAGI REQUEST: Will update brain region %s position using region API" % brain_region.friendly_name)
		else:
			push_warning("FEAGI Requests: Unknown genome object type for movement: %s" % genome_object.get_class())
	
	var final_result: FeagiRequestOutput
	
	# Handle cortical areas (use cortical area properties API - CORRECT!)
	if cortical_areas_to_move.size() > 0:
		print("FEAGI REQUEST: Moving %d cortical areas using CORRECT /v1/cortical_area/multi/cortical_area API" % cortical_areas_to_move.size())
		
		# Build properties dictionary with coordinate_2d for each cortical area
		var properties = {}
		for cortical_area in cortical_areas_to_move:
			var new_coords = cortical_area_positions[cortical_area]
			properties[cortical_area.cortical_ID] = {"coordinate_2d": FEAGIUtils.vector2i_to_array(new_coords)}
		
		# Use the existing update_cortical_areas function logic but with coordinate updates
		properties["cortical_id_list"] = AbstractCorticalArea.cortical_area_array_to_ID_array(cortical_areas_to_move)
		var cortical_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_PUT_call(FeagiCore.network.http_API.address_list.PUT_corticalArea_multi_corticalArea, properties)
		
		var cortical_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(cortical_request)
		await cortical_worker.worker_done
		final_result = cortical_worker.retrieve_output_and_close()
		
		if _return_if_HTTP_failed_and_automatically_handle(final_result):
			push_error("FEAGI Requests: Unable to move %d cortical areas using cortical_area API!" % cortical_areas_to_move.size())
			return final_result
		
		print("FEAGI REQUEST: Successfully moved %d cortical areas using CORRECT cortical_area API!" % cortical_areas_to_move.size())
		
		# Update local cache for cortical areas
		for cortical_area in cortical_areas_to_move:
			var movement_dict = {cortical_area: cortical_area_positions[cortical_area]}
			FeagiCore.feagi_local_cache.FEAGI_mass_update_2D_positions(movement_dict)
	
	# Handle brain regions (use region relocate_members API - may be correct for regions)
	if brain_regions_to_move.size() > 0:
		print("FEAGI REQUEST: Moving %d brain regions using /v1/region/relocate_members API" % brain_regions_to_move.size())
		
		var region_dict_to_send: Dictionary = {}
		for brain_region in brain_regions_to_move.keys():
			region_dict_to_send[(brain_region as BrainRegion).region_ID] = {"coordinate_2d": FEAGIUtils.vector2i_to_array(brain_regions_to_move[brain_region])}
		
		var region_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_PUT_call(FeagiCore.network.http_API.address_list.PUT_genome_relocate_members, region_dict_to_send)
		
		var region_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(region_request)
		await region_worker.worker_done
		var region_result: FeagiRequestOutput = region_worker.retrieve_output_and_close()
		
		if _return_if_HTTP_failed_and_automatically_handle(region_result):
			push_error("FEAGI Requests: Unable to move %d brain regions!" % brain_regions_to_move.size())
			return region_result
			
		print("FEAGI REQUEST: Successfully moved %d brain regions!" % brain_regions_to_move.size())
		
		# Update local cache for brain regions
		FeagiCore.feagi_local_cache.FEAGI_mass_update_2D_positions(brain_regions_to_move)
		final_result = region_result
	
	return final_result


#region Brain Regions
## Used by the user to create regions
func create_region(parent_region: BrainRegion, region_internals: Array[GenomeObject], region_name: StringName, coords_2D: Vector2i, coords_3D: Vector3i) -> FeagiRequestOutput:
	# Clean region creation without fallbacks
	print("🏗️ Creating region '%s' at coordinates 2D=%s, 3D=%s" % [region_name, coords_2D, coords_3D])
	
	# Requirement checking
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	if !parent_region.region_ID in FeagiCore.feagi_local_cache.brain_regions.available_brain_regions:
		push_error("FEAGI Requests: No such parent ID %s to create subregion under!" % parent_region.region_ID)
		return FeagiRequestOutput.requirement_fail("INVALID_PARENT_ID")
	if region_name == "":
		push_error("FEAGI Requests: Region name cannot be blank!")
		return FeagiRequestOutput.requirement_fail("BLANK_NAME")
	for internal in region_internals:
		if internal is BrainRegion:
			if (internal as BrainRegion).is_root_region():
				push_error("FEAGI Requests: Cannot add root region as a subregion!")
				return FeagiRequestOutput.requirement_fail("CHILD_ROOT")
	
	# Define Request
	var dict_to_send: Dictionary = {
		"title": region_name,
		"parent_region_id": parent_region.region_ID,
		"coordinates_2d": FEAGIUtils.vector2i_to_array(coords_2D),
		"coordinates_3d": FEAGIUtils.vector3i_to_array(coords_3D),
		"areas": AbstractCorticalArea.cortical_area_array_to_ID_array(GenomeObject.filter_cortical_areas(region_internals)),
		"regions": BrainRegion.object_array_to_ID_array(GenomeObject.filter_brain_regions(region_internals)),
	}
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_POST_call(FeagiCore.network.http_API.address_list.POST_region_region, dict_to_send)
	
	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		push_error("FEAGI Requests: Unable to create region of name %s!" % region_name)
		return FEAGI_response_data
	var response: Dictionary = FEAGI_response_data.decode_response_as_dict()
	
	# Use coordinates from FEAGI response if available, otherwise use input coordinates
	var feagi_coords_2d = coords_2D
	var feagi_coords_3d = coords_3D
	
	if response.has("coordinate_2d") and response["coordinate_2d"] is Array:
		feagi_coords_2d = FEAGIUtils.array_to_vector2i(response["coordinate_2d"])
	if response.has("coordinate_3d") and response["coordinate_3d"] is Array:
		feagi_coords_3d = FEAGIUtils.array_to_vector3i(response["coordinate_3d"])
	
	# Add region to cache (but don't emit signal yet)
	FeagiCore.feagi_local_cache.brain_regions.FEAGI_add_region(response["region_id"], parent_region, region_name, feagi_coords_2d, feagi_coords_3d, region_internals)

	# Load I/O mapping data from POST response BEFORE emitting region_added signal  
	if response.has("inputs") or response.has("outputs"):
		var inputs = response.get("inputs", [])
		var outputs = response.get("outputs", [])
		
		
		var seed: Dictionary = {}
		seed[response["region_id"]] = {
			"inputs": inputs,
			"outputs": outputs
		}
		FeagiCore.feagi_local_cache.brain_regions.FEAGI_load_all_partial_mapping_sets(seed)
		print("🔄 REGION CREATION: Loaded I/O mappings for new region %s - inputs: %s, outputs: %s" % [response["region_id"], inputs.size(), outputs.size()])
	
	var new_region: BrainRegion = FeagiCore.feagi_local_cache.brain_regions.available_brain_regions[response["region_id"]]
	if new_region:
		# Refresh the region cache to establish any synthetic I/O mappings
		FeagiCore.feagi_local_cache._refresh_single_brain_region_cache(new_region)
		
		# NOW emit the region_added signal after all cache data is loaded
		print("🚀 REGION CREATION: All cache data loaded, emitting region_added signal for: %s" % new_region.friendly_name)
		FeagiCore.feagi_local_cache.brain_regions.emit_region_added_signal(new_region)
		
		# Ask UI to open or refresh BM for the new region so areas appear immediately
		# Avoid static typing to prevent parser issues in plugin context
		var wm = null
		var main_loop := Engine.get_main_loop()
		if main_loop != null and main_loop is SceneTree:
			var root: SceneTree = main_loop as SceneTree
			var wm_node = root.root.get_node_or_null("BrainVisualizer/UIManager/WindowManager")
			if wm_node != null and wm_node.has_method("spawn_3d_brain_monitor_tab"):
				wm = wm_node
		if wm != null:
			wm.spawn_3d_brain_monitor_tab(new_region)
	
	print("✅ Region '%s' created at %s" % [region_name, feagi_coords_3d])
	return FEAGI_response_data
	
## Used to edit the metadata of the region
func edit_region_object(brain_region: BrainRegion, parent_region: BrainRegion, region_name: StringName, region_description: StringName, coords_2D: Vector2i, coords_3D: Vector3i) -> FeagiRequestOutput:
	# Requirement checking
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	if !brain_region.region_ID in FeagiCore.feagi_local_cache.brain_regions.available_brain_regions:
		push_error("FEAGI Requests: No such region ID %s to edit!" % brain_region.region_ID)
		return FeagiRequestOutput.requirement_fail("INVALID_REGION_ID")
	if !parent_region.region_ID in FeagiCore.feagi_local_cache.brain_regions.available_brain_regions:
		push_error("FEAGI Requests: No such parent region ID %s to place subregion under!" % parent_region.region_ID)
		return FeagiRequestOutput.requirement_fail("INVALID_PARENT_ID")
	if !brain_region.region_ID in FeagiCore.feagi_local_cache.brain_regions.available_brain_regions:
		push_error("FEAGI Requests: No such region ID %s to edit!" % brain_region.region_ID)
		return FeagiRequestOutput.requirement_fail("INVALID_REGION_ID")
	if brain_region.is_root_region():
		push_error("FEAGI Requests: Unable to edit root region!")
		return FeagiRequestOutput.requirement_fail("CANNOT_EDIT_ROOT")
	if region_name == "":
		push_error("FEAGI Requests: Region name cannot be blank!")
		return FeagiRequestOutput.requirement_fail("BLANK_NAME")
	
	# Define Request - Using correct FEAGI API key names
	var dict_to_send: Dictionary = {
		"region_id": brain_region.region_ID,
		"region_title": region_name,  # title → region_title
		"coordinate_2d": FEAGIUtils.vector2i_to_array(coords_2D),  # coordinates_2d → coordinate_2d
		"coordinate_3d": FEAGIUtils.vector3i_to_array(coords_3D),  # coordinates_3d → coordinate_3d
		# Removed unsupported keys: parent_region_id, region_description
	}
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_PUT_call(FeagiCore.network.http_API.address_list.PUT_region_region, dict_to_send)
	
	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		push_error("FEAGI Requests: Unable to create region of name %s!" % brain_region.friendly_name)
		return FEAGI_response_data
	FeagiCore.feagi_local_cache.brain_regions.FEAGI_edit_region(brain_region, region_name, region_description, parent_region, coords_2D, coords_3D)
	return FEAGI_response_data

func move_objects_to_region(target_region: BrainRegion, objects_to_move: Array[GenomeObject]) -> FeagiRequestOutput:
	# Requirement checking
	if !FeagiCore.can_interact_with_feagi():
		BV.NOTIF.add_notification("Cannot move objects: Not connected to FEAGI", NotificationSystemNotification.NOTIFICATION_TYPE.ERROR)
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	if !target_region.region_ID in FeagiCore.feagi_local_cache.brain_regions.available_brain_regions:
		var error_msg = "Cannot move objects: Target region '%s' does not exist!" % target_region.friendly_name
		BV.NOTIF.add_notification(error_msg, NotificationSystemNotification.NOTIFICATION_TYPE.ERROR)
		return FeagiRequestOutput.requirement_fail("INVALID_REGION_ID")
	for object in objects_to_move:
		if object is BrainRegion:
			if (object as BrainRegion).is_root_region():
				var error_msg = "Unable to make Root Region a child of %s!" % target_region.friendly_name
				BV.NOTIF.add_notification(error_msg, NotificationSystemNotification.NOTIFICATION_TYPE.ERROR)
				return FeagiRequestOutput.requirement_fail("CANNOT_MOVE_ROOT")
			if (object as BrainRegion).region_ID == target_region.region_ID:
				var error_msg = "Cannot make region %s child of itself!" % target_region.friendly_name
				BV.NOTIF.add_notification(error_msg, NotificationSystemNotification.NOTIFICATION_TYPE.ERROR)
				return FeagiRequestOutput.requirement_fail("CANNOT_RECURSE_REGION")
	
	# Define Request - FEAGI requires both parent_region_id AND coordinate_2d
	var dict_to_send: Dictionary = {}
	for object in objects_to_move:
		dict_to_send[object.genome_ID] = {
			"parent_region_id": target_region.region_ID,
			"coordinate_2d": FEAGIUtils.vector2i_to_array(object.coordinates_2D)
		}
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_PUT_call(FeagiCore.network.http_API.address_list.PUT_region_relocateMembers, dict_to_send)
	
	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		var error_msg = "Unable to move objects to region '%s'. Server error: %s" % [target_region.friendly_name, FEAGI_response_data.failure_reason]
		BV.NOTIF.add_notification(error_msg, NotificationSystemNotification.NOTIFICATION_TYPE.ERROR)
		return FEAGI_response_data
	
	# Parse the response to get updated region data
	var response_dict = FEAGI_response_data.decode_response_as_dict()
	print("MOVE API RESPONSE: ", response_dict.keys())
	
	# Update local cache for moved objects
	for object in objects_to_move:
		object.FEAGI_change_parent_brain_region(target_region)
	
	# CRITICAL: Force I/O refresh for destination region
	print("FORCING I/O REFRESH for region: ", target_region.region_ID)
	call_deferred("_force_io_refresh", target_region.region_ID)
	
	var success_msg = "Successfully moved %d object(s) to region '%s'" % [objects_to_move.size(), target_region.friendly_name]
	BV.NOTIF.add_notification(success_msg, NotificationSystemNotification.NOTIFICATION_TYPE.INFO)
	return FEAGI_response_data

## Force I/O refresh for a region after moving objects
func _force_io_refresh(region_id: StringName) -> void:
	print("IO REFRESH: Starting for region ", region_id)
	
	# Get the region from cache
	if not region_id in FeagiCore.feagi_local_cache.brain_regions.available_brain_regions:
		print("IO REFRESH: Region not found in cache")
		return
	
	var region = FeagiCore.feagi_local_cache.brain_regions.available_brain_regions[region_id]
	
	# Step 1: Refresh cache data
	FeagiCore.feagi_local_cache._refresh_single_brain_region_cache(region)
	
	# Step 2: Manual I/O detection based on connections
	_detect_io_areas_by_connections(region)
	
	# Step 3: Trigger visualization refresh
	_refresh_region_visualization(region_id)

## Detect I/O areas by analyzing external connections
func _detect_io_areas_by_connections(region: BrainRegion) -> void:
	print("IO DETECTION: Analyzing connections for region ", region.friendly_name)
	
	var new_partial_mappings: Array[PartialMappingSet] = []
	var contained_ids: Array[String] = []
	
	# Get all area IDs in this region
	for area in region.contained_cortical_areas:
		contained_ids.append(area.cortical_ID)
	
	# Check each area for external connections
	for area in region.contained_cortical_areas:
		var is_input = false
		var is_output = false
		
		# Check incoming connections (afferent_mappings keys are source areas)
		if area.afferent_mappings:
			for source_area in area.afferent_mappings:
				var source_id = source_area.cortical_ID
				if source_id not in contained_ids:
					print("IO DETECTION: ", area.cortical_ID, " has external input from ", source_id)
					is_input = true
		
		# Check outgoing connections (efferent_mappings keys are destination areas)
		if area.efferent_mappings:
			for dest_area in area.efferent_mappings:
				var dest_id = dest_area.cortical_ID
				if dest_id not in contained_ids:
					print("IO DETECTION: ", area.cortical_ID, " has external output to ", dest_id)
					is_output = true
		
		# Create partial mappings for I/O areas
		if is_input:
			var input_mapping = PartialMappingSet.new(true, [], area, region, "external_input")
			new_partial_mappings.append(input_mapping)
			print("IO DETECTION: Added INPUT mapping for ", area.cortical_ID)
		
		if is_output:
			var output_mapping = PartialMappingSet.new(false, [], area, region, "external_output")
			new_partial_mappings.append(output_mapping)
			print("IO DETECTION: Added OUTPUT mapping for ", area.cortical_ID)
	
	# Add new mappings to existing ones
	region.partial_mappings.append_array(new_partial_mappings)
	print("IO DETECTION: Region now has ", region.partial_mappings.size(), " total partial mappings")

## Refresh region visualization
func _refresh_region_visualization(region_id: StringName) -> void:
	var scene_tree = Engine.get_main_loop() as SceneTree
	if not scene_tree or not scene_tree.root:
		return
	
	var brain_monitor_scenes = scene_tree.root.find_children("*", "UI_BrainMonitor_3DScene", true, false)
	
	for scene in brain_monitor_scenes:
		if scene is UI_BrainMonitor_3DScene:
			var monitor_scene = scene as UI_BrainMonitor_3DScene
			# First try direct key lookup
			if region_id in monitor_scene._brain_region_visualizations_by_ID:
				var brain_region_3d = monitor_scene._brain_region_visualizations_by_ID[region_id]
				brain_region_3d._refresh_frame_contents()
				print("IO REFRESH: Triggered visualization refresh for ", region_id)
				return
			# Fallback: match by string equality (handles String vs StringName mismatches)
			for existing_id in monitor_scene._brain_region_visualizations_by_ID.keys():
				if str(existing_id) == str(region_id):
					var br3d = monitor_scene._brain_region_visualizations_by_ID[existing_id]
					br3d._refresh_frame_contents()
					print("IO REFRESH: Triggered visualization refresh (fallback match) for ", region_id)
					return


func delete_regions_and_raise_internals(deleting_region: BrainRegion) -> FeagiRequestOutput:
	# Requirement checking
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	if !deleting_region.region_ID in FeagiCore.feagi_local_cache.brain_regions.available_brain_regions:
		push_error("FEAGI Requests: No such region ID %s to edit!" % deleting_region.region_ID)
		return FeagiRequestOutput.requirement_fail("INVALID_REGION_ID")
	if deleting_region.is_root_region():
		push_error("FEAGI Requests: Unable to delete Root Region!")
		return FeagiRequestOutput.requirement_fail("CANNOT_DELETE_ROOT")

	# Define Request
	var dict_to_send: Dictionary = {
		"id": deleting_region.region_ID
	}
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_DELETE_call(FeagiCore.network.http_API.address_list.DELETE_region_region, dict_to_send)
	
	
	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		push_error("FEAGI Requests: Unable to delete region of name %s!" % deleting_region.friendly_name)
		return FEAGI_response_data
	FeagiCore.feagi_local_cache.brain_regions.FEAGI_remove_region_and_raise_internals(deleting_region)
	return FEAGI_response_data

	
	
	
#endregion


#region Cortical Areas

#NOTE: No way to request a core area, since we shouldn't be able to make those directly!

## Requests an update of a cortical area's properties a single time
func get_cortical_area(checking_cortical_ID: StringName) -> FeagiRequestOutput:
	# Fetching cortical area details
	# Requirement checking
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	
	# Note: Removed the cache existence check to allow fetching missing cortical areas
	
	# Define Request
	var dict_to_send: Dictionary = {"cortical_id": checking_cortical_ID}
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_POST_call(FeagiCore.network.http_API.address_list.POST_corticalArea_corticalAreaProperties, dict_to_send)
	print("FEAGI REQUEST: Making POST request to %s for cortical area %s" % [FeagiCore.network.http_API.address_list.POST_corticalArea_corticalAreaProperties, checking_cortical_ID])
	
	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		var error_details = FEAGI_response_data.decode_response_as_generic_error_code()
		var raw_response = FEAGI_response_data.decode_response_as_string()
		push_error("FEAGI Requests: Unable to grab cortical area details of %s! Error: %s - %s" % [checking_cortical_ID, error_details[0], error_details[1]])
		return FEAGI_response_data
	
	var response: Dictionary = FEAGI_response_data.decode_response_as_dict()
	
	# Log visualization_voxel_granularity if present
	if "visualization_voxel_granularity" in response:
		print("🔵 FEAGI REQUEST: Found visualization_voxel_granularity in top-level for %s: %s (type: %s)" % [checking_cortical_ID, response["visualization_voxel_granularity"], typeof(response["visualization_voxel_granularity"])])
	if "properties" in response and response["properties"] is Dictionary and "visualization_voxel_granularity" in response["properties"]:
		print("🔵 FEAGI REQUEST: Found visualization_voxel_granularity in properties for %s: %s" % [checking_cortical_ID, response["properties"]["visualization_voxel_granularity"]])
	
	# Handle nested properties structure - FEAGI returns {"properties": {...}}
	# Also handle top-level fields (like visualization_voxel_granularity) that are outside properties
	var properties_dict: Dictionary = response
	if "properties" in response and response["properties"] is Dictionary:
		# Merge top-level fields with properties (top-level takes precedence)
		properties_dict = response["properties"].duplicate()
		# Copy top-level fields that aren't in properties (like visualization_voxel_granularity, cortical_type, etc.)
		for key in response.keys():
			if key != "properties" and not key in properties_dict:
				properties_dict[key] = response[key]
				if key == "visualization_voxel_granularity":
					print("🔵 FEAGI REQUEST: Passing visualization_voxel_granularity to cache for %s: %s (type: %s)" % [checking_cortical_ID, response[key], typeof(response[key])])
	properties_dict["cortical_id"] = checking_cortical_ID  # Add the ID to the properties dict
	
	# Check if cortical area exists in cache - if not, create it; if yes, update it
	if checking_cortical_ID in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas:
		# Prevent incorrect reassignment to root if backend omits true parent region
		# If server reports parent_region_id as root but cache shows a non-root parent, trust cache
		var existing_area: AbstractCorticalArea = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas[checking_cortical_ID]
		if properties_dict.has("parent_region_id"):
			var reported_parent: StringName = properties_dict["parent_region_id"]
			var current_parent: StringName = existing_area.current_parent_region.region_ID if existing_area != null and existing_area.current_parent_region != null else BrainRegion.ROOT_REGION_ID
			if reported_parent == BrainRegion.ROOT_REGION_ID and current_parent != BrainRegion.ROOT_REGION_ID:
				properties_dict["parent_region_id"] = current_parent
		FeagiCore.feagi_local_cache.cortical_areas.FEAGI_update_cortical_area_from_dict(properties_dict)
	else:
		# Need to create the cortical area - find the parent region first
		var parent_region_id: StringName = properties_dict.get("parent_region_id", BrainRegion.ROOT_REGION_ID)
		
		if parent_region_id not in FeagiCore.feagi_local_cache.brain_regions.available_brain_regions:
			push_warning("FEAGI REQUEST: Parent region '%s' not found for cortical area '%s', using root region" % [parent_region_id, checking_cortical_ID])
			parent_region_id = BrainRegion.ROOT_REGION_ID
		
		# Check if parent region exists in cache
		if not FeagiCore.feagi_local_cache.brain_regions.available_brain_regions.has(parent_region_id):
			push_error("FEAGI REQUEST: Parent region '%s' not found in cache, cannot create cortical area '%s'" % [parent_region_id, checking_cortical_ID])
			return FeagiRequestOutput.requirement_fail("PARENT_REGION_NOT_FOUND")
		
		var parent_region_data = FeagiCore.feagi_local_cache.brain_regions.available_brain_regions[parent_region_id]
		if parent_region_data == null:
			push_error("FEAGI REQUEST: Parent region '%s' is null in cache, cannot create cortical area '%s'" % [parent_region_id, checking_cortical_ID])
			return FeagiRequestOutput.requirement_fail("PARENT_REGION_NULL")
		
		if not parent_region_data is BrainRegion:
			push_error("FEAGI REQUEST: Parent region '%s' is not a BrainRegion object (type: %s), cannot create cortical area '%s'" % [parent_region_id, type_string(typeof(parent_region_data)), checking_cortical_ID])
			return FeagiRequestOutput.requirement_fail("INVALID_PARENT_REGION")
		
		var parent_region: BrainRegion = parent_region_data as BrainRegion
		FeagiCore.feagi_local_cache.cortical_areas.FEAGI_add_cortical_area_from_dict(properties_dict, parent_region, checking_cortical_ID)
	return FEAGI_response_data

### Requests information on multiple cortical areas
func get_cortical_areas(checking_areas: Array[AbstractCorticalArea]) -> FeagiRequestOutput:
	# Basic FeagiCore checks first
	if !FeagiCore:
		push_error("FEAGI Requests: FeagiCore is null!")
		return FeagiRequestOutput.requirement_fail("FEAGICORE_NULL")
	
	# Requirement checking
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	
	# Additional network component checks
	var network_check = _check_network_components_ready()
	if network_check != null:
		return network_check
	
	# Define Request
	var IDs: Array[StringName] = AbstractCorticalArea.cortical_area_array_to_ID_array(checking_areas)
	var dict_to_send: Dictionary = {"cortical_id_list": IDs}
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_POST_call(FeagiCore.network.http_API.address_list.POST_corticalArea_multi_corticalAreaProperties, dict_to_send)

	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		push_error("FEAGI Requests: Unable to grab cortical area details of %d cortical areas!" % len(checking_areas))
		return FEAGI_response_data
	
	# Response is a dictionary with cortical_id as keys: {"cortical_id": {...properties...}}
	var responses_dict: Dictionary = FEAGI_response_data.decode_response_as_dict()
	print("FEAGI REQUEST: Successfully retrieved details of %d cortical areas!" % len(responses_dict.keys()))
	
	for cortical_id in responses_dict.keys():
		var area_data_raw: Dictionary = responses_dict[cortical_id]
		# Log visualization_voxel_granularity if present
		if "visualization_voxel_granularity" in area_data_raw:
			print("🔵 FEAGI REQUEST: [MULTI] Found visualization_voxel_granularity in top-level for %s: %s" % [cortical_id, area_data_raw["visualization_voxel_granularity"]])
		if "properties" in area_data_raw and area_data_raw["properties"] is Dictionary and "visualization_voxel_granularity" in area_data_raw["properties"]:
			print("🔵 FEAGI REQUEST: [MULTI] Found visualization_voxel_granularity in properties for %s: %s" % [cortical_id, area_data_raw["properties"]["visualization_voxel_granularity"]])
		
		# Handle both response formats:
		# - { "cortical_id": { ...properties... } }
		# - { "cortical_id": { "properties": { ...properties... } } }
		var area_data: Dictionary = area_data_raw
		if "properties" in area_data_raw and area_data_raw["properties"] is Dictionary:
			# Merge top-level fields with properties (top-level takes precedence for fields like visualization_voxel_granularity)
			area_data = area_data_raw["properties"].duplicate()
			# Copy top-level fields - top-level takes precedence (overwrites properties version)
			for key in area_data_raw.keys():
				if key != "properties":
					area_data[key] = area_data_raw[key]  # Top-level always wins
					if key == "visualization_voxel_granularity":
						print("🔵 FEAGI REQUEST: [MULTI] Passing visualization_voxel_granularity to cache for %s: %s" % [cortical_id, area_data_raw[key]])
		# Ensure cortical_id is in the dict (some responses omit it).
		# IMPORTANT: Cast to StringName so cache lookups using StringName keys work reliably.
		if not "cortical_id" in area_data:
			area_data["cortical_id"] = StringName(cortical_id)
		print("🔵 FEAGI REQUEST: [MULTI] Updating cache for %s with visualization_voxel_granularity: %s" % [cortical_id, area_data.get("visualization_voxel_granularity", "NOT PRESENT")])
		FeagiCore.feagi_local_cache.cortical_areas.FEAGI_update_cortical_area_from_dict(area_data)
	
	return FEAGI_response_data
	

## Adds a custom cortical area
func add_custom_cortical_area(cortical_name: StringName, coordinates_3D: Vector3i, dimensions: Vector3i, parent_region: BrainRegion, is_coordinate_2D_defined: bool, coordinates_2D: Vector2i = Vector2(0,0)) -> FeagiRequestOutput:
	# Requirement checking
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	if cortical_name in FeagiCore.feagi_local_cache.cortical_areas.get_all_cortical_area_names():
		push_error("FEAGI Requests: Cannot create custom cortical area of name %s when a cortical area of this name already exists!" % cortical_name)
		return FeagiRequestOutput.requirement_fail("NAME_EXISTS")
	if !(parent_region.region_ID in FeagiCore.feagi_local_cache.brain_regions.available_brain_regions.keys()):
		push_error("FEAGI Requests: Cannot create custom cortical area of name %s inside non-existant region %s!" % [cortical_name, parent_region.region_ID])
		return FeagiRequestOutput.requirement_fail("REGION_NOT_EXISTS")
	
	print("FEAGI REQUEST: Request creating custom cortical area by name %s" % cortical_name)
	
	# Define Request
	var dict_to_send: Dictionary = 	{
		"cortical_name": cortical_name,
		"coordinates_3d": FEAGIUtils.vector3i_to_array(coordinates_3D),
		"cortical_dimensions": FEAGIUtils.vector3i_to_array(dimensions),
		"cortical_group": AbstractCorticalArea.cortical_type_to_str(AbstractCorticalArea.CORTICAL_AREA_TYPE.CUSTOM),  # API field name (category: IPU/OPU/CORE/etc)
		"brain_region_id": parent_region.region_ID,
		"cortical_sub_group": "",
		"coordinates_2d": [null, null]
	}
	
	# NEW: Add cortical_type_info for CUSTOM areas
	var feagi_custom_type: FeagiCorticalType = FeagiCorticalTypeFactory.create_custom()
	dict_to_send["cortical_type_info"] = feagi_custom_type.to_api_dict()
	
	if is_coordinate_2D_defined:
		dict_to_send["coordinates_2d"] = FEAGIUtils.vector2i_to_array(coordinates_2D)
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_POST_call(FeagiCore.network.http_API.address_list.POST_genome_customCorticalArea, dict_to_send)

	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		push_error("FEAGI Requests: Unable to create custom cortical area by the name of %s!" % cortical_name)
		return FEAGI_response_data
	var response: Dictionary = FEAGI_response_data.decode_response_as_dict()
	FeagiCore.feagi_local_cache.cortical_areas.FEAGI_add_custom_cortical_area( response["cortical_id"], cortical_name, coordinates_3D, dimensions, is_coordinate_2D_defined, coordinates_2D, parent_region)
	print("FEAGI REQUEST: Successfully created custom cortical area by name %s with ID %s" % [cortical_name, response["cortical_id"]])
	
	# Automatically fetch detailed properties for the newly created cortical area
	await get_cortical_area(response["cortical_id"])
	# Ensure the created area appears in the correct region's 3D view immediately
	if parent_region != null:
		var bm: UI_BrainMonitor_3DScene = BV.UI.get_brain_monitor_for_region(parent_region)
		if bm != null:
			# Force-add if not present due to filter timing
			var new_area_obj: AbstractCorticalArea = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.get(response["cortical_id"], null)
			if new_area_obj != null:
				bm._add_cortical_area(new_area_obj)
	print("FEAGI REQUEST: Fetched detailed properties for newly created cortical area %s" % response["cortical_id"])
	
	return FEAGI_response_data


## Adds a custom memory cortical area
func add_custom_memory_cortical_area(cortical_name: StringName, coordinates_3D: Vector3i, dimensions: Vector3i, parent_region: BrainRegion, is_coordinate_2D_defined: bool, coordinates_2D: Vector2i = Vector2(0,0)) -> FeagiRequestOutput:
	# Requirement checking
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	if cortical_name in FeagiCore.feagi_local_cache.cortical_areas.get_all_cortical_area_names():
		push_error("FEAGI Requests: Cannot create custom cortical area of name %s when a cortical area of this name already exists!" % cortical_name)
		return FeagiRequestOutput.requirement_fail("NAME_EXISTS")
	if !(parent_region.region_ID in FeagiCore.feagi_local_cache.brain_regions.available_brain_regions.keys()):
		push_error("FEAGI Requests: Cannot create memory cortical area of name %s inside non-existant region %s!" % [cortical_name, parent_region.region_ID])
		return FeagiRequestOutput.requirement_fail("REGION_NOT_EXISTS")
	
	print("FEAGI REQUEST: Request creating custom memory cortical area by name %s" % cortical_name)
	# Define Request
	var dict_to_send: Dictionary = 	{
		"cortical_name": cortical_name,
		"coordinates_3d": FEAGIUtils.vector3i_to_array(coordinates_3D),
		"cortical_dimensions": FEAGIUtils.vector3i_to_array(dimensions),
		"cortical_group": AbstractCorticalArea.cortical_type_to_str(AbstractCorticalArea.CORTICAL_AREA_TYPE.CUSTOM),  # API field name (category: IPU/OPU/CORE/etc)
		"cortical_sub_group": "",
		"coordinates_2d": [null, null],
		"sub_group_id": "MEMORY",
		"brain_region_id": parent_region.region_ID,
	}
	if is_coordinate_2D_defined:
		dict_to_send["coordinates_2d"] = FEAGIUtils.vector2i_to_array(coordinates_2D)
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_POST_call(FeagiCore.network.http_API.address_list.POST_genome_customCorticalArea, dict_to_send)

	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		push_error("FEAGI Requests: Unable to create memory cortical area by the name of %s!" % cortical_name)
		return FEAGI_response_data
	var response: Dictionary = FEAGI_response_data.decode_response_as_dict()
	FeagiCore.feagi_local_cache.cortical_areas.FEAGI_add_memory_cortical_area( response["cortical_id"], cortical_name, coordinates_3D, dimensions, is_coordinate_2D_defined, coordinates_2D, parent_region)
	print("FEAGI REQUEST: Successfully created custom memory cortical area by name %s with ID %s" % [cortical_name, response["cortical_id"]])
	
	# Automatically fetch detailed properties for the newly created cortical area
	await get_cortical_area(response["cortical_id"])
	# Ensure the created area appears in the correct region's 3D view immediately
	if parent_region != null:
		var bm: UI_BrainMonitor_3DScene = BV.UI.get_brain_monitor_for_region(parent_region)
		if bm != null:
			var new_area_obj: AbstractCorticalArea = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.get(response["cortical_id"], null)
			if new_area_obj != null:
				bm._add_cortical_area(new_area_obj)
	print("FEAGI REQUEST: Fetched detailed properties for newly created memory cortical area %s" % response["cortical_id"])
	
	return FEAGI_response_data


## Adds a IPU / OPU cortical area (may create multiple cortical areas for multi-subunit templates).
## NOTE: IPUs/OPUs can ONLY be in the root region!
##
## BREAKING CHANGE (unreleased FEAGI API):
## `data_type_config` is now per-subunit: `data_type_configs_by_subunit` (Dictionary: subunit_idx -> config_value).
func add_IOPU_cortical_area(IOPU_template: CorticalTemplate, device_count: int, coordinates_3D: Vector3i, is_coordinate_2D_defined: bool, coordinates_2D: Vector2i = Vector2(0,0), unit_id: int = 0, neurons_per_voxel: int = 1, data_type_configs_by_subunit: Dictionary = {}) -> FeagiRequestOutput:
	# Requirement checking
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	
	# Additional network component checks
	var network_check = _check_network_components_ready()
	if network_check != null:
		return network_check
	if IOPU_template.ID in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.keys():
		push_error("FEAGI Requests: I/OPU area of ID %s already exists!!" % IOPU_template.ID)
		return FeagiRequestOutput.requirement_fail("ID_EXISTS")
	if device_count < 1:
		push_error("FEAGI Requests: Channel count is too low!")
		return FeagiRequestOutput.requirement_fail("CHANNEL_TOO_LOW")
	if !(IOPU_template.cortical_type  in [AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU, AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU]):
		push_error("FEAGI Requests: Unable to create non-IPU/OPU area using the request IPU/OPU call!, Skipping!")
		return FeagiRequestOutput.requirement_fail("NON_IOPU")
	
	print("FEAGI REQUEST: Request creating IOPU cortical area by name %s with unit_id %d, neurons_per_voxel %d, data_type_configs_by_subunit=%s" % [IOPU_template.cortical_name, unit_id, neurons_per_voxel, str(data_type_configs_by_subunit)])
	# Define Request
	var dict_to_send: Dictionary = {
		"cortical_id": IOPU_template.ID,
		"coordinates_3d": FEAGIUtils.vector3i_to_array(coordinates_3D),
		"cortical_type": AbstractCorticalArea.cortical_type_to_str(IOPU_template.cortical_type),
		"device_count": device_count,
		"unit_id": unit_id,
		"neurons_per_voxel": neurons_per_voxel,
		"data_type_configs_by_subunit": data_type_configs_by_subunit,
		"coordinates_2d": [null, null]
	}
	
	# NEW: Add cortical_type_info if available
	if IOPU_template.feagi_cortical_type != null:
		dict_to_send["cortical_type_info"] = IOPU_template.feagi_cortical_type.to_api_dict()
	
	if is_coordinate_2D_defined:
		dict_to_send["coordinates_2d"] = FEAGIUtils.vector2i_to_array(coordinates_2D)
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_POST_call(FeagiCore.network.http_API.address_list.PUT_genome_corticalArea, dict_to_send)

	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		push_error("FEAGI Requests: Unable to create IPU/OPU cortical area!")
		return FEAGI_response_data
	var response: Dictionary = FEAGI_response_data.decode_response_as_dict()
	
	# For multi-unit cortical types (e.g., Segmented Vision with 9 units), 
	# multiple cortical areas are created and returned in the response
	var unit_count: int = int(response.get("unit_count", 1))
	
	print("FEAGI REQUEST: Successfully created %d cortical area(s) for %s (first ID: %s)" % [unit_count, IOPU_template.cortical_name, response.get("cortical_id", "")])
	
	# Add all created areas directly to cache using the full details returned in response
	var created_cortical_ids: Array[StringName] = []
	if "areas" in response and response["areas"] is Array:
		var areas: Array = response["areas"]
		print("FEAGI REQUEST: Adding %d cortical areas directly to cache from response" % areas.size())
		
		for area_dict in areas:
			if area_dict is Dictionary:
				var cortical_id: StringName = area_dict.get("cortical_id", "")
				if cortical_id == "":
					push_error("FEAGI REQUEST: Area in response missing cortical_id")
					continue
				
				print("FEAGI REQUEST: Adding cortical area %s to cache" % cortical_id)
				# Add to cache using FEAGI_add_cortical_area_from_dict which handles all types
				var parent_region_id: StringName = area_dict.get("parent_region_id", BrainRegion.ROOT_REGION_ID)
				var parent_region: BrainRegion = FeagiCore.feagi_local_cache.brain_regions.available_brain_regions.get(
					parent_region_id,
					FeagiCore.feagi_local_cache.brain_regions.get_root_region()
				)
				if parent_region == null:
					push_error("FEAGI REQUEST: Parent region '%s' not found and root region unavailable, cannot add cortical area '%s'" % [parent_region_id, cortical_id])
					continue
				FeagiCore.feagi_local_cache.cortical_areas.FEAGI_add_cortical_area_from_dict(
					area_dict,
					parent_region,
					cortical_id
				)
				created_cortical_ids.append(cortical_id)
	else:
		push_warning("FEAGI REQUEST: Response missing 'areas' field - falling back to fetching properties")
		# Fallback: fetch properties if server doesn't return them
		if "cortical_ids" in response:
			var cortical_ids_str: String = response["cortical_ids"]
			var cortical_ids: PackedStringArray = cortical_ids_str.split(", ")
			for cortical_id in cortical_ids:
				if cortical_id != "":
					await get_cortical_area(cortical_id)
					created_cortical_ids.append(StringName(cortical_id))
		else:
			# Fallback for single unit (backward compatibility)
			await get_cortical_area(response["cortical_id"])
			created_cortical_ids.append(StringName(response["cortical_id"]))
	
	# Ensure all created areas appear in the correct region's 3D view immediately
	# This fixes timing issues with large areas where get_cortical_area takes longer
	var root_region: BrainRegion = FeagiCore.feagi_local_cache.brain_regions.get_root_region()
	if root_region != null:
		var bm: UI_BrainMonitor_3DScene = BV.UI.get_brain_monitor_for_region(root_region)
		if bm != null:
			for cortical_id in created_cortical_ids:
				var new_area_obj: AbstractCorticalArea = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.get(cortical_id, null)
				if new_area_obj != null:
					bm._add_cortical_area(new_area_obj)
	
	print("FEAGI REQUEST: All newly created IOPU cortical areas for type %s, unit %d have been added to cache." % [IOPU_template.ID, unit_id])
	
	return FEAGI_response_data


## Clone a given cortical area
func clone_cortical_area(cloning_area: AbstractCorticalArea, new_name: StringName, new_position_2D: Vector2i, new_position_3D: Vector3i, parent_region: BrainRegion, clone_cortical_mapping: bool = true) -> FeagiRequestOutput:
	# Requirement checking
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	if !cloning_area.cortical_ID in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.keys():
		push_error("FEAGI Requests: Unable to clone cortical area %s that is not found in cache!!" % cloning_area.cortical_ID)
		return FeagiRequestOutput.requirement_fail("SOURCE_NOT_FOUND")
	if !cloning_area.user_can_clone_this_cortical_area:
		push_error("FEAGI Requests: Unable to clone cortical area %s as it is of type %s!" % [cloning_area.cortical_ID, cloning_area.type_as_string])
		return FeagiRequestOutput.requirement_fail("CLONE_NOT_ALLOWED")
	print("User requested cloning cortical area " + cloning_area.cortical_ID)
	
	# New unified clone endpoint
	var dict_to_send: Dictionary = {
		"source_area_id": cloning_area.cortical_ID,
		"clone_cortical_mapping": clone_cortical_mapping,
		"coordinates_3d": FEAGIUtils.vector3i_to_array(new_position_3D),
		"coordinates_2d": FEAGIUtils.vector2i_to_array(new_position_2D)
	}
	# Double-check network components
	var network_check = _check_network_components_ready()
	if network_check != null:
		return network_check
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_POST_call(FeagiCore.network.http_API.address_list.POST_corticalArea_clone, dict_to_send)
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		push_error("FEAGI Requests: Unable to clone cortical area %s!" % cloning_area.cortical_ID)
		return FEAGI_response_data

	# Success path: decode, refresh caches, and ensure placement under correct region
	var response: Dictionary = FEAGI_response_data.decode_response_as_dict()
	var new_id: String = response.get("new_area_id", "")
	print("FEAGI REQUEST: Successfully cloned cortical area %s to new area %s" % [cloning_area.cortical_ID, new_id])
	# Refresh area details and region membership incrementally
	if new_id != "":
		await get_cortical_area(new_id)
		var regions_summary: FeagiRequestOutput = await get_regions_summary()
		if regions_summary != null and regions_summary.success:
			var regions_dict: Dictionary = regions_summary.decode_response_as_dict()
			# Update partial mapping sets (inputs/outputs) for regions
			FeagiCore.feagi_local_cache.brain_regions.FEAGI_load_all_partial_mapping_sets(regions_dict)
			# Determine the correct parent region for the new area from the regions summary
			var target_region_id: StringName = &""
			for region_id in regions_dict.keys():
				var region_info: Dictionary = regions_dict[region_id]
				if region_info.has("areas"):
					var listed_areas: Array = []
					listed_areas.assign(region_info["areas"])
					if listed_areas.has(new_id):
						target_region_id = StringName(region_id)
						break
			# If we found a target region, move the area in local cache so 3D placement is correct
			if target_region_id != &"":
				if FeagiCore.feagi_local_cache.brain_regions.available_brain_regions.has(target_region_id):
					var target_region: BrainRegion = FeagiCore.feagi_local_cache.brain_regions.available_brain_regions[target_region_id]
					var new_area_obj: AbstractCorticalArea = FeagiCore.feagi_local_cache.cortical_areas.try_to_get_cortical_area_by_ID(new_id)
					if new_area_obj != null and new_area_obj.current_parent_region != target_region:
						print("FEAGI REQUEST: Moving cloned area %s under region %s" % [new_id, target_region.region_ID])
						new_area_obj.FEAGI_change_parent_brain_region(target_region)
						# If the region's Brain Monitor is open, ensure the visualization is added immediately
						if BV.UI:
							var bm_target: UI_BrainMonitor_3DScene = BV.UI.get_brain_monitor_for_region(target_region)
							if bm_target != null:
								bm_target._add_cortical_area(new_area_obj)
		# Refresh mapping cache so UI components (3D scene, Circuit Builder) see new connections
		var mapping_summary: FeagiRequestOutput = await get_mapping_summary()
		if mapping_summary != null and mapping_summary.success:
			var mapping_dict: Dictionary = mapping_summary.decode_response_as_dict()
			FeagiCore.feagi_local_cache.mapping_data.FEAGI_load_all_mappings(mapping_dict)
			# Proactively refresh any visible brain monitor connection visuals
			var scene_tree = Engine.get_main_loop() as SceneTree
			if scene_tree and scene_tree.root:
				var brain_monitor_scenes = scene_tree.root.find_children("*", "UI_BrainMonitor_3DScene", true, false)
				for scene in brain_monitor_scenes:
					if scene is UI_BrainMonitor_3DScene:
						(scene as UI_BrainMonitor_3DScene).force_refresh_all_cortical_connections()
	return FEAGI_response_data

## Initiate region clone as pending amalgamation (no finalize). Returns amalgamation_id and circuit_size.
func clone_brain_region_pending(source_region: BrainRegion, region_name: StringName, prefill_position_3D: Vector3i = Vector3i(0, 0, 0), prefill_position_2D: Vector2i = Vector2i(0, 0)) -> FeagiRequestOutput:
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	if source_region == null:
		push_error("FEAGI Requests: clone_brain_region_pending called with null region")
		return FeagiRequestOutput.requirement_fail("INVALID_INPUT")

	# Defensive clear: if a pending amalgamation exists, cancel it before starting a new one
	var health: FeagiRequestOutput = await single_health_check_call(false)
	if health != null and health.success:
		var health_dict: Dictionary = health.decode_response_as_dict()
		if "amalgamation_pending" in health_dict and health_dict["amalgamation_pending"]:
			var amalgamation_id: String = str(health_dict.get("amalgamation_id", ""))
			print("⚠️ FEAGI REQUEST: Pending amalgamation detected (%s). Auto-cancelling before new clone..." % amalgamation_id)
			var cancel_def: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_DELETE_call(
				FeagiCore.network.http_API.address_list.DELETE_GE_amalgamationCancellation + "?amalgamation_id=" + amalgamation_id, {}
			)
			var cancel_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(cancel_def)
			await cancel_worker.worker_done
			var cancel_out: FeagiRequestOutput = cancel_worker.retrieve_output_and_close()
			if cancel_out.has_errored:
				push_warning("FEAGI Requests: Auto-cancel of previous pending amalgamation reported an error; proceeding with new clone anyway.")
			else:
				print("FEAGI REQUEST: Previous pending amalgamation cancelled.")

	print("FEAGI REQUEST: Request region clone pending for %s" % source_region.genome_ID)
	var dict_to_send: Dictionary = {
		"source_region_id": source_region.genome_ID,
		"region_name": region_name,
		# Prefill coordinates for server-side availability if needed; finalize uses destination API
		"coordinates_3d": [prefill_position_3D.x, prefill_position_3D.y, prefill_position_3D.z],
		"coordinates_2d": [prefill_position_2D.x, prefill_position_2D.y]
	}
	var request_def: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_POST_call(
		FeagiCore.network.http_API.address_list.POST_region_clone, dict_to_send)

	var worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(request_def)
	await worker.worker_done
	var output: FeagiRequestOutput = worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(output, request_def):
		push_error("FEAGI Requests: Unable to initiate region clone pending!")
		return output
	print("FEAGI REQUEST: Region clone pending initiated.")
	return output


## Attempts to update the property of a cortical area. Ensure your properties dict is properly formatted for FEAGI!
func update_cortical_area(editing_ID: StringName, properties: Dictionary) -> FeagiRequestOutput:
	# Requirement checking
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	if !editing_ID in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.keys():
		push_error("FEAGI Requests: Unable to clone cortical area %s that is not found in cache!!" % editing_ID)
		return FeagiRequestOutput.requirement_fail("ID_NOT_FOUND")
	
	# Define Request
	properties["cortical_id"] = editing_ID  # ensure
	
	# Double-check network components right before use (race condition protection)
	var network_check = _check_network_components_ready()
	if network_check != null:
		return network_check
	
	# Log what we're sending
	print("🔵 FEAGI REQUEST: update_cortical_area called for area: %s" % editing_ID)
	print("🔵 FEAGI REQUEST: Properties being sent: %s" % properties)
	if "visualization_voxel_granularity" in properties:
		print("🔵 FEAGI REQUEST: visualization_voxel_granularity value: %s (type: %s)" % [properties["visualization_voxel_granularity"], typeof(properties["visualization_voxel_granularity"])])
	
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_PUT_call(FeagiCore.network.http_API.address_list.PUT_genome_corticalArea, properties)
	print("🔵 FEAGI REQUEST: Making PUT request to %s for cortical area %s" % [FeagiCore.network.http_API.address_list.PUT_genome_corticalArea, editing_ID])
	print("🔵 FEAGI REQUEST: Full request body: %s" % properties)
	
	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	
	print("🔵 FEAGI REQUEST: Response received - has_errored: %s, has_timed_out: %s" % [FEAGI_response_data.has_errored, FEAGI_response_data.has_timed_out])
	if FEAGI_response_data.has_errored:
		var error_details = FEAGI_response_data.decode_response_as_generic_error_code()
		var raw_response = FEAGI_response_data.decode_response_as_string()
		push_error("FEAGI Requests: Unable to update cortical area of ID %s! Error: %s - %s" % [editing_ID, error_details[0], error_details[1]])
		print("🔴 FEAGI REQUEST: ❌ PUT request failed for %s - Error code: %s, Description: %s" % [editing_ID, error_details[0], error_details[1]])
		print("🔴 FEAGI REQUEST: ❌ Raw response body: %s" % raw_response)
		print("🔴 FEAGI REQUEST: ❌ Request data sent: %s" % properties)
		return FEAGI_response_data
	
	# Re-fetch the cortical area from FEAGI to ensure cache is synchronized with backend
	print("FEAGI REQUEST: PUT succeeded for %s, re-fetching from FEAGI to sync cache" % editing_ID)
	await get_cortical_area(editing_ID)
	print("FEAGI REQUEST: Successfully updated cortical area %s" % [ editing_ID])
	return FEAGI_response_data

func update_cortical_areas(editing_areas: Array[AbstractCorticalArea], properties: Dictionary) -> FeagiRequestOutput:
	# Requirement checking
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")

	# Log what we're sending
	var cortical_ids = AbstractCorticalArea.cortical_area_array_to_ID_array(editing_areas)
	print("🔵 FEAGI REQUEST: update_cortical_areas called for %d areas: %s" % [len(editing_areas), cortical_ids])
	print("🔵 FEAGI REQUEST: Properties being sent: %s" % properties)
	if "visualization_voxel_granularity" in properties:
		print("🔵 FEAGI REQUEST: visualization_voxel_granularity value: %s (type: %s)" % [properties["visualization_voxel_granularity"], typeof(properties["visualization_voxel_granularity"])])
	
	# Define Request
	properties["cortical_id_list"] = cortical_ids
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_PUT_call(FeagiCore.network.http_API.address_list.PUT_corticalArea_multi_corticalArea, properties)
	
	print("🔵 FEAGI REQUEST: Sending PUT request to: %s" % FeagiCore.network.http_API.address_list.PUT_corticalArea_multi_corticalArea)
	print("🔵 FEAGI REQUEST: Full request body: %s" % properties)
	
	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	
	print("🔵 FEAGI REQUEST: Response received - has_errored: %s, has_timed_out: %s" % [FEAGI_response_data.has_errored, FEAGI_response_data.has_timed_out])
	if FEAGI_response_data.has_errored:
		var error_details = FEAGI_response_data.decode_response_as_generic_error_code()
		var raw_response = FEAGI_response_data.decode_response_as_string()
		print("🔴 FEAGI REQUEST: API Error - Code: %s, Description: %s" % [error_details[0], error_details[1]])
		print("🔴 FEAGI REQUEST: Raw response: %s" % raw_response)
	
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		push_error("FEAGI Requests: Unable to update %d cortical area!" % len(editing_areas))
		return FEAGI_response_data
	
	# Re-fetch all updated cortical areas from FEAGI to ensure cache is synchronized with backend
	print("🔵 FEAGI REQUEST: Multi-PUT succeeded for %d areas, re-fetching from FEAGI to sync cache" % len(editing_areas))
	await get_cortical_areas(editing_areas)
	print("🔵 FEAGI REQUEST: Successfully updated %d cortical area!" % len(editing_areas))
	return FEAGI_response_data


## Attempts to delete a cortical area
func delete_cortical_area(deleting_area: AbstractCorticalArea) -> FeagiRequestOutput:
	# Requirement checking
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	if !deleting_area.cortical_ID in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.keys():
		push_error("FEAGI Requests: Unable to delete cortical area %s that is not found in cache!" % deleting_area.cortical_ID)
		return FeagiRequestOutput.requirement_fail("ID_NOT_FOUND")
	
	# Define Request
	var dict_to_send: Dictionary = {"cortical_id": deleting_area.cortical_ID}
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_DELETE_call(FeagiCore.network.http_API.address_list.DELETE_GE_corticalArea, dict_to_send)

	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		push_error("FEAGI Requests: Unable to delete cortical area of ID %s!" % deleting_area.cortical_ID)
		return FEAGI_response_data
	var response: Dictionary = FEAGI_response_data.decode_response_as_dict()
	print("FEAGI REQUEST: Successfully removed cortical area %s" % deleting_area.cortical_ID)
	FeagiCore.feagi_local_cache.FEAGI_delete_all_mappings_involving_area_and_area(deleting_area)
	return FEAGI_response_data

func mass_delete_cortical_areas(deleting_areas: Array[AbstractCorticalArea]) -> FeagiRequestOutput:
	# Requirement checking
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	
	# Define Request
	var ID_list: Array[StringName] = AbstractCorticalArea.cortical_area_array_to_ID_array(deleting_areas)
	var dict_to_send: Dictionary = {
		"cortical_id_list": ID_list
	}
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_DELETE_call(FeagiCore.network.http_API.address_list.DELETE_corticalArea_multi_corticalArea, dict_to_send)

	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		push_error("FEAGI Requests: Unable to delete %d cortical areass!" % len(deleting_areas))
		return FEAGI_response_data
	var response: Dictionary = FEAGI_response_data.decode_response_as_dict()
	print("FEAGI REQUEST: Successfully removed %s cortical areas" % len(deleting_areas))
	for deleting in deleting_areas:
		FeagiCore.feagi_local_cache.FEAGI_delete_all_mappings_involving_area_and_area(deleting)
	return FEAGI_response_data

# Send Request to reset cortical areas
func mass_reset_cortical_areas(cortical_areas: Array[AbstractCorticalArea]) -> FeagiRequestOutput:
	# Requirement checking
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	
	# Define Request
	var ID_list: Array[StringName] = AbstractCorticalArea.cortical_area_array_to_ID_array(cortical_areas)
	var dict_to_send: Dictionary = {
		"area_list": ID_list
	}
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_PUT_call(FeagiCore.network.http_API.address_list.PUT_corticalArea_reset, dict_to_send)

	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		push_error("FEAGI Requests: Unable to reset %d cortical areass!" % len(cortical_areas))
		return FEAGI_response_data
	var response: Dictionary = FEAGI_response_data.decode_response_as_dict()
	print("FEAGI REQUEST: Successfully reset %s cortical areas" % len(cortical_areas))
	return FEAGI_response_data
	
	

## Refresh templates for IPU/OPU generation. Note that this is technically already done on genome load
func get_cortical_templates() -> FeagiRequestOutput:
	# Requirement checking
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	
	# Get IPU types
	var ipu_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(FeagiCore.network.http_API.address_list.GET_corticalAreas_ipu_types)
	var ipu_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(ipu_request)
	await ipu_worker.worker_done
	var ipu_data: FeagiRequestOutput = ipu_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(ipu_data):
		push_error("FEAGI Requests: Unable to get IPU types!")
		return ipu_data
	
	# Get OPU types
	var opu_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(FeagiCore.network.http_API.address_list.GET_corticalAreas_opu_types)
	var opu_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(opu_request)
	await opu_worker.worker_done
	var opu_data: FeagiRequestOutput = opu_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(opu_data):
		push_error("FEAGI Requests: Unable to get OPU types!")
		return opu_data
	
	# Transform and aggregate responses
	var ipu_types_dict: Dictionary = ipu_data.decode_response_as_dict()
	var opu_types_dict: Dictionary = opu_data.decode_response_as_dict()
	
	# name_to_id_mapping should map type_id -> [cortical_instance_ids] from genome
	# Leave empty for now - will be populated from genome data if needed
	var aggregated: Dictionary = {
		"types": {
			"IPU": {
				"supported_devices": ipu_types_dict,
				"name_to_id_mapping": {}  # Empty - populated from genome, not templates
			},
			"OPU": {
				"supported_devices": opu_types_dict,
				"name_to_id_mapping": {}  # Empty - populated from genome, not templates
			}
		}
	}
	
	print("FEAGI REQUEST: Successfully retrieved cortical template data!")
	FeagiCore.feagi_local_cache.update_templates_from_FEAGI(aggregated)
	return ipu_data  # Return successful result

## Get cortical template metadata including supported data types and configurations
func get_cortical_template_metadata() -> FeagiRequestOutput:
	# Requirement checking
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	
	# Define Request
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(FeagiCore.network.http_API.address_list.GET_genome_corticalTemplate)
	
	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		push_error("FEAGI Requests: Unable to get cortical template metadata!")
		return FEAGI_response_data
	print("FEAGI REQUEST: Successfully retrieved cortical template metadata!")
	return FEAGI_response_data

## Toggle the synaptic activity monitoring of cortical areas
func toggle_synaptic_monitoring(cortical_areas: Array[AbstractCorticalArea], should_monitor: bool) -> FeagiRequestOutput:
	# Requirement checking
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	if !FeagiCore.feagi_local_cache.influxdb_availability:
		push_error("FEAGI Requests: InfluxDB is not available for toggling synaptic monitoring!")
		return FeagiRequestOutput.requirement_fail("NO_INFLUXDB")
	
	# Define Request
	var dict_to_send: Dictionary = {
		"cortical_id_list" : AbstractCorticalArea.array_of_cortical_areas_to_array_of_cortical_IDs(cortical_areas)
	}
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_POST_call(FeagiCore.network.http_API.address_list.POST_MON_neuron_membranePotential, dict_to_send)
	
	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		push_error("FEAGI Requests: Unable to set synaptic monitoring on %d cortical areas!" % len(cortical_areas))
		return FEAGI_response_data
	var response: Dictionary = FEAGI_response_data.decode_response_as_dict()
	print("FEAGI REQUEST: Successfully set synaptic monitoring on %d cortical areas!" % len(cortical_areas))
	for cortical_area in cortical_areas:
		cortical_area.is_monitoring_synaptic_potential = should_monitor
	return FEAGI_response_data


## Toggle the membrane activity monitoring of cortical areas
func toggle_membrane_monitoring(cortical_areas: Array[AbstractCorticalArea], should_monitor: bool) -> FeagiRequestOutput:
	# Requirement checking
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")

		return FeagiRequestOutput.requirement_fail("SOURCE_NOT_FOUND")
	if !FeagiCore.feagi_local_cache.influxdb_availability:
		push_error("FEAGI Requests: InfluxDB is not available for toggling membrane monitoring!")
		return FeagiRequestOutput.requirement_fail("NO_INFLUXDB")
	
	# Define Request
	var dict_to_send: Dictionary = {
		"cortical_id_list" : AbstractCorticalArea.array_of_cortical_areas_to_array_of_cortical_IDs(cortical_areas)
	}
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_POST_call(FeagiCore.network.http_API.address_list.POST_monitoring_neuron_membranePotential_set, dict_to_send)
	
	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		push_error("FEAGI Requests: Unable to set membrane monitoring on %d cortical areas!" % len(cortical_areas))
		return FEAGI_response_data
	var response: Dictionary = FEAGI_response_data.decode_response_as_dict()
	print("FEAGI REQUEST: Successfully set membrane monitoring on %d cortical areas!" % len(cortical_areas))
	for cortical_area in cortical_areas:
		cortical_area.is_monitoring_membrane_potential = should_monitor
	return FEAGI_response_data

func set_cortical_areas_that_are_invisible(cortical_areas: Array[AbstractCorticalArea]) -> FeagiRequestOutput:
	# Requirement checking
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	
	# Define Request
	var array_of_IDs = AbstractCorticalArea.cortical_area_array_to_ID_array(cortical_areas)
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_PUT_call(FeagiCore.network.http_API.address_list.PUT_corticalArea_suppressCorticalVisibility, array_of_IDs)
	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		push_error("FEAGI Requests: Unable to set visibility for cortical areas!")
		return FEAGI_response_data
	var response: Dictionary = FEAGI_response_data.decode_response_as_dict()
	print("FEAGI REQUEST: Successfully updated the visibility of cortical areas!")
	FeagiCore.feagi_local_cache.cortical_areas.FEAGI_set_invisible_cortical_areas(cortical_areas)
	return FEAGI_response_data


#endregion

#region Morphologies

## Refresh the information of a specific morphology
func get_morphology(morphology_name: StringName) -> FeagiRequestOutput:
	# Requirement checking
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	if !morphology_name in FeagiCore.feagi_local_cache.morphologies.available_morphologies.keys():
		push_error("FEAGI Requests: Unable to find morphology %s to refresh!" % morphology_name)
		return FeagiRequestOutput.requirement_fail("NAME_NOT_FOUND")
	
	# Define Request
	var dict_to_send: Dictionary = {"morphology_name": morphology_name}
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_POST_call(FeagiCore.network.http_API.address_list.POST_morphology_morphologyProperties, dict_to_send)
	
	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		push_error("FEAGI Requests: Unable to get morphology details of name %s!" % morphology_name)
		return FEAGI_response_data
	var response: Dictionary = FEAGI_response_data.decode_response_as_dict()
	print("FEAGI REQUEST: Successfully retrieved morphology properties of %s" % morphology_name)
	FeagiCore.feagi_local_cache.morphologies.update_morphology_by_dict(response)
	return FEAGI_response_data


## Update the usage of a morphology in the genome
func get_morphology_usage(morphology_name: StringName) -> FeagiRequestOutput:
	# Requirement checking
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	if !morphology_name in FeagiCore.feagi_local_cache.morphologies.available_morphologies.keys():
		push_error("FEAGI Requests: Unable to find morphology %s to get the usage of!" % morphology_name)
		return FeagiRequestOutput.requirement_fail("NAME_NOT_FOUND")
	
	# Define Request
	var dict_to_send: Dictionary = {"morphology_name": morphology_name}
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_POST_call(FeagiCore.network.http_API.address_list.POST_morphology_morphologyUsage, dict_to_send)
	
	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		push_error("FEAGI Requests: Unable to get morphology usage of name %s!" % morphology_name)
		return FEAGI_response_data
	var response: Array = FEAGI_response_data.decode_response_as_array()
	print("FEAGI REQUEST: Successfully retrieved morphology usage of %s" % morphology_name)
	var output: Array[Array] = [] # Why can't godot figure out these types?
	output.assign(response)
	FeagiCore.feagi_local_cache.morphologies.available_morphologies[morphology_name].feagi_update_usage(output)
	return FEAGI_response_data


## Adds a Vector morphology
func add_vector_morphology(morphology_name: StringName, vectors: Array[Vector3i]) -> FeagiRequestOutput:
	# Requirement checking
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	if morphology_name in FeagiCore.feagi_local_cache.morphologies.available_morphologies.keys():
		push_error("FEAGI Requests: Morphology of name %s already exists!" % morphology_name)
		return FeagiRequestOutput.requirement_fail("NAME_EXISTS")
	if len(vectors) == 0:
		push_error("FEAGI Requests: Cannot create vector morphology of name %s with 0 vectors!" % morphology_name)
		return FeagiRequestOutput.requirement_fail("0_VECTORS")
	
	# Define Request
	var dict_to_send: Dictionary = {
		"morphology_name": morphology_name,
		"morphology_type": BaseMorphology.morphology_type_to_string(BaseMorphology.MORPHOLOGY_TYPE.VECTORS),
		"morphology_parameters": {
			"vectors": FEAGIUtils.vector3i_array_to_array_of_arrays(vectors)
		}
	}
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_POST_call(FeagiCore.network.http_API.address_list.POST_genome_morphology, dict_to_send)
	
	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		push_error("FEAGI Requests: Unable to create vector morphology of name %s!" % morphology_name)
		return FEAGI_response_data
	print("FEAGI REQUEST: Successfully created morphology of name %s" % morphology_name)
	FeagiCore.feagi_local_cache.morphologies.add_defined_vector_morphology(morphology_name, vectors)
	return FEAGI_response_data
	
	
## Adds a Pattern morphology
func add_pattern_morphology(morphology_name: StringName, patterns: Array[PatternVector3Pairs]) -> FeagiRequestOutput:
	# Requirement checking
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	if morphology_name in FeagiCore.feagi_local_cache.morphologies.available_morphologies.keys():
		push_error("FEAGI Requests: Morphology of name %s already exists!" % morphology_name)
		return FeagiRequestOutput.requirement_fail("NAME_EXISTS")
	if len(patterns) == 0:
		push_error("FEAGI Requests: Cannot create pattern morphology of name %s with 0 vector pairs!" % morphology_name)
		return FeagiRequestOutput.requirement_fail("0_VECTORS")
	
	# Define Request
	var dict_to_send: Dictionary = {
		"morphology_name": morphology_name,
		"morphology_type": BaseMorphology.morphology_type_to_string(BaseMorphology.MORPHOLOGY_TYPE.PATTERNS),
		"morphology_parameters": {
			"patterns": FEAGIUtils.array_of_PatternVector3Pairs_to_array_of_array_of_array_of_array_of_elements(patterns)
		}
	}
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_POST_call(FeagiCore.network.http_API.address_list.POST_genome_morphology, dict_to_send)
	
	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		push_error("FEAGI Requests: Unable to create pattern morphology of name %s!" % morphology_name)
		return FEAGI_response_data
	print("FEAGI REQUEST: Successfully created morphology of name %s" % morphology_name)
	FeagiCore.feagi_local_cache.morphologies.add_defined_pattern_morphology(morphology_name, patterns)
	return FEAGI_response_data


## Adds a Composite morphology
func add_composite_morphology(morphology_name: StringName, source_seed: Vector3i, source_pattern: Array[Vector2i], mapped_morphology_name: StringName ) -> FeagiRequestOutput:
	# Requirement checking
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	if morphology_name in FeagiCore.feagi_local_cache.morphologies.available_morphologies.keys():
		push_error("FEAGI Requests: Morphology of name %s already exists!" % morphology_name)
		return FeagiRequestOutput.requirement_fail("NAME_EXISTS")
	if len(source_pattern) == 0:
		push_error("FEAGI Requests: Cannot create composite morphology of name %s with 0 vectors!" % morphology_name)
		return FeagiRequestOutput.requirement_fail("0_VECTORS")
	if !source_pattern in FeagiCore.feagi_local_cache.morphologies.available_morphologies.keys():
		push_error("FEAGI Requests: Unable to find mapped morphology target by name of %s" % mapped_morphology_name)
		return FeagiRequestOutput.requirement_fail("MAPPED_NONEXISTANT")
	
	# Define Request
	var dict_to_send: Dictionary = {
		"morphology_name": morphology_name,
		"morphology_type": BaseMorphology.morphology_type_to_string(BaseMorphology.MORPHOLOGY_TYPE.COMPOSITE),
		"morphology_parameters": {
			"composite": {
				"src_seed": FEAGIUtils.vector3i_to_array(source_seed),
				"src_pattern": FEAGIUtils.vector2i_array_to_array_of_arrays(source_pattern),
				"mapper_morphology": mapped_morphology_name
			}
		}
	}
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_POST_call(FeagiCore.network.http_API.address_list.POST_genome_morphology, dict_to_send)
	
	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		push_error("FEAGI Requests: Unable to create composite morphology of name %s!" % morphology_name)
		return FEAGI_response_data
	print("FEAGI REQUEST: Successfully added composite morphology of name %s" % morphology_name)
	FeagiCore.feagi_local_cache.morphologies.add_defined_composite_morphology(morphology_name, source_seed, source_pattern, mapped_morphology_name)
	return FEAGI_response_data


## Update Vector morphology
func update_vector_morphology(morphology_name: StringName, vectors: Array[Vector3i]) -> FeagiRequestOutput:
	# Requirement checking
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	if !morphology_name in FeagiCore.feagi_local_cache.morphologies.available_morphologies.keys():
		push_error("FEAGI Requests: Morphology of name %s doesn't exist to update!" % morphology_name)
		return FeagiRequestOutput.requirement_fail("MORPHOLOGY_MISSING")
	if len(vectors) == 0:
		push_error("FEAGI Requests: Cannot update vector morphology of name %s with 0 vectors!" % morphology_name)
		return FeagiRequestOutput.requirement_fail("0_VECTORS")
	
	# Define Request
	var dict_to_send: Dictionary = {
		"morphology_name": morphology_name,
		"morphology_type": BaseMorphology.morphology_type_to_string(BaseMorphology.MORPHOLOGY_TYPE.VECTORS),
		"morphology_parameters": {
			"vectors": FEAGIUtils.vector3i_array_to_array_of_arrays(vectors)
		}
	}
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_PUT_call(FeagiCore.network.http_API.address_list.PUT_genome_morphology, dict_to_send)
	
	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		push_error("FEAGI Requests: Unable to update vector morphology of name %s!" % morphology_name)
		return FEAGI_response_data
	print("FEAGI REQUEST: Successfully updated vector morphology of name %s" % morphology_name)
	FeagiCore.feagi_local_cache.morphologies.available_morphologies[morphology_name].feagi_confirmed_value_update(vectors)
	return FEAGI_response_data
	
	
## Update a vector morphology
func update_pattern_morphology(morphology_name: StringName, patterns: Array[PatternVector3Pairs]) -> FeagiRequestOutput:
	# Requirement checking
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	if !morphology_name in FeagiCore.feagi_local_cache.morphologies.available_morphologies.keys():
		push_error("FEAGI Requests: Morphology of name %s doesn't exist to update!" % morphology_name)
		return FeagiRequestOutput.requirement_fail("MORPHOLOGY_MISSING")
	if len(patterns) == 0:
		push_error("FEAGI Requests: Cannot update pattern morphology of name %s with 0 vector pairs!" % morphology_name)
		return FeagiRequestOutput.requirement_fail("0_VECTORS")
	
	# Define Request
	var dict_to_send: Dictionary = {
		"morphology_name": morphology_name,
		"morphology_type": BaseMorphology.morphology_type_to_string(BaseMorphology.MORPHOLOGY_TYPE.PATTERNS),
		"morphology_parameters": {
			"patterns": FEAGIUtils.array_of_PatternVector3Pairs_to_array_of_array_of_array_of_array_of_elements(patterns)
		}
	}
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_PUT_call(FeagiCore.network.http_API.address_list.PUT_genome_morphology, dict_to_send)
	
	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		push_error("FEAGI Requests: Unable to update pattern morphology of name %s!" % morphology_name)
		return FEAGI_response_data
	print("FEAGI REQUEST: Successfully updated pattern morphology of name %s" % morphology_name)
	FeagiCore.feagi_local_cache.morphologies.available_morphologies[morphology_name].feagi_confirmed_value_update(patterns)
	return FEAGI_response_data


## Update a Composite morphology
func update_composite_morphology(morphology_name: StringName, source_seed: Vector3i, source_pattern: Array[Vector2i], mapped_morphology_name: StringName ) -> FeagiRequestOutput:
	# Requirement checking
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	if !morphology_name in FeagiCore.feagi_local_cache.morphologies.available_morphologies.keys():
		push_error("FEAGI Requests: Morphology of name %s doesn't exist to update!" % morphology_name)
		return FeagiRequestOutput.requirement_fail("MORPHOLOGY_MISSING")
	if len(source_pattern) == 0:
		push_error("FEAGI Requests: Cannot update composite morphology of name %s with 0 vectors!" % morphology_name)
		return FeagiRequestOutput.requirement_fail("0_VECTORS")
	if !source_pattern in FeagiCore.feagi_local_cache.morphologies.available_morphologies.keys():
		push_error("FEAGI Requests: Unable to find mapped morphology target by name of %s" % mapped_morphology_name)
		return FeagiRequestOutput.requirement_fail("MAPPED_NONEXISTANT")
	
	# Define Request
	var dict_to_send: Dictionary = {
		"morphology_name": morphology_name,
		"morphology_type": BaseMorphology.morphology_type_to_string(BaseMorphology.MORPHOLOGY_TYPE.COMPOSITE),
		"morphology_parameters": {
			"composite": {
				"src_seed": FEAGIUtils.vector3i_to_array(source_seed),
				"src_pattern": FEAGIUtils.vector2i_array_to_array_of_arrays(source_pattern),
				"mapper_morphology": mapped_morphology_name
			}
		}
	}
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_PUT_call(FeagiCore.network.http_API.address_list.PUT_genome_morphology, dict_to_send)
	
	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		push_error("FEAGI Requests: Unable to update composite morphology of name %s!" % morphology_name)
		return FEAGI_response_data
	print("FEAGI REQUEST: Successfully updated composite morphology of name %s" % morphology_name)
	FeagiCore.feagi_local_cache.morphologies.available_morphologies[morphology_name].feagi_confirmed_value_update(source_seed, source_pattern)
	return FEAGI_response_data


## Delete a morphology
func delete_morphology(morphology: BaseMorphology) -> FeagiRequestOutput:
	# Requirement checking
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	if !morphology.name in FeagiCore.feagi_local_cache.morphologies.available_morphologies.keys():
		push_error("FEAGI Requests: Morphology of name %s doesn't exist to delete!" % morphology.name)
		return FeagiRequestOutput.requirement_fail("MORPHOLOGY_MISSING")
	if morphology.get_latest_known_deletability() in [BaseMorphology.DELETABILITY.NOT_DELETABLE_USED, BaseMorphology.DELETABILITY.NOT_DELETABLE_UNKNOWN]:
		push_error("FEAGI Requests: Unable to delete morphology %s that is not allowed for deletion!" % morphology.name)
		return FeagiRequestOutput.requirement_fail("DELETE_DISALLOWED")
	
	# Define Request
	var dict_to_send: Dictionary = {"morphology_name": morphology.name}
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_DELETE_call(FeagiCore.network.http_API.address_list.DELETE_GE_morphology, dict_to_send)
	
	# Cache data
	var deleting_name: StringName = morphology.name
	
	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		push_error("FEAGI Requests: Unable to delete morphology of name %s!" % morphology.name)
		return FEAGI_response_data
	var response: Dictionary = FEAGI_response_data.decode_response_as_dict()
	print("FEAGI REQUEST: Successfully deleted morphology of name %s" % deleting_name)
	FeagiCore.feagi_local_cache.morphologies.remove_morphology(deleting_name)
	return FEAGI_response_data

#endregion

#region Connections

## Get mappings between 2 cortical areas. Can also be used to get mappings froma  cortical area to itself
func get_mappings_between_2_cortical_areas(source_cortical_ID: StringName, destination_cortical_ID: StringName) -> FeagiRequestOutput:
	# Requirement checking
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	if !source_cortical_ID in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.keys():
		push_error("FEAGI Requests: Unable to get mappings from uncached cortical area %s that is not found in cache!!" % source_cortical_ID)
		return FeagiRequestOutput.requirement_fail("SOURCE_NOT_FOUND")
	if !destination_cortical_ID in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.keys():
		push_error("FEAGI Requests: Unable to get mappings toward uncached cortical area %s that is not found in cache!!" % destination_cortical_ID)
		return FeagiRequestOutput.requirement_fail("DESTINATION_NOT_FOUND")

	# Define Request
	var dict_to_send: Dictionary = {
		"src_cortical_area": source_cortical_ID,
		"dst_cortical_area": destination_cortical_ID
		}
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_POST_call(FeagiCore.network.http_API.address_list.POST_corticalMappings_mappingProperties, dict_to_send)
	
	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		push_error("FEAGI Requests: Unable to retrieve mappings of %s toward %s" % [source_cortical_ID, destination_cortical_ID])
		return FEAGI_response_data
	# Unlikely not, but checking to make sure cortical areas still exist
	if source_cortical_ID not in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.keys() or destination_cortical_ID not in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.keys():
		push_error("FEAGI Requests: Retrieved cortical mapping refers to a cortical area no longer in the cache!")
		return FeagiRequestOutput.requirement_fail("AREA_NO_LONGER_EXIST")
	var response: Array = FEAGI_response_data.decode_response_as_array()
	var source_area: AbstractCorticalArea =  FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas[source_cortical_ID]
	var destination_area: AbstractCorticalArea =  FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas[destination_cortical_ID]
	var raw_dicts: Array[Dictionary] = []
	raw_dicts.assign(response)
	
	print("FEAGI REQUEST: Successfully retrieved mappings of %s toward %s" % [source_cortical_ID, destination_cortical_ID])
	FeagiCore.feagi_local_cache.mapping_data.FEAGI_set_mapping_JSON(source_area, destination_area, raw_dicts)

	# CRITICAL NEW FEATURE: Process brain region I/O data from response if available (robust extraction)
	var full_response: Dictionary = FEAGI_response_data.decode_response_as_dict()
	var regions_map: Dictionary = _extract_brain_regions_io_from_mapping_response(full_response)
	if regions_map.size() > 0:
		print("🔗 MAPPING GET: Processing %d region(s) I/O data from FEAGI response" % regions_map.size())
		# Temporarily disable ALL competing refresh signals during update
		_disable_region_refresh_signals()
		_disable_local_cache_refresh_signals()
		_process_brain_region_io_updates(regions_map)
		# Re-enable signals after update is complete
		call_deferred("_enable_region_refresh_signals")
		call_deferred("_enable_local_cache_refresh_signals")
	
	return FEAGI_response_data


## Set (overwrite) the mappings between 2 areas
func set_mappings_between_corticals(source_area: AbstractCorticalArea, destination_area: AbstractCorticalArea,  mappings: Array[SingleMappingDefinition]) -> FeagiRequestOutput:
	var source_cortical_ID = source_area.cortical_ID
	var destination_cortical_ID = destination_area.cortical_ID
	
	# Requirement checking
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	if !source_cortical_ID in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.keys():
		push_error("FEAGI Requests: Unable to get mappings from uncached cortical area %s that is not found in cache!" % source_cortical_ID)
		return FeagiRequestOutput.requirement_fail("SOURCE_NOT_FOUND")
	if !destination_cortical_ID in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.keys():
		push_error("FEAGI Requests: Unable to get mappings toward uncached cortical area %s that is not found in cache!" % destination_cortical_ID)
		return FeagiRequestOutput.requirement_fail("DESTINATION_NOT_FOUND")
	
	# Define Request
	var dict_to_send: Dictionary = {
		"src_cortical_area": source_cortical_ID,
		"dst_cortical_area": destination_cortical_ID,
		"mapping_string": SingleMappingDefinition.to_FEAGI_JSON_array(mappings)
		}
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_PUT_call(FeagiCore.network.http_API.address_list.PUT_genome_mappingProperties, dict_to_send)
	
	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		push_error("FEAGI Requests: Unable to set mappings of %s toward %s" % [source_cortical_ID, destination_cortical_ID])
		return FEAGI_response_data
	# Unlikely not, but checking to make sure cortical areas still exist
	if source_cortical_ID not in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.keys() or destination_cortical_ID not in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.keys():
		push_error("FEAGI Requests: Retrieved cortical mapping refers to a cortical area no longer in the cache!")
		return FeagiRequestOutput.requirement_fail("AREA_NO_LONGER_EXIST")
	var response: Dictionary = FEAGI_response_data.decode_response_as_dict()
	print("FEAGI REQUEST: Successfully set the mappings of %s toward %s with %d mappings!" % [source_cortical_ID, destination_cortical_ID, len(mappings)])
	
	# CRITICAL NEW FEATURE: Process brain region I/O data from response for dynamic plate reconfiguration (robust extraction)
	var regions_map_put: Dictionary = _extract_brain_regions_io_from_mapping_response(response)
	if regions_map_put.size() > 0:
		print("🔗 MAPPING UPDATE: Processing %d region(s) I/O data from FEAGI response" % regions_map_put.size())
		# Temporarily disable ALL competing refresh signals during update
		_disable_region_refresh_signals()
		_disable_local_cache_refresh_signals()
		_process_brain_region_io_updates(regions_map_put)
		# Update local cache AFTER processing brain region updates to prevent conflicts
		FeagiCore.feagi_local_cache.mapping_data.FEAGI_set_mapping(source_area, destination_area, mappings)
		# Re-enable signals after update is complete
		call_deferred("_enable_region_refresh_signals") 
		call_deferred("_enable_local_cache_refresh_signals")
	else:
		print("⚠️  MAPPING UPDATE: No brain region data in response - using fallback refresh")
		# Update local cache first, then refresh
		FeagiCore.feagi_local_cache.mapping_data.FEAGI_set_mapping(source_area, destination_area, mappings)
		# Fallback: refresh regions containing the source and destination areas
		await _refresh_regions_containing_areas([source_area, destination_area])
	
	#var mapping_set: InterCorticalMappingSet = FeagiCore.feagi_local_cache.mapping_data.established_mappings[source_area.cortical_ID][destination_area.cortical_ID]
	#mapping_set.mappings_changed.emit(mapping_set)
	#mapping_set._connection_chain.FEAGI_updated_associated_mapping_set()
	#FeagiCore.feagi_local_cache.mapping_data.mapping_updated.emit(mapping_set)
	return FEAGI_response_data

## Processes brain region I/O updates from FEAGI API response and reconfigures plates
func _process_brain_region_io_updates(brain_regions_data) -> void:
	print("🔄 BRAIN REGION I/O UPDATE: Processing %d region(s) from FEAGI response" % brain_regions_data.size())
	
	for region_id in brain_regions_data.keys():
		var region_data = brain_regions_data[region_id]
		print("  🧠 Processing region: %s" % region_id)
		print("    📋 Region data keys: %s" % [region_data.keys()])
		
		# Find the brain region in cache
		if region_id not in FeagiCore.feagi_local_cache.brain_regions.available_brain_regions.keys():
			print("    ⚠️  Region %s not found in cache, skipping" % region_id)
			continue
			
		var brain_region: BrainRegion = FeagiCore.feagi_local_cache.brain_regions.available_brain_regions[region_id]
		print("    🏷️ Region friendly name: %s" % brain_region.friendly_name)
		
		# Log current state before update
		print("    📊 BEFORE UPDATE:")
		print("      📊 Current partial_mappings count: %d" % brain_region.partial_mappings.size())
		for i in range(brain_region.partial_mappings.size()):
			var mapping = brain_region.partial_mappings[i]
			print("        🔗 Mapping %d: %s (%s)" % [i, mapping.internal_target_cortical_area.cortical_ID, "INPUT" if mapping.is_region_input else "OUTPUT"])
		
		# Update the brain region's input/output arrays if provided (String -> StringName conversion)
		if region_data.has("inputs"):
			var inputs_raw = region_data["inputs"]
			var inputs: Array[StringName] = []
			for id in inputs_raw:
				inputs.append(StringName(id))
			print("    📥 Updating %d input areas: %s" % [inputs.size(), inputs])
			# Update the brain region's partial mappings to reflect new I/O status
			_update_brain_region_io_mappings(brain_region, inputs, true)  # true = input
			
		if region_data.has("outputs"):
			var outputs_raw = region_data["outputs"]
			var outputs: Array[StringName] = []
			for id2 in outputs_raw:
				outputs.append(StringName(id2))
			print("    📤 Updating %d output areas: %s" % [outputs.size(), outputs])
			# Update the brain region's partial mappings to reflect new I/O status
			_update_brain_region_io_mappings(brain_region, outputs, false)  # false = output
		
		# Log state after update
		print("    📊 AFTER UPDATE:")
		print("      📊 Updated partial_mappings count: %d" % brain_region.partial_mappings.size())
		for i in range(brain_region.partial_mappings.size()):
			var mapping = brain_region.partial_mappings[i]
			print("        🔗 Mapping %d: %s (%s)" % [i, mapping.internal_target_cortical_area.cortical_ID, "INPUT" if mapping.is_region_input else "OUTPUT"])
		
		# Trigger plate reconfiguration for this region
		print("    🔄 Triggering visualization refresh...")
		call_deferred("_refresh_region_visualization", region_id)
		print("    ✅ Region %s plate reconfiguration triggered" % region_id)

## Extracts a canonical map of region_id -> {"inputs": [], "outputs": []} from FEAGI mapping API responses
func _extract_brain_regions_io_from_mapping_response(response: Dictionary) -> Dictionary:
	var regions: Dictionary = {}
	if response.size() == 0:
		return regions

	# Case 1: { "brain_regions": { "region_id": { "inputs": [...], "outputs": [...] }, ... } }
	if response.has("brain_regions") and response["brain_regions"] is Dictionary:
		var br: Dictionary = response["brain_regions"]
		for region_id in br.keys():
			var region_data: Dictionary = br[region_id]
			regions[region_id] = {
				"inputs": region_data.get("inputs", []),
				"outputs": region_data.get("outputs", [])
			}
		return regions

	# Case 2: { "regions": [ {"region_id"|"id": "...", "inputs": [...], "outputs": [...]}, ... ] }
	if response.has("regions") and response["regions"] is Array:
		for entry in (response["regions"] as Array):
			if entry is Dictionary:
				var d: Dictionary = entry
				var rid = d.get("region_id", d.get("id", null))
				if rid != null:
					regions[rid] = {
						"inputs": d.get("inputs", []),
						"outputs": d.get("outputs", [])
					}
		return regions

	# Case 3: { "region" : { "region_id": "...", "inputs": [...], "outputs": [...] } }
	if response.has("region") and response["region"] is Dictionary:
		var r: Dictionary = response["region"]
		var rid2 = r.get("region_id", r.get("id", null))
		if rid2 != null:
			regions[rid2] = {
				"inputs": r.get("inputs", []),
				"outputs": r.get("outputs", [])
			}
		return regions

	# Case 4: { "source_region": {...}, "destination_region": {...} }
	if response.has("source_region") or response.has("destination_region") or response.has("src_region") or response.has("dst_region"):
		for key in ["source_region", "destination_region", "src_region", "dst_region"]:
			if response.has(key) and response[key] is Dictionary:
				var rr: Dictionary = response[key]
				var rid3 = rr.get("region_id", rr.get("id", null))
				if rid3 != null:
					regions[rid3] = {
						"inputs": rr.get("inputs", []),
						"outputs": rr.get("outputs", [])
					}
		return regions

	# Nothing usable found
	return regions

## Updates brain region I/O mappings based on FEAGI response data
func _update_brain_region_io_mappings(brain_region: BrainRegion, area_ids: Array, is_input: bool) -> void:
	var mapping_type = "input" if is_input else "output"
	print("    🔧 Updating %s mappings for region %s with %d areas" % [mapping_type, brain_region.friendly_name, area_ids.size()])
	
	# Clear existing partial mappings of this type
	var mappings_to_remove = []
	for mapping in brain_region.partial_mappings:
		if mapping.is_region_input == is_input:
			mappings_to_remove.append(mapping)
	
	for mapping in mappings_to_remove:
		# Ensure the associated ConnectionChainLink(s) are deregistered cleanly.
		# Otherwise the 3D plate composition can remain stale (open links not removed).
		mapping.FEAGI_deleted_mapping_set()
		brain_region.partial_mappings.erase(mapping)
	
	# Create new partial mappings based on FEAGI response
	for area_id_str in area_ids:
		var area_id = StringName(area_id_str)
		if area_id in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.keys():
			var area: AbstractCorticalArea = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas[area_id]
			# Create new partial mapping
			var partial_mapping = PartialMappingSet.new(
				is_input,          # is_input_of_region
				[],                # mappings_suggested (empty for now)
				area,              # internal_target
				brain_region,      # brain_region
				area_id           # label
			)
			brain_region.partial_mappings.append(partial_mapping)
			print("      ✅ Added %s mapping for area: %s" % [mapping_type, area_id])
		else:
			print("      ⚠️  Area %s not found in cache, skipping" % area_id)

## Fallback: Refreshes brain regions that contain the specified areas
func _refresh_regions_containing_areas(areas: Array[AbstractCorticalArea]) -> void:
	print("🔄 FALLBACK REFRESH: Finding regions containing %d areas" % areas.size())
	var regions_to_refresh: Array[StringName] = []
	
	for area in areas:
		print("  🔍 Finding regions containing area: %s" % area.cortical_ID)
		
		# Find all regions that contain this area
		for region_id in FeagiCore.feagi_local_cache.brain_regions.available_brain_regions.keys():
			var region: BrainRegion = FeagiCore.feagi_local_cache.brain_regions.available_brain_regions[region_id]
			if area in region.contained_cortical_areas:
				if region_id not in regions_to_refresh:
					regions_to_refresh.append(region_id)
					print("    📍 Found in region: %s" % region.friendly_name)
	
	# Refresh all affected regions
	if regions_to_refresh.is_empty():
		print("  ⚠️  No regions found containing the specified areas")
		return

	# Pull authoritative I/O lists from FEAGI and update partial mappings (drives plate composition)
	var summary_out: FeagiRequestOutput = await get_regions_summary()
	if summary_out.has_errored:
		print("  ⚠️  Unable to refresh regions summary from FEAGI - leaving visualization unchanged")
		return
	var summary_dict: Dictionary = summary_out.decode_response_as_dict()

	var subset: Dictionary = {}
	for region_id in regions_to_refresh:
		if summary_dict.has(region_id):
			subset[region_id] = summary_dict[region_id]

	if subset.is_empty():
		print("  ⚠️  FEAGI region summary did not include any of the target regions")
		return

	print("  🔄 Applying refreshed I/O membership for %d region(s)" % subset.size())
	_process_brain_region_io_updates(subset)
	
	# Note: _process_brain_region_io_updates() will trigger per-region visualization refresh.

## CRITICAL: Disables recursive refresh signals to prevent infinite loops during FEAGI data updates
func _disable_region_refresh_signals() -> void:
	print("🔇 SIGNAL CONTROL: Disabling recursive refresh signals during update")
	var scene_tree = Engine.get_main_loop() as SceneTree
	if not scene_tree or not scene_tree.root:
		return
	
	var brain_monitor_scenes = scene_tree.root.find_children("*", "UI_BrainMonitor_3DScene", true, false)
	
	for scene in brain_monitor_scenes:
		if scene is UI_BrainMonitor_3DScene:
			var monitor_scene = scene as UI_BrainMonitor_3DScene
			for region_id in monitor_scene._brain_region_visualizations_by_ID:
				var brain_region_3d = monitor_scene._brain_region_visualizations_by_ID[region_id]
				brain_region_3d._disable_connection_monitoring()

## CRITICAL: Re-enables recursive refresh signals after FEAGI data updates are complete
func _enable_region_refresh_signals() -> void:
	print("🔊 SIGNAL CONTROL: Re-enabling recursive refresh signals after update")
	var scene_tree = Engine.get_main_loop() as SceneTree
	if not scene_tree or not scene_tree.root:
		return
	
	var brain_monitor_scenes = scene_tree.root.find_children("*", "UI_BrainMonitor_3DScene", true, false)
	
	for scene in brain_monitor_scenes:
		if scene is UI_BrainMonitor_3DScene:
			var monitor_scene = scene as UI_BrainMonitor_3DScene
			for region_id in monitor_scene._brain_region_visualizations_by_ID:
				var brain_region_3d = monitor_scene._brain_region_visualizations_by_ID[region_id]
				brain_region_3d._enable_connection_monitoring()

## CRITICAL: Temporarily disable local cache refresh signals to prevent conflicts during FEAGI updates
var _local_cache_signals_disabled: bool = false

func _disable_local_cache_refresh_signals() -> void:
	if _local_cache_signals_disabled:
		return  # Already disabled
		
	print("🔇 CACHE CONTROL: Disabling local cache refresh signals during FEAGI update")
	_local_cache_signals_disabled = true
	
	# Disconnect local cache mapping change signals that trigger competing refreshes
	if FeagiCore.feagi_local_cache.mapping_data.has_signal("mapping_updated"):
		var connections = FeagiCore.feagi_local_cache.mapping_data.mapping_updated.get_connections()
		for connection in connections:
			# Store connection info for re-enabling later
			if not _stored_mapping_connections:
				_stored_mapping_connections = []
			_stored_mapping_connections.append(connection)
			FeagiCore.feagi_local_cache.mapping_data.mapping_updated.disconnect(connection.callable)
			print("  🔇 Disconnected mapping_updated signal")

## CRITICAL: Re-enable local cache refresh signals after FEAGI updates complete
var _stored_mapping_connections: Array = []

func _enable_local_cache_refresh_signals() -> void:
	if not _local_cache_signals_disabled:
		return  # Already enabled
		
	print("🔊 CACHE CONTROL: Re-enabling local cache refresh signals after FEAGI update")
	_local_cache_signals_disabled = false
	
	# Reconnect local cache mapping change signals
	for connection in _stored_mapping_connections:
		FeagiCore.feagi_local_cache.mapping_data.mapping_updated.connect(connection.callable)
		print("  🔊 Reconnected mapping_updated signal")
	
	_stored_mapping_connections.clear()

	#if FeagiCore.feagi_local_cache.mapping_data.does_mappings_exist_between_areas(source_area, destination_area):
	#	FeagiCore.feagi_local_cache.mapping_data.established_mappings[source_area.cortical_ID][destination_area.cortical_ID].FEAGI_updated_mappings_JSON(temp_json_inbetween)
	#	return FEAGI_response_data
	# doesnt exist, create
	

## Immediately trigger visualization creation for new brain regions after successful cloning
func _trigger_immediate_region_visualization_update() -> void:
	print("🎯 IMMEDIATE UPDATE: Finding all 3D brain monitor scenes to update...")
	
	var scene_tree = Engine.get_main_loop() as SceneTree
	if not scene_tree or not scene_tree.root:
		print("❌ IMMEDIATE UPDATE: No scene tree available")
		return
	
	# Find all brain monitor 3D scenes
	var brain_monitor_scenes = scene_tree.root.find_children("*", "UI_BrainMonitor_3DScene", true, false)
	print("🎯 IMMEDIATE UPDATE: Found %d brain monitor scenes" % brain_monitor_scenes.size())
	
	for scene in brain_monitor_scenes:
		if scene is UI_BrainMonitor_3DScene:
			var monitor_scene = scene as UI_BrainMonitor_3DScene
			print("🎯 IMMEDIATE UPDATE: Updating brain monitor instance %d (represents: %s)" % [monitor_scene.get_instance_id(), monitor_scene._representing_region.friendly_name if monitor_scene._representing_region else "null"])
			monitor_scene._create_missing_brain_region_visualizations()
	
	print("✅ IMMEDIATE UPDATE: All brain monitor scenes updated")

## Manual test function - call this from Godot console to force region visualization update
func manual_force_region_update() -> void:
	print("🔧 MANUAL TEST: Forcing region visualization update...")
	_trigger_immediate_region_visualization_update()
	print("🔧 MANUAL TEST: Update completed")

## Stop all flashing previews across all amalgamation windows
func _stop_all_flashing_previews() -> void:
	print("🔄 FLASH: Searching for amalgamation windows to stop flashing previews...")
	
	var scene_tree = Engine.get_main_loop() as SceneTree
	if not scene_tree or not scene_tree.root:
		print("❌ FLASH: No scene tree available")
		return
	
	# Find all amalgamation request windows
	var amalgamation_windows = scene_tree.root.find_children("*", "WindowAmalgamationRequest", true, false)
	print("🔄 FLASH: Found %d amalgamation windows" % amalgamation_windows.size())
	
	for window in amalgamation_windows:
		if window.has_method("_stop_flashing_preview"):
			print("🔄 FLASH: Stopping flashing preview in window: %s" % window.name)
			window._stop_flashing_preview()
	
	print("✅ FLASH: All flashing previews stopped")

## Append a mapping betwseen 2 cortical areas. Assumes the current mapping information is up to date
func append_mapping_between_corticals(source_area: AbstractCorticalArea, destination_area: AbstractCorticalArea,  mapping: SingleMappingDefinition) -> FeagiRequestOutput:
	var current_mappings: Array[SingleMappingDefinition] = source_area.get_mapping_array_toward_cortical_area(destination_area)
	current_mappings.append(mapping)
	var return_data: FeagiRequestOutput = await set_mappings_between_corticals(source_area, destination_area, current_mappings)
	return return_data


## Append a default mapping betwseen 2 cortical areas, given the morphology to use. Assumes the current mapping information is up to date
func append_default_mapping_between_corticals(source_area: AbstractCorticalArea, destination_area: AbstractCorticalArea,  morphology: BaseMorphology) -> FeagiRequestOutput:
	var appending_mapping: SingleMappingDefinition = SingleMappingDefinition.create_default_mapping(morphology)
	var return_data: FeagiRequestOutput = await append_mapping_between_corticals(source_area, destination_area, appending_mapping)
	return return_data


## delete the mappings between 2 areas
func delete_mappings_between_corticals(source_area: AbstractCorticalArea, destination_area: AbstractCorticalArea) -> FeagiRequestOutput:
	var empty_mappings: Array[SingleMappingDefinition] = []
	var return_data: FeagiRequestOutput = await set_mappings_between_corticals(source_area, destination_area, empty_mappings)
	return return_data



#endregion

#region Amalgamation
#TODO move wiring mode to enum!
## Confirm the import of a pending amalgamation at a specific coordinate
func request_import_amalgamation(position: Vector3i, amalgamation_ID: StringName, parent_region_ID: StringName, wiring_mode: StringName) -> FeagiRequestOutput:
	print("🚨 CRITICAL DEBUG: request_import_amalgamation() ENTRY - amalgamation_ID: %s" % amalgamation_ID)
	print("🚨 CRITICAL DEBUG: Parameters - position: %s, parent_region_ID: %s, wiring_mode: %s" % [position, parent_region_ID, wiring_mode])
	
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	print("FEAGI REQUEST: Request confirming amalgamation of ID %s" % amalgamation_ID)
	# Map UI wiring_mode to server enum values
	var rewire_mode_param: String = "rewire_all"
	var wm: String = str(wiring_mode).to_lower()
	match wm:
		"all":
			rewire_mode_param = "rewire_all"
		"none":
			rewire_mode_param = "no_rewiring"
		"system":
			push_warning("FEAGI Requests: 'system' wiring maps to 'rewire_all' (server supports rewire_all|no_rewiring)")
			rewire_mode_param = "rewire_all"
		_:
			push_warning("FEAGI Requests: Unknown wiring_mode '%s', defaulting to 'rewire_all'" % wm)
			rewire_mode_param = "rewire_all"

	# Define Request #TODO why are the parameters in the URL
	var dict_to_send: Dictionary = 	{
		"brain_region_id": parent_region_ID
	}
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_POST_call(
		FeagiCore.network.http_API.address_list.POST_genome_amalgamationDestination + "?circuit_origin_x=" + str(position.x) + "&circuit_origin_y=" + str(position.y) + "&circuit_origin_z=" + str(position.z) + "&amalgamation_id=" + amalgamation_ID + "&rewire_mode=" + rewire_mode_param
		, dict_to_send)
	
	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		push_error("FEAGI Requests: Unable to confirm amalgamation %s!" % amalgamation_ID)
		return FEAGI_response_data
	print("FEAGI REQUEST: Successfully confirmed amalgamation %s, awaiting completion on FEAGIs side..." % amalgamation_ID)
	
	# CRITICAL: Check if amalgamation is already complete before waiting
	print("FEAGI REQUEST: 🎯 Checking if amalgamation %s is already complete..." % amalgamation_ID)
	print("🚨 CRITICAL DEBUG: About to call single_health_check_call()")
	
	# Get current health status to check if amalgamation is still pending
	var health_check_result = await FeagiCore.requests.single_health_check_call()
	if not FeagiCore.requests._return_if_HTTP_failed_and_automatically_handle(health_check_result):
		var health_data = health_check_result.decode_response_as_dict()
		var amalgamation_pending = health_data.get("amalgamation_pending", null)
		
		if amalgamation_pending == null:
			print("FEAGI REQUEST: 🎯 Amalgamation %s already completed - proceeding directly to genome reload" % amalgamation_ID)
		else:
			print("FEAGI REQUEST: 🎯 Amalgamation %s still pending - setting up completion detection" % amalgamation_ID)
			
			# Set pending amalgamation for completion detection
			FeagiCore.feagi_local_cache._pending_amalgamation = amalgamation_ID
			print("FEAGI REQUEST: 🎯 Cache _pending_amalgamation set to: '%s'" % FeagiCore.feagi_local_cache._pending_amalgamation)
			
			print("FEAGI REQUEST: Waiting for amalgamation_no_longer_pending signal...")
			
			# Simple timeout approach
			var signal_received = false
			var start_time = Time.get_ticks_msec()
			var timeout_ms = 3000  # 3 second timeout
			
			var signal_handler = func(completed_id): 
				signal_received = true
				print("FEAGI REQUEST: Amalgamation %s completion signal received!" % amalgamation_ID)
			
			FeagiCore.feagi_local_cache.amalgamation_no_longer_pending.connect(signal_handler, CONNECT_ONE_SHOT)
			
			# Poll for signal or timeout
			var scene_tree = Engine.get_main_loop() as SceneTree
			while not signal_received and (Time.get_ticks_msec() - start_time) < timeout_ms:
				if scene_tree:
					await scene_tree.process_frame
			
			# Cleanup
			if not signal_received:
				if FeagiCore.feagi_local_cache.amalgamation_no_longer_pending.is_connected(signal_handler):
					FeagiCore.feagi_local_cache.amalgamation_no_longer_pending.disconnect(signal_handler)
				print("FEAGI REQUEST: Timeout waiting for signal - assuming amalgamation %s completed" % amalgamation_ID)
	else:
		print("FEAGI REQUEST: ⚠️ Health check failed - assuming amalgamation %s completed" % amalgamation_ID)
	
	print("FEAGI REQUEST: Amalgamation %s addition confirmed by FEAGI! Adding new region visualization directly..." % amalgamation_ID)
	
	# SIMPLE: Use the brain region registry from the 200 response to update cache and add visualization
	print("FEAGI REQUEST: 🎯 Using brain region registry from response to update cache and add visualization...")
	
	# Decode the response to get the brain region registry
	var response_dict = FEAGI_response_data.decode_response_as_dict()
	print("FEAGI REQUEST: 🔍 Full response keys: %s" % str(response_dict.keys()))
	print("FEAGI REQUEST: 🔍 Response has brain_regions: %s" % response_dict.has("brain_regions"))
	if response_dict.has("message"):
		print("FEAGI REQUEST: 🔍 Response message: %s" % response_dict["message"])
	
	if response_dict.has("brain_regions"):
		print("FEAGI REQUEST: 🔍 Found brain_regions in response, updating cache...")
		
		# Update the brain regions cache with the fresh data from FEAGI
		var brain_regions_list = response_dict["brain_regions"]
		
		# Convert list format to dictionary format expected by cache
		var brain_regions_dict = {}
		for region_data in brain_regions_list:
			if region_data.has("region_id"):
				var region_id = region_data["region_id"]
				brain_regions_dict[region_id] = region_data
				
				# DEBUG: Show parent-child relationships for new regions
				if "clone" in str(region_data.get("title", "")).to_lower():
					print("FEAGI REQUEST: 🔍 NEW CLONED REGION: %s (%s)" % [region_id, region_data.get("title", "No Title")])
					print("  - Parent: %s" % region_data.get("parent_region_id", "None"))
					print("  - Regions (children): %s" % str(region_data.get("regions", [])))
		
		print("FEAGI REQUEST: 🔄 Converted %d regions from list to dictionary format" % brain_regions_dict.size())
		
		# DEBUG: Also check what the root region's children are after update
		if "root" in brain_regions_dict:
			var root_region = brain_regions_dict["root"]
			print("FEAGI REQUEST: 🔍 ROOT REGION after update:")
			print("  - Title: %s" % root_region.get("title", "No Title"))
			print("  - Children (regions): %s" % str(root_region.get("regions", [])))
		var cortical_area_IDs_mapped_to_parent_regions_IDs = FeagiCore.feagi_local_cache.brain_regions.FEAGI_load_all_regions_and_establish_relations_and_calculate_area_region_mapping(brain_regions_dict)
		print("FEAGI REQUEST: ✅ Brain regions cache updated with fresh data")
		
		# CRITICAL: Update the cache with the new cortical areas using the same method as normal genome loading
		print("FEAGI REQUEST: 🔄 Fetching fresh cortical area data to update cache...")
		
		# Fetch ALL cortical area data (same as normal genome loading)
		var cortical_area_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(FeagiCore.network.http_API.address_list.GET_corticalArea_corticalArea_geometry)
		var cortical_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(cortical_area_request)
		await cortical_worker.worker_done
		var cortical_areas_response: FeagiRequestOutput = cortical_worker.retrieve_output_and_close()
		
		if cortical_areas_response.success:
			print("FEAGI REQUEST: ✅ Cortical area data fetched successfully")
			
			# Update the cortical areas cache using the same method as normal genome loading
			print("FEAGI REQUEST: 🔄 Updating cortical areas cache...")
			FeagiCore.feagi_local_cache.cortical_areas.FEAGI_load_all_cortical_areas(
				cortical_areas_response.decode_response_as_dict(), 
				cortical_area_IDs_mapped_to_parent_regions_IDs
			)
			print("FEAGI REQUEST: ✅ Cortical areas cache updated successfully")
			
			# CRITICAL: Process inputs/outputs arrays from the response to create partial_mappings
			print("FEAGI REQUEST: 🔄 Processing inputs/outputs arrays to create partial mappings...")
			for region_data in brain_regions_list:
				if region_data.has("region_id") and (region_data.has("inputs") or region_data.has("outputs")):
					var region_id = region_data["region_id"]
					var inputs = region_data.get("inputs", [])
					var outputs = region_data.get("outputs", [])
					
					print("FEAGI REQUEST: 🔍 Processing I/O for region %s: %d inputs, %d outputs" % [region_id, inputs.size(), outputs.size()])
					
					# Create the seed data for partial mappings
					var seed: Dictionary = {}
					seed[region_id] = {
						"inputs": inputs,
						"outputs": outputs
					}
					
					# Load the partial mappings (this creates the partial_mappings that the visualization uses)
					FeagiCore.feagi_local_cache.brain_regions.FEAGI_load_all_partial_mapping_sets(seed)
					print("FEAGI REQUEST: ✅ Loaded I/O mappings for region %s - inputs: %d, outputs: %d" % [region_id, inputs.size(), outputs.size()])
			
			print("FEAGI REQUEST: ✅ All partial mappings processed successfully")
		else:
			print("FEAGI REQUEST: ❌ Failed to fetch cortical area data: %s" % cortical_areas_response.decode_response_as_generic_error_code())
		
		# Now trigger visualization creation with the updated cache
		if BV.UI and BV.UI.temp_root_bm:
			var brain_monitor = BV.UI.temp_root_bm
			print("FEAGI REQUEST: 🔍 Found brain monitor: %s" % brain_monitor.name)
			print("FEAGI REQUEST: 🔍 Brain monitor represents region: %s" % (brain_monitor._representing_region.friendly_name if brain_monitor._representing_region else "null"))
			
			# CRITICAL FIX: Update the brain monitor's _representing_region reference 
			# because the cache update creates new BrainRegion objects
			var old_region_id = brain_monitor._representing_region.region_ID if brain_monitor._representing_region else "unknown"
			var fresh_representing_region = FeagiCore.feagi_local_cache.brain_regions.available_brain_regions.get(old_region_id)
			if fresh_representing_region:
				brain_monitor._representing_region = fresh_representing_region
				print("FEAGI REQUEST: 🔄 Updated brain monitor's _representing_region reference to fresh cache object")
				print("FEAGI REQUEST: 🔍 Fresh representing region has %d child regions" % fresh_representing_region.contained_regions.size())
				for child_region in fresh_representing_region.contained_regions:
					print("FEAGI REQUEST: 🔍   - Child: %s (%s)" % [child_region.region_ID, child_region.friendly_name])
			else:
				print("FEAGI REQUEST: ❌ Could not find fresh representing region for ID: %s" % old_region_id)
			
			print("FEAGI REQUEST: 🔍 Current visualizations before update: %s" % str(brain_monitor._brain_region_visualizations_by_ID.keys()))
			
			# Force the brain monitor to check for and create any missing region visualizations
			print("FEAGI REQUEST: 🎯 Calling _create_missing_brain_region_visualizations()...")
			brain_monitor._create_missing_brain_region_visualizations()
			
			print("FEAGI REQUEST: 🔍 Current visualizations after update: %s" % str(brain_monitor._brain_region_visualizations_by_ID.keys()))
			
			# CRITICAL: Also create cortical area visualizations for the newly cloned region
			print("FEAGI REQUEST: 🎯 Creating cortical area visualizations for newly cloned region...")
			
			# Find the newly created region (it should be the one that was just added)
			var new_region_ids = []
			for region_id in brain_regions_dict.keys():
				if region_id != "root":  # Skip root region
					new_region_ids.append(region_id)
			
			print("FEAGI REQUEST: 🔍 Processing %d regions for cortical area visualization..." % new_region_ids.size())
			
			for region_id in new_region_ids:
				var region = FeagiCore.feagi_local_cache.brain_regions.available_brain_regions.get(region_id)
				if region and region.contained_cortical_areas.size() > 0:
					print("FEAGI REQUEST: 🔍 Region %s has %d cortical areas, creating visualizations..." % [region_id, region.contained_cortical_areas.size()])
					var areas_created = 0
					for area in region.contained_cortical_areas:
						# Check if visualization already exists
						if not brain_monitor.has_cortical_area_visualization(area.cortical_ID):
							print("FEAGI REQUEST: 🆕 Creating visualization for cortical area %s in region %s" % [area.cortical_ID, region_id])
							var created_viz = brain_monitor._add_cortical_area(area)
							if created_viz:
								areas_created += 1
								print("FEAGI REQUEST: ✅ Successfully created visualization for %s" % area.cortical_ID)
							else:
								print("FEAGI REQUEST: ❌ Failed to create visualization for %s" % area.cortical_ID)
						else:
							print("FEAGI REQUEST: ⏭️ Visualization already exists for cortical area %s" % area.cortical_ID)
					print("FEAGI REQUEST: 📊 Created %d/%d cortical area visualizations for region %s" % [areas_created, region.contained_cortical_areas.size(), region_id])
				else:
					print("FEAGI REQUEST: ⚠️ Region %s has no cortical areas to visualize" % region_id)
			
			print("FEAGI REQUEST: ✅ Region and cortical area visualization creation completed")
		else:
			print("FEAGI REQUEST: ❌ No brain monitor available for visualization")
			print("FEAGI REQUEST: 🔍 BV.UI exists: %s" % (BV.UI != null))
			print("FEAGI REQUEST: 🔍 BV.UI.temp_root_bm exists: %s" % (BV.UI.temp_root_bm != null if BV.UI else "BV.UI is null"))
	else:
		print("FEAGI REQUEST: ❌ No brain_regions found in response - cannot update cache")
	
	# CRITICAL: Stop any flashing previews - cloning completed successfully
	print("FEAGI REQUEST: 🔄 Stopping flashing previews - cloning completed successfully")
	print("FEAGI REQUEST: 🔍 About to call _stop_all_flashing_previews()...")
	_stop_all_flashing_previews()
	print("FEAGI REQUEST: ✅ _stop_all_flashing_previews() completed")
	
	return FEAGI_response_data
	

## Cancel the import of a specific amalgamation
func cancel_pending_amalgamation(amalgamation_ID: StringName) -> FeagiRequestOutput:
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	print("FEAGI REQUEST: Request deletion of amalgamation request of ID %s" % amalgamation_ID)
	
	# Define Request #TODO why are the parameters in the URL
	var dict_to_send: Dictionary = 	{}
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_DELETE_call(
		FeagiCore.network.http_API.address_list.DELETE_GE_amalgamationCancellation + "?amalgamation_id=" + amalgamation_ID
		, dict_to_send)
	
	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		push_error("FEAGI Requests: Unable to delete amalgamation request %s!" % amalgamation_ID)
		return FEAGI_response_data
	print("FEAGI REQUEST: Successfully deleted amalgamation request %s" % amalgamation_ID)
	return FEAGI_response_data



#endregion


## Check if network components are properly initialized
func _check_network_components_ready() -> FeagiRequestOutput:
	if !FeagiCore.network:
		push_error("FEAGI Requests: Network component is null!")
		return FeagiRequestOutput.requirement_fail("NETWORK_NULL")
	
	if !FeagiCore.network.http_API:
		push_error("FEAGI Requests: HTTP API component is null!")
		return FeagiRequestOutput.requirement_fail("HTTP_API_NULL")
	
	if !FeagiCore.network.http_API.address_list:
		push_error("FEAGI Requests: Address list is null!")
		return FeagiRequestOutput.requirement_fail("ADDRESS_LIST_NULL")
	
	return null  # null means all checks passed

## Safe wrapper for making HTTP calls with network component validation
func _make_safe_http_call(request_definition: APIRequestWorkerDefinition) -> APIRequestWorker:
	# Check network components right before making the call
	var network_check = _check_network_components_ready()
	if network_check != null:
		# Return a fake worker that immediately fails
		var fake_worker = APIRequestWorker.new()
		# We can't easily create a failed worker, so we'll let the caller handle the null check
		return null
	
	return FeagiCore.network.http_API.make_HTTP_call(request_definition)

## Used for error automated error handling of HTTP requests, outputs booleans to set up easy early returns
func _return_if_HTTP_failed_and_automatically_handle(output: FeagiRequestOutput, optional_input_for_debugging: APIRequestWorkerDefinition = null) -> bool:
	if output.has_timed_out:
		print("FEAGI REQUEST: ⏰ Request timed out")
		return true
	if output.has_errored:
		var error_details = output.decode_response_as_generic_error_code()
		print("FEAGI REQUEST: ❌ HTTP error - Code: %s, Message: %s" % [error_details[0], error_details[1]])
		if OS.is_debug_build() and optional_input_for_debugging != null:
			push_error("FEAGI Requests: Error at endpoint %s - %s: %s" % [optional_input_for_debugging.full_address, error_details[0], error_details[1]])
			
		
		return true
	return false
