extends RefCounted
class_name FEAGIRequests

#region Genome and FEAGI general

## Reloads the genome, returns if sucessful
func reload_genome() -> FeagiRequestOutput:
	var cortical_area_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(FeagiCore.network.http_API.address_list.GET_corticalArea_corticalArea_geometry)
	var morphologies_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(FeagiCore.network.http_API.address_list.GET_morphology_morphologies)
	var mappings_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(FeagiCore.network.http_API.address_list.GET_corticalArea_corticalMapDetailed)
	var region_request:APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(FeagiCore.network.http_API.address_list.GET_region_regionsMembers)
	var templates_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(FeagiCore.network.http_API.address_list.GET_corticalArea_corticalTypes)
	
	# Get Cortical Area Data
	var cortical_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(cortical_area_request)
	await cortical_worker.worker_done
	var cortical_data: FeagiRequestOutput = cortical_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(cortical_data):
		push_error("FEAGI Requests: Unable to grab FEAGI cortical summary data!")
		return cortical_data

	# Get Morphologies
	var morphologies_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(morphologies_request)
	await morphologies_worker.worker_done
	var morphologies_data: FeagiRequestOutput = morphologies_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(morphologies_data):
		push_error("FEAGI Requests: Unable to grab FEAGI morphology summary data!")
		return morphologies_data

	# Get Mapping Data
	var mapping_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(mappings_request)
	await mapping_worker.worker_done
	var mapping_data: FeagiRequestOutput = mapping_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(mapping_data):
		push_error("FEAGI Requests: Unable to grab FEAGI mapping summary data!")
		return mapping_data
	
	# Get Region Data
	var region_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(region_request)
	await region_worker.worker_done
	var region_data: FeagiRequestOutput = region_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(region_data):
		push_error("FEAGI Requests: Unable to grab FEAGI region data!")
		return region_data
	
	FeagiCore.feagi_local_cache.replace_whole_genome(
		cortical_data.decode_response_as_dict(),
		morphologies_data.decode_response_as_dict(),
		mapping_data.decode_response_as_dict(),
		region_data.decode_response_as_dict()
	)
	
	# Get Template Data
	var template_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(templates_request)
	await template_worker.worker_done
	var template_data: FeagiRequestOutput = template_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(template_data):
		push_error("FEAGI Requests: Unable to grab FEAGI template summary data!")
		return template_data
	var raw_templates: Dictionary = template_data.decode_response_as_dict()
	FeagiCore.feagi_local_cache.update_templates_from_FEAGI(raw_templates)
	
	# Other stuff (asyncronous)
	get_burst_delay()
	
	return FeagiRequestOutput.generic_success() # use generic success since we made multiple calls
	

## Retrieves FEAGIs Burst Rate
func get_burst_delay() -> FeagiRequestOutput:
	# Requirement checking
	if !FeagiCore.connection_state == FeagiCore.CONNECTION_STATE.CONNECTED:
		push_error("FEAGI Requests: Not connected to FEAGI!")
		return FeagiRequestOutput.requirement_fail("NOT_CONNECTED")
	print("FEAGI REQUEST: Request getting delay between bursts")
	
	# Define Request
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(FeagiCore.network.http_API.address_list.GET_burstEngine_stimulationPeriod)
	
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
	# Requirement checking
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	if new_delay_between_bursts <= 0.0:
		push_error("FEAGI Requests: Cannot set delay between bursts to 0 or less!")
		return FeagiRequestOutput.requirement_fail("IMPOSSIBLE_BURST_DELAY")
	print("FEAGI REQUEST: Request setting delay between bursts to %d" % new_delay_between_bursts)
	
	# Define Request
	var dict_to_send: Dictionary = 	{ "burst_duration": new_delay_between_bursts}
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
	

#endregion


## Mass move a bunch of cortical areas at once
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
	
	# Define Request
	var dict_to_send: Dictionary = {}
	for move in genome_objects_mapped_to_new_locations_as_vector2is.keys():
		dict_to_send[(move as GenomeObject).genome_ID] = {"coordinate_2d": FEAGIUtils.vector2i_to_array(genome_objects_mapped_to_new_locations_as_vector2is[move])}
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_PUT_call(FeagiCore.network.http_API.address_list.PUT_genome_relocate_members, dict_to_send)
	
	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		push_error("FEAGI Requests: Unable to 2D move %d genome objects!" % len(genome_objects_mapped_to_new_locations_as_vector2is))
		return FEAGI_response_data
	var response: Dictionary = FEAGI_response_data.decode_response_as_dict()
	print("FEAGI REQUEST: Successfully 2D moved %d genome objects!" % len(genome_objects_mapped_to_new_locations_as_vector2is))
	FeagiCore.feagi_local_cache.FEAGI_mass_update_2D_positions(genome_objects_mapped_to_new_locations_as_vector2is)
	return FEAGI_response_data


#region Brain Regions
## Used by the user to create regions
func create_region(parent_region: BrainRegion, region_internals: Array[GenomeObject], region_name: StringName, coords_2D: Vector2i, coords_3D: Vector3) -> FeagiRequestOutput:
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
		"coordinates_3d": FEAGIUtils.vector3_to_array(coords_3D),
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
	FeagiCore.feagi_local_cache.brain_regions.FEAGI_add_region(response["region_id"], parent_region, region_name, coords_2D, coords_3D, region_internals)
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
	
	# Define Request
	var dict_to_send: Dictionary = {
		"region_id": brain_region.region_ID,
		"region_title": region_name,
		"region_description": region_description,
		"parent_region_id": parent_region.region_ID,
		"coordinates_2d": FEAGIUtils.vector2i_to_array(coords_2D),
		"coordinates_3d": FEAGIUtils.vector3i_to_array(coords_3D),
	}
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_PUT_call(FeagiCore.network.http_API.address_list.PUT_region_region, dict_to_send)
	
	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		push_error("FEAGI Requests: Unable to create region of name %s!" % brain_region.name)
		return FEAGI_response_data
	FeagiCore.local_feagi_cache.brain_regions.FEAGI_edited_region(brain_region, region_name, region_description, parent_region, coords_2D, coords_3D)
	return FEAGI_response_data

func move_objects_to_region(target_region: BrainRegion, objects_to_move: Array[GenomeObject]) -> FeagiRequestOutput:
	# Requirement checking
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	if !target_region.region_ID in FeagiCore.feagi_local_cache.brain_regions.available_brain_regions:
		push_error("FEAGI Requests: No such region ID %s to edit!" % target_region.region_ID)
		return FeagiRequestOutput.requirement_fail("INVALID_REGION_ID")
	for object in objects_to_move:
		if object is BrainRegion:
			if (object as BrainRegion).is_root_region():
				push_error("FEAGI Requests: Unable to make Root Region a child of %s!" % target_region.name)
				return FeagiRequestOutput.requirement_fail("CANNOT_MOVE_ROOT")
			if (object as BrainRegion).region_ID == target_region.region_ID:
				push_error("FEAGI Requests: Cannot make region %s child of itself!" % target_region.name)
				return FeagiRequestOutput.requirement_fail("CANNOT_RECURSE_REGION")
	
	# Define Request
	var dict_to_send: Dictionary = {}
	for object in objects_to_move:
		dict_to_send[object.genome_ID] = target_region.region_ID
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_PUT_call(FeagiCore.network.http_API.address_list.PUT_region_relocateMembers, dict_to_send)
	
	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		push_error("FEAGI Requests: Unable to move objects to region of name %s!" % target_region.name)
		return FEAGI_response_data
	for object in objects_to_move:
		object.FEAGI_change_parent_brain_region(target_region)
	return FEAGI_response_data


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
	# Requirement checking
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	if !checking_cortical_ID in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.keys():
		push_error("FEAGI Requests: Unable to delete cortical area %s that is not found in cache!" % checking_cortical_ID)
		return FeagiRequestOutput.requirement_fail("ID_NOT_FOUND")
	
	# Define Request
	var dict_to_send: Dictionary = {"cortical_id": checking_cortical_ID}
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_POST_call(FeagiCore.network.http_API.address_list.POST_corticalArea_corticalAreaProperties, dict_to_send)
	
	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		push_error("FEAGI Requests: Unable to grab cortical area details of %s!" % checking_cortical_ID)
		return FEAGI_response_data
	var response: Dictionary = FEAGI_response_data.decode_response_as_dict()
	print("FEAGI REQUEST: Successfully retrieved details of cortical area %s" % checking_cortical_ID)
	FeagiCore.feagi_local_cache.cortical_areas.FEAGI_update_cortical_area_from_dict(response)
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
		"cortical_group": AbstractCorticalArea.cortical_type_to_str(AbstractCorticalArea.CORTICAL_AREA_TYPE.CUSTOM),
		"brain_region_id": parent_region.region_ID,
		"cortical_sub_group": "",
		"coordinates_2d": [null, null]
	}
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
		"cortical_group": AbstractCorticalArea.cortical_type_to_str(AbstractCorticalArea.CORTICAL_AREA_TYPE.CUSTOM),
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
	return FEAGI_response_data


## Adds a IPU / OPU cortical area. NOTE: IPUs/OPUs can ONLY be in the root region!
func add_IOPU_cortical_area(IOPU_template: CorticalTemplate, channel_count: int, coordinates_3D: Vector3i, is_coordinate_2D_defined: bool, coordinates_2D: Vector2i = Vector2(0,0)) -> FeagiRequestOutput:
	# Requirement checking
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	if IOPU_template.ID in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.keys():
		push_error("FEAGI Requests: I/OPU area of ID %s already exists!!" % IOPU_template.ID)
		return FeagiRequestOutput.requirement_fail("ID_EXISTS")
	if channel_count < 1:
		push_error("FEAGI Requests: Channel count is too low!")
		return FeagiRequestOutput.requirement_fail("CHANNEL_TOO_LOW")
	if !(IOPU_template.cortical_type  in [AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU, AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU]):
		push_error("FEAGI Requests: Unable to create non-IPU/OPU area using the request IPU/OPU call!, Skipping!")
		return FeagiRequestOutput.requirement_fail("NON_IOPU")
	
	print("FEAGI REQUEST: Request creating IOPU cortical area by name %s" % IOPU_template.cortical_name)
	# Define Request
	var dict_to_send: Dictionary = {
		"cortical_id": IOPU_template.ID,
		"coordinates_3d": FEAGIUtils.vector3i_to_array(coordinates_3D),
		"cortical_type": AbstractCorticalArea.cortical_type_to_str(IOPU_template.cortical_type),
		"channel_count": channel_count,
		"coordinates_2d": [null, null]
	}
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
	if IOPU_template.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU:
		FeagiCore.feagi_local_cache.cortical_areas.FEAGI_add_input_cortical_area(IOPU_template.ID, IOPU_template, channel_count, coordinates_3D, is_coordinate_2D_defined, coordinates_2D)
	else: #OPU
		FeagiCore.feagi_local_cache.cortical_areas.FEAGI_add_output_cortical_area(IOPU_template.ID, IOPU_template, channel_count, coordinates_3D, is_coordinate_2D_defined, coordinates_2D)
	
	print("FEAGI REQUEST: Successfully created custom cortical area by name %s with ID %s" % [IOPU_template.cortical_name, response["cortical_id"]])
	return FEAGI_response_data


## Clone a given cortical area
func clone_cortical_area(cloning_area: AbstractCorticalArea, new_name: StringName, new_position_2D: Vector2i, new_position_3D: Vector3i, parent_region: BrainRegion) -> FeagiRequestOutput:
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
	
	var FEAGI_response_data: FeagiRequestOutput
	
	match(cloning_area.cortical_type):
		AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY:
			print("FEAGI REQUEST: Request copying memory cortical area %s as new area with name %s" % [cloning_area.cortical_ID, new_name])
			FEAGI_response_data = await add_custom_memory_cortical_area(new_name, new_position_3D, cloning_area.dimensions_3D, parent_region, true, new_position_2D)
		AbstractCorticalArea.CORTICAL_AREA_TYPE.CUSTOM:
			print("FEAGI REQUEST: Request copying custom cortical area %s as new area with name %s" % [cloning_area.cortical_ID, new_name])
			FEAGI_response_data = await add_custom_cortical_area(new_name, new_position_3D, cloning_area.dimensions_3D, parent_region, true, new_position_2D)
		_:
			push_error("FEAGI Requests: No procedure for cloning a cortical area of type %s" % cloning_area.type_as_string)
			return FeagiRequestOutput.requirement_fail("TYPE_NOT_ALLOWED")
	
	if !FEAGI_response_data.success:
		print("FEAGI REQUEST: Unable to clone cortical area %s" % [cloning_area.cortical_ID])
		return FEAGI_response_data
	
	var response: Dictionary = FEAGI_response_data.decode_response_as_dict()
	print("FEAGI REQUEST: Successfully cloned cortical area %s to new area %s" % [cloning_area.cortical_ID, response["cortical_id"]])
	return FEAGI_response_data


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
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_PUT_call(FeagiCore.network.http_API.address_list.PUT_genome_corticalArea, properties)
	
	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		push_error("FEAGI Requests: Unable to update cortical area of ID %s!" % editing_ID)
		return FEAGI_response_data
	FeagiCore.feagi_local_cache.cortical_areas.FEAGI_update_cortical_area_from_dict(properties)
	print("FEAGI REQUEST: Successfully updated cortical area %s" % [ editing_ID])
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


## Refresh templates for IPU/OPU generation. Note that this is technically already done on genome load
func get_cortical_templates() -> FeagiRequestOutput:
	# Requirement checking
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	
	# Define Request
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(FeagiCore.network.http_API.address_list.GET_corticalArea_corticalTypes)
	
	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		push_error("FEAGI Requests: Unable to get cortical templates!")
		return FEAGI_response_data
	var response: Dictionary = FEAGI_response_data.decode_response_as_dict()
	print("FEAGI REQUEST: Successfully retrieved cortical template data!")
	FeagiCore.feagi_local_cache.update_templates_from_FEAGI(response)
	return FEAGI_response_data


## Toggle is the synaptic activity of a cortical area should be monitored
func toggle_synaptic_monitoring(cortical_area_ID: StringName, should_monitor: bool) -> FeagiRequestOutput:
	# Requirement checking
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	if !cortical_area_ID in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.keys():
		push_error("FEAGI Requests: Unable to find cortical area %s that is not found in cache!!" % cortical_area_ID)
		return FeagiRequestOutput.requirement_fail("SOURCE_NOT_FOUND")
	if !FeagiCore.feagi_local_cache.influxdb_availability:
		push_error("FEAGI Requests: InfluxDB is not available for toggling synaptic monitoring!")
		return FeagiRequestOutput.requirement_fail("NO_INFLUXDB")
	
	# Define Request
	var dict_to_send: Dictionary = {
		"ID": cortical_area_ID,
		"state": should_monitor}
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_POST_call(FeagiCore.network.http_API.address_list.POST_MON_neuron_membranePotential, dict_to_send)
	
	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		push_error("FEAGI Requests: Unable to set synaptic monitoring on cortical area %s!" % cortical_area_ID)
		return FEAGI_response_data
	var response: Dictionary = FEAGI_response_data.decode_response_as_dict()
	print("FEAGI REQUEST: Successfully set synaptic monitoring on cortical area %s!" % cortical_area_ID)
	var cortical_area: AbstractCorticalArea = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas[cortical_area_ID]
	cortical_area.is_monitoring_synaptic_potential = should_monitor
	return FEAGI_response_data


## Toggle is the membrane activity of a cortical area should be monitored
func toggle_membrane_monitoring(cortical_area_ID: StringName, should_monitor: bool) -> FeagiRequestOutput:
	# Requirement checking
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	if !cortical_area_ID in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.keys():
		push_error("FEAGI Requests: Unable to find cortical area %s that is not found in cache!!" % cortical_area_ID)
		return FeagiRequestOutput.requirement_fail("SOURCE_NOT_FOUND")
	if !FeagiCore.feagi_local_cache.influxdb_availability:
		push_error("FEAGI Requests: InfluxDB is not available for toggling membrane monitoring!")
		return FeagiRequestOutput.requirement_fail("NO_INFLUXDB")
	
	# Define Request
	var dict_to_send: Dictionary = {
		"ID": cortical_area_ID,
		"state": should_monitor}
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_POST_call(FeagiCore.network.http_API.address_list.POST_monitoring_neuron_membranePotential_set, dict_to_send)
	
	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		push_error("FEAGI Requests: Unable to set membrane monitoring on cortical area %s!" % cortical_area_ID)
		return FEAGI_response_data
	var response: Dictionary = FEAGI_response_data.decode_response_as_dict()
	print("FEAGI REQUEST: Successfully set membrane monitoring on cortical area %s!" % cortical_area_ID)
	var cortical_area: AbstractCorticalArea = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas[cortical_area_ID]
	cortical_area.is_monitoring_membrane_potential = should_monitor
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
	
	FeagiCore.feagi_local_cache.mapping_data.FEAGI_set_mapping(source_area, destination_area, mappings)
	#var mapping_set: InterCorticalMappingSet = FeagiCore.feagi_local_cache.mapping_data.established_mappings[source_area.cortical_ID][destination_area.cortical_ID]
	#mapping_set.mappings_changed.emit(mapping_set)
	#mapping_set._connection_chain.FEAGI_updated_associated_mapping_set()
	#FeagiCore.feagi_local_cache.mapping_data.mapping_updated.emit(mapping_set)
	return FEAGI_response_data
	#if FeagiCore.feagi_local_cache.mapping_data.does_mappings_exist_between_areas(source_area, destination_area):
	#	FeagiCore.feagi_local_cache.mapping_data.established_mappings[source_area.cortical_ID][destination_area.cortical_ID].FEAGI_updated_mappings_JSON(temp_json_inbetween)
	#	return FEAGI_response_data
	# doesnt exist, create
	

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
## Confirm the import of a pending amalgamation at a specific coordinate
func request_import_amalgamation(position: Vector3i, amalgamation_ID: StringName, parent_region_ID: StringName) -> FeagiRequestOutput:
	if !FeagiCore.can_interact_with_feagi():
		push_error("FEAGI Requests: Not ready for requests!")
		return FeagiRequestOutput.requirement_fail("NOT_READY")
	print("FEAGI REQUEST: Request confirming amalgamation of ID %s" % amalgamation_ID)
	
	# Define Request #TODO why are the parameters in the URL
	var dict_to_send: Dictionary = 	{
		"brain_region_id": parent_region_ID
	}
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_POST_call(
		FeagiCore.network.http_API.address_list.POST_genome_amalgamationDestination + "?circuit_origin_x=" + str(position.x) + "&circuit_origin_y=" + str(position.y) + "&circuit_origin_z=" + str(position.z) + "&amalgamation_id=" + amalgamation_ID
		, dict_to_send)
	
	# Send request and await results
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	await HTTP_FEAGI_request_worker.worker_done
	var FEAGI_response_data: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	if _return_if_HTTP_failed_and_automatically_handle(FEAGI_response_data):
		push_error("FEAGI Requests: Unable to confirm amalgamation %s!" % amalgamation_ID)
		return FEAGI_response_data
	print("FEAGI REQUEST: Successfully confirmed amalgamation %s, awaiting completion on FEAGIs side..." % amalgamation_ID)
	await FeagiCore.feagi_local_cache.amalgamation_no_longer_pending
	print("FEAGI REQUEST: Amalgamation %s addition confirmed by FEAGI! Reloading genome..." % amalgamation_ID)
	reload_genome()
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


## Used for error automated error handling of HTTP requests, outputs booleans to set up easy early returns
func _return_if_HTTP_failed_and_automatically_handle(output: FeagiRequestOutput, optional_input_for_debugging: APIRequestWorkerDefinition = null) -> bool:
	if output.has_timed_out:
		print("TODO generic timeout handling")
		return true
	if output.has_errored:
		print("TODO generic error handling")
		if OS.is_debug_build() and optional_input_for_debugging != null:
			push_error("FEAGI Requests: Error at endpoint %s" % optional_input_for_debugging.full_address)
			
		
		return true
	return false
