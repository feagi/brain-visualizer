extends Object
class_name ResponseProxyFunctions
## All responses from FEAGI calls go through these calls

func GET_GE_fileName(_response_code: int, response_body: PackedByteArray, _irrelevant_data: Variant) -> void:
	FeagiCache.genome_name = response_body.get_string_from_utf8()


## returns dict of morphology names keyd to their type string
func GET_MO_list_types(_response_code: int, response_body: PackedByteArray, _irrelevant_data: Variant) -> void:
	var morphologies_and_types: Dictionary = _body_to_dictionary(response_body)
	FeagiCache.morphology_cache.update_morphology_cache_from_summary(morphologies_and_types)
	FeagiEvents.retrieved_latest_morphology_listing.emit(morphologies_and_types.keys())

## returns a dict of the mapping of cortical areas
func GET_GE_corticalMap(_response_code: int, response_body: PackedByteArray, _irrelevant_data: Variant) -> void:
	var cortical_map: Dictionary = _body_to_dictionary(response_body)
	for source_cortical_ID in cortical_map.keys():
		if cortical_map[source_cortical_ID] == {}:
			continue # no efferent connections for the current searching source cortical ID
		if source_cortical_ID not in FeagiCache.cortical_areas_cache.cortical_areas.keys():
			push_error("Retrieved mapping from nonexistant cortical area %s! Skipping!" % source_cortical_ID)
			continue
		
		# This function is not particuarly efficient. Too Bad!
		# no typing of these arrays due to type cast shenanigans. Be careful!
		var source_area: CorticalArea = FeagiCache.cortical_areas_cache.cortical_areas[source_cortical_ID]
		var connections_requested: Array = cortical_map[source_cortical_ID].keys()
		var efferent_connections_already_set: Array = source_area.efferent_connections_with_count.keys()
		var efferents_to_add: Array = FEAGIUtils.find_missing_elements(connections_requested, efferent_connections_already_set)
		var efferents_to_remove: Array = FEAGIUtils.find_missing_elements(efferent_connections_already_set, connections_requested)
		var efferents_to_update: Array = FEAGIUtils.find_union(efferent_connections_already_set, connections_requested)
		

		for add_ID in efferents_to_add:
			source_area.set_efferent_connection(FeagiCache.cortical_areas_cache.cortical_areas[add_ID], cortical_map[source_cortical_ID][add_ID])
		
		for remove_ID in efferents_to_remove:
			source_area.remove_efferent_connection(FeagiCache.cortical_areas_cache.cortical_areas[remove_ID])

		for check_ID in efferents_to_update:
			source_area.set_efferent_connection(FeagiCache.cortical_areas_cache.cortical_areas[check_ID], cortical_map[source_cortical_ID][check_ID])
	
	if VisConfig.visualizer_state == VisConfig.STATES.LOADING_INITIAL:
		# we were loading the game, but now we can assume we are loaded
		VisConfig.visualizer_state = VisConfig.STATES.READY


## returns a dict of all the properties of a specific cortical area, then triggers a cache update for it
func GET_GE_corticalArea(_response_code: int, response_body: PackedByteArray, _irrelevant_data: Variant) -> void:
	if _response_code == 422:
		push_error("Unable to retrieve cortical area information! Skipping!")
		return
	var cortical_area_properties: Dictionary = _body_to_dictionary(response_body)
	print("Recieved from FEAGI latest cortical info for " + cortical_area_properties["cortical_id"])
	FeagiCache.cortical_areas_cache.update_cortical_area_from_dict(cortical_area_properties)


func GET_GE_CorticalArea_geometry(_response_code: int, response_body: PackedByteArray, _irrelevant_data: Variant) -> void:
	var cortical_area_summary: Dictionary = _body_to_dictionary(response_body)
	FeagiCache.cortical_areas_cache.update_cortical_area_cache_from_summary(cortical_area_summary)
	FeagiRequests.refresh_connection_list()


func GET_GE_circuits(_response_code: int, response_body: PackedByteArray, _irrelevant_data: Variant) -> void:
	FeagiCache.available_circuits = _body_to_string_array(response_body)

func GET_GE_circuitsize(_response_code: int, response_body: PackedByteArray, circuit_name: StringName) -> void:
	var size_array: Array[int] = FEAGIUtils.untyped_array_to_int_array(_body_to_untyped_array(response_body))
	FeagiEvents.retrieved_circuit_size.emit(circuit_name, FEAGIUtils.array_to_vector3i(size_array))
	
func GET_GE_mappingProperties(_response_code: int, response_body: PackedByteArray, source_destination_ID_str: Array) -> void:
	if source_destination_ID_str[0] not in FeagiCache.cortical_areas_cache.cortical_areas.keys() or source_destination_ID_str[1] not in FeagiCache.cortical_areas_cache.cortical_areas.keys():
		# This is INCREDIBLY unlikely, but the cortical area referenced by the mapping was deleted right before we got this response back
		push_error("Retrieved cortical mapping refers to a cortical area no longer in the cache! Skipping!")
		return
	var source_area: CorticalArea =  FeagiCache.cortical_areas_cache.cortical_areas[source_destination_ID_str[0]]
	var destination_area: CorticalArea =  FeagiCache.cortical_areas_cache.cortical_areas[source_destination_ID_str[1]]
	var properties: MappingProperties
	if _response_code == 404:
		# Feagi does this when it cannot find a mapping
		properties = MappingProperties.create_empty_mapping(source_area, destination_area)
	else:
		# feagi returned a filled mappings
		var raw_mapping_properties: Array = _body_to_untyped_array(response_body)
		properties = MappingProperties.from_MappingPropertys(raw_mapping_properties, source_area, destination_area)
	source_area.set_efferent_mapping_properties_from_FEAGI(properties, destination_area)

func GET_GE_morphologyUsage(response_code: int, response_body: PackedByteArray, morphology_name: StringName) -> void:
	if response_code == 400:
		push_error("Unable to access in FEAGI morphology of name %s" % morphology_name)
		return
	if response_code == 404:
		push_error("Unable to locate in FEAGI morphology of name %s" % morphology_name)
		return
	if morphology_name not in FeagiCache.morphology_cache.available_morphologies.keys():
		push_error("RACE CONDITION! Morphology %s was removed before we returned usage information! Skipping!" % morphology_name)
		return
	var usage_array: Array[Array] = []
	usage_array.assign(_body_to_untyped_array(response_body))
	var morphology_used: Morphology = FeagiCache.morphology_cache.available_morphologies[morphology_name]
	# Emit for both the specific morpholoy and broadly to support various use cases
	morphology_used.retrieved_latest_usuage_of_morphology.emit(usage_array)
	FeagiEvents.retrieved_latest_usuage_of_morphology.emit(morphology_used, usage_array)
	

func GET_GE_morphology(_response_code: int, response_body: PackedByteArray, _irrelevant_data: Variant) -> void:
	if _response_code == 404:
		push_error("FEAGI was unable to find the requested morphology details. Skipping!")
		return
	if _response_code == 400:
		push_error("FEAGI had an unknown error retrieving morpholgy details. Skipping!")
		return
	var morphology_dict: Dictionary = _body_to_dictionary(response_body)
	FeagiCache.morphology_cache.update_morphology_by_dict(morphology_dict)

func GET_MON_neuron_membranePotential(response_code: int, response_body: PackedByteArray, corticalID: String) -> void:
	if response_code == 404:
		push_warning("FEAGI unable to check for membrane potential monitoring status!")
		return
	if corticalID not in FeagiCache.cortical_areas_cache.cortical_areas.keys():
		push_error("Unable to locate cortical ID " + corticalID)
		return
	FeagiCache.cortical_areas_cache.cortical_areas[corticalID].is_monitoring_membrane_potential = FEAGIUtils.string_2_bool(response_body.get_string_from_utf8())

func GET_MON_neuron_synapticPotential(response_code: int, response_body: PackedByteArray, corticalID: String) -> void:
	if response_code == 404:
		push_warning("FEAGI unable to check for synaptic potential monitoring status!")
		return
	if corticalID not in FeagiCache.cortical_areas_cache.cortical_areas.keys():
		push_error("Unable to locate cortical ID " + corticalID)
		return
	FeagiCache.cortical_areas_cache.cortical_areas[corticalID].is_monitoring_synaptic_potential = FEAGIUtils.string_2_bool(response_body.get_string_from_utf8())

func GET_BU_stimulationPeriod(_response_code: int, response_body: PackedByteArray, _irrelevant_data: Variant) -> void:
	FeagiCache.delay_between_bursts = _body_to_float(response_body)

func GET_PNS_current_ipu(response_code: int, response_body: PackedByteArray, _irrelevant_data: Variant) -> void:
	if response_code != 200:
		push_error("Unknown error trying to get current PNS IPU templates!")
		return
	var arr: Array[String] = _body_to_string_array(response_body)
	# TODO what to do with this?

func GET_PNS_current_opu(response_code: int, response_body: PackedByteArray, _irrelevant_data: Variant) -> void:
	if response_code != 200:
		push_error("Unknown error trying to get current PNS OPU templates!")
		return
	var arr: Array[String] = _body_to_string_array(response_body)
	# TODO what to do with this?

func GET_GE_corticalTypes(response_code: int, response_body: PackedByteArray, _irrelevant_data: Variant) -> void:
	if response_code != 200:
		push_error("Unknown error trying to get current cortical templates!")
		return
	var raw_templates: Dictionary = _body_to_dictionary(response_body)
	FeagiCache.feagi_set_cortical_templates(raw_templates)

func GET_healthCheck_POLL_genome_availability(response_code: int, response_body: PackedByteArray, _irrelevant_data: Variant) -> void:
	FeagiRequests.initial_FEAGI_calls()
	FeagiRequests.poll_genome_availability_monitoring()
	if response_code != 200: 
		return
	var statuses: Dictionary = _body_to_dictionary(response_body)
	FeagiEvents.retrieved_latest_FEAGI_health.emit(
		statuses["burst_engine"],
		statuses["genome_availability"],
		statuses["genome_validity"],
		statuses["brain_readiness"]
	)

func GET_healthCheck_POLL_health(response_code: int, response_body: PackedByteArray, _irrelevant_data: Variant) -> void:
	if response_code != 200: 
		return
	print("polled health")
	var statuses: Dictionary = _body_to_dictionary(response_body)
	FeagiEvents.retrieved_latest_FEAGI_health.emit(
		statuses["burst_engine"],
		statuses["genome_availability"],
		statuses["genome_validity"],
		statuses["brain_readiness"]
	)

func POST_GE_corticalArea(_response_code: int, response_body: PackedByteArray, other_properties: Dictionary) -> void:
	if _response_code == 422:
		push_error("Unable to process new cortical area dict, skipping!")
		return
	var cortical_ID_raw: Dictionary = _body_to_dictionary(response_body)
	if "cortical_id" not in cortical_ID_raw.keys():
		push_error("FEAGI did not respond with a cortical ID when trying to generate a cortical area, something likely went wrong")
		return
	if cortical_ID_raw["cortical_id"] == null:
		push_error("FEAGI did not respond with a cortical ID when trying to generate a cortical area, something likely went wrong")
		return
	
	var created_cortical_ID: StringName = cortical_ID_raw["cortical_id"]
	var template: CorticalTemplate = FeagiCache.cortical_templates[other_properties["cortical_type_str"]].templates[created_cortical_ID]
	
	var is_2D_coordinates_defined: bool = false
	var coordinates_2D: Vector2 = Vector2(0,0)
	
	if "coordinates_2d" in other_properties.keys():
		is_2D_coordinates_defined = true
		coordinates_2D = other_properties["coordinates_2d"]
	
	FeagiCache.cortical_areas_cache.add_new_IOPU_cortical_area(template, created_cortical_ID, other_properties["channel_count"], other_properties["coordinates_3d"], 
		is_2D_coordinates_defined, coordinates_2D)
	

func POST_GE_customCorticalArea(_response_code: int, response_body: PackedByteArray, other_properties: Dictionary) -> void:
	# returns a dict of cortical ID
	if _response_code == 422:
		push_error("Unable to process new custom cortical area dict, skipping!")
		return

	var cortical_ID_raw: Dictionary = _body_to_dictionary(response_body)

	if "cortical_id" not in cortical_ID_raw.keys():
		push_error("FEAGI did not respond with a cortical ID when trying to generate a custom cortical area, something likely went wrong")
		return

	var is_2D_coordinates_defined: bool = false
	var coordinates_2D: Vector2 = Vector2(0,0)
	
	if "coordinates_2d" in other_properties.keys():
		is_2D_coordinates_defined = true
		coordinates_2D = other_properties["coordinates_2d"]
	
	FeagiCache.cortical_areas_cache.add_cortical_area(
		cortical_ID_raw["cortical_id"],
		other_properties["cortical_name"],
		other_properties["coordinates_3d"]	,
		other_properties["cortical_dimensions"],
		is_2D_coordinates_defined,
		coordinates_2D,
		CorticalArea.CORTICAL_AREA_TYPE.CUSTOM
	)

func POST_FE_burstEngine(_response_code: int, _response_body: PackedByteArray, _irrelevant_data: Variant) -> void:
	# no real error handling from FEAGI right now, so we cannot do anything here
	pass

func POST_GE_morphology(_response_code: int, _response_body: PackedByteArray, requested_properties: Dictionary) -> void:
	if _response_code == 422:
		push_error("Unable to process add morphology %s, skipping!" % [requested_properties["morphology_name"]])
		return
	FeagiCache.morphology_cache.add_morphology_by_dict(requested_properties)
	
func POST_MON_neuron_membranePotential(response_code: int, _response_body: PackedByteArray, set_values: Dictionary) -> void:
	if response_code == 404:
		push_error("FEAGI unable to set setting for membrane potential monitoring!")
		FeagiCache.cortical_areas_cache.cortical_areas[set_values["ID"]].is_monitoring_membrane_potential = FeagiCache.cortical_areas_cache.cortical_areas[set_values["ID"]].is_monitoring_membrane_potential
		return
	if set_values["ID"] not in FeagiCache.cortical_areas_cache.cortical_areas.keys():
		push_error("Unable to find cortical area %s in cache to update monitoring status of membrane potential" % set_values["ID"])
		FeagiCache.cortical_areas_cache.cortical_areas[set_values["ID"]].is_monitoring_membrane_potential = FeagiCache.cortical_areas_cache.cortical_areas[set_values["ID"]].is_monitoring_membrane_potential
		return
	FeagiCache.cortical_areas_cache.cortical_areas[set_values["ID"]].is_monitoring_membrane_potential = set_values["state"]
	
func POST_MON_neuron_synapticPotential(response_code: int, _response_body: PackedByteArray, set_values: Dictionary) -> void:
	if response_code == 404:
		push_error("FEAGI unable to set setting for synaptic potential monitoring!")
		FeagiCache.cortical_areas_cache.cortical_areas[set_values["ID"]].is_monitoring_synaptic_potential = FeagiCache.cortical_areas_cache.cortical_areas[set_values["ID"]].is_monitoring_synaptic_potential
		return	
	if set_values["ID"] not in FeagiCache.cortical_areas_cache.cortical_areas.keys():
		push_error("Unable to find cortical area %s in cache to update monitoring status of synaptic potential" % set_values["ID"])
		FeagiCache.cortical_areas_cache.cortical_areas[set_values["ID"]].is_monitoring_synaptic_potential = FeagiCache.cortical_areas_cache.cortical_areas[set_values["ID"]].is_monitoring_synaptic_potential
		return
	FeagiCache.cortical_areas_cache.cortical_areas[set_values["ID"]].is_monitoring_synaptic_potential = set_values["state"]


func PUT_GE_mappingProperties(_response_code: int, _response_body: PackedByteArray, src_dst_data: Dictionary) -> void:
	if _response_code == 422:
		push_error("Unable to process new mappings! Skipping!")
		return
	var cortical_src: CorticalArea = src_dst_data["src"]
	var cortical_dst: CorticalArea = src_dst_data["dst"]
	print("FEAGI sucessfully updated the mapping between %s and %s" % [cortical_src.cortical_ID, cortical_dst.cortical_ID])
	var mapping_count: int = src_dst_data["count"]
	if mapping_count == 0:
		# we removed the mapping
		cortical_src.remove_efferent_connection(cortical_dst)
		return
	# assume we add / modify the mapping
	cortical_src.set_efferent_connection(cortical_dst, mapping_count)


func PUT_GE_corticalArea(_response_code: int, _response_body: PackedByteArray, changed_cortical_ID: StringName) -> void:
	if _response_code == 422:
		push_error("Unable to process new properties for cortical area %s, skipping!" % [changed_cortical_ID])
		return
	
	# Property change accepted, pull latest details
	FeagiRequests.refresh_cortical_area(FeagiCache.cortical_areas_cache.cortical_areas[changed_cortical_ID], true)
	pass

func PUT_GE_morphology(_response_code: int, _response_body: PackedByteArray, changed_morphology_name: StringName) -> void:
	if _response_code == 422:
		push_error("Unable to process new properties for morphology %s, skipping!" % [changed_morphology_name])
		return
	FeagiRequests.refresh_morphology_properties(changed_morphology_name)

## returns nothing, so we passthrough the deleted cortical ID
func DELETE_GE_corticalArea(_response_code: int, _response_body: PackedByteArray, deleted_cortical_ID: StringName) -> void:
	print("FEAGI confirmed deletion of cortical area " + deleted_cortical_ID)
	FeagiCache.cortical_areas_cache.remove_cortical_area(deleted_cortical_ID)

func DELETE_GE_morphology(_response_code: int, _response_body: PackedByteArray, deleted_morphology_name: StringName) -> void:
	print("FEAGI confirmed deletion of morphology " + deleted_morphology_name)
	FeagiCache.morphology_cache.remove_morphology(deleted_morphology_name)





func _body_to_untyped_array(response_body: PackedByteArray) -> Array:
	var data = response_body.get_string_from_utf8()
	return JSON.parse_string(data)

func _body_to_string_array(response_body: PackedByteArray) -> PackedStringArray:
	return JSON.parse_string(response_body.get_string_from_utf8())

func _body_to_dictionary(response_body: PackedByteArray) -> Dictionary:
	return JSON.parse_string(response_body.get_string_from_utf8())

func _body_to_float(response_body: PackedByteArray) -> float:
	return (str(response_body.get_string_from_utf8())).to_float()



