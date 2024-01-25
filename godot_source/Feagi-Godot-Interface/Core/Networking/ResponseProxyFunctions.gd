extends Object
class_name ResponseProxyFunctions
## All responses from FEAGI calls go through these calls

func GET_GE_fileName(_response_code: int, response_body: PackedByteArray, _irrelevant_data: Variant) -> void:
	FeagiCache.genome_name = response_body.get_string_from_utf8()


## returns dict of morphology names keyd to their type string
func GET_MO_list_types(_response_code: int, response_body: PackedByteArray, _irrelevant_data: Variant) -> void:
	return
	var morphologies_and_types: Dictionary
	if _response_code == 422:
		morphologies_and_types = {}
	else:
		morphologies_and_types = _body_to_dictionary(response_body)
	FeagiCache.morphology_cache.update_morphology_cache_from_summary(morphologies_and_types)
	FeagiEvents.retrieved_latest_morphology_listing.emit(morphologies_and_types.keys())

## returns a dict of the mapping of cortical areas
func GET_GE_corticalMap_detailed(_response_code: int, response_body: PackedByteArray, _irrelevant_data: Variant) -> void:
	var cortical_map: Dictionary = _body_to_dictionary(response_body)
	var source_area: BaseCorticalArea
	var destination_area: BaseCorticalArea
	var raw_mappings: Array[Dictionary] = []
	
	for source_cortical_ID: StringName in cortical_map.keys():
		if cortical_map[source_cortical_ID] == {}:
			continue # no efferent connections for the current searching source cortical ID
		if source_cortical_ID not in FeagiCache.cortical_areas_cache.cortical_areas.keys():
			push_error("Retrieved mapping from nonexistant cortical area %s! Skipping!" % source_cortical_ID)
			continue
	
		source_area = FeagiCache.cortical_areas_cache.cortical_areas[source_cortical_ID]
		for destination_area_ID: StringName in cortical_map[source_cortical_ID]:
			if destination_area_ID not in FeagiCache.cortical_areas_cache.cortical_areas.keys():
				push_error("Retrieved mapping toward nonexistant cortical area %s! Skipping!" % destination_area_ID)
				continue
			destination_area = FeagiCache.cortical_areas_cache.cortical_areas[destination_area_ID]
			raw_mappings.assign(cortical_map[source_cortical_ID][destination_area_ID])
			source_area.set_mappings_to_efferent_area(destination_area, MappingProperty.from_array_of_dict(raw_mappings))
		
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
	
	# Clean up dictionary output
	
	FeagiCache.cortical_areas_cache.update_cortical_area_cache_from_summary(cortical_area_summary)
	FeagiRequests.refresh_connection_list()


func GET_GE_circuits(_response_code: int, response_body: PackedByteArray, _irrelevant_data: Variant) -> void:
	var string_array: PackedStringArray = PackedStringArray(_body_to_string_array(response_body))
	FeagiEvents.retrieved_circuit_listing.emit(string_array)

func GET_GE_circuitDescription(response_code: int, response_body: PackedByteArray, circuit_name: StringName) -> void:
	if response_code != 200:
		push_error("Unable to retrieve circuit information for %s! Skipping!" % circuit_name)
		return
	var circuit_properties: Dictionary = _body_to_dictionary(response_body)
	var details: CircuitDetails = CircuitDetails.new(circuit_name, FEAGIUtils.array_to_vector3i(circuit_properties["size"]), circuit_properties["description"])
	FeagiEvents.retrieved_circuit_details.emit(details)

	
func GET_GE_mappingProperties(_response_code: int, response_body: PackedByteArray, source_destination_ID_str: Array) -> void:
	if source_destination_ID_str[0] not in FeagiCache.cortical_areas_cache.cortical_areas.keys() or source_destination_ID_str[1] not in FeagiCache.cortical_areas_cache.cortical_areas.keys():
		# This is INCREDIBLY unlikely, but the cortical area referenced by the mapping was deleted right before we got this response back
		push_error("UI: WINDOW: Retrieved cortical mapping refers to a cortical area no longer in the cache! Skipping!")
		return
	var source_area: BaseCorticalArea =  FeagiCache.cortical_areas_cache.cortical_areas[source_destination_ID_str[0]]
	var destination_area: BaseCorticalArea =  FeagiCache.cortical_areas_cache.cortical_areas[source_destination_ID_str[1]]
	var properties: Array[MappingProperty] = []
	if _response_code == 404:
		# Feagi does this when it cannot find a mapping
		pass
	else:
		# feagi returned a filled mappings
		var raw_dicts: Array[Dictionary] = []
		raw_dicts.assign(_body_to_untyped_array(response_body))
		properties = MappingProperty.from_array_of_dict(raw_dicts)
		
	source_area.set_mappings_to_efferent_area(destination_area, properties)

func GET_GE_morphologyUsage(response_code: int, response_body: PackedByteArray, morphology_name: StringName) -> void:
	if response_code == 400:
		push_error("Unable to access in FEAGI morphology of name %s" % morphology_name)
		VisConfig.UI_manager.make_notification("Unable to access in FEAGI morphology of name %s" % morphology_name, SingleNotification.NOTIFICATION_TYPE.ERROR)
		return
	if response_code == 404:
		push_error("Unable to locate in FEAGI morphology of name %s" % morphology_name)
		VisConfig.UI_manager.make_notification("Unable to locate in FEAGI morphology of name %s" % morphology_name, SingleNotification.NOTIFICATION_TYPE.ERROR)
		return
	if morphology_name not in FeagiCache.morphology_cache.available_morphologies.keys():
		push_error("RACE CONDITION! Morphology %s was removed before we returned usage information! Skipping!" % morphology_name)
		return
	var usage_array: Array[Array] = []
	usage_array.assign(_body_to_untyped_array(response_body))
	var morphology_used: Morphology = FeagiCache.morphology_cache.available_morphologies[morphology_name]
	morphology_used.feagi_update_usage(usage_array)
	FeagiEvents.retrieved_latest_usuage_of_morphology.emit(morphology_used, usage_array)
	

func GET_GE_morphology(_response_code: int, response_body: PackedByteArray, _irrelevant_data: Variant) -> void:
	if _response_code == 404:
		push_error("FEAGI was unable to find the requested morphology details. Skipping!")
		VisConfig.UI_manager.make_notification("FEAGI was unable to find the requested morphology details. Skipping!", SingleNotification.NOTIFICATION_TYPE.ERROR)
		return
	if _response_code == 400:
		push_error("FEAGI had an unknown error retrieving morpholgy details. Skipping!")
		VisConfig.UI_manager.make_notification("FEAGI had an unknown error retrieving morpholgy details. Skipping!", SingleNotification.NOTIFICATION_TYPE.ERROR)
		return
	var morphology_dict: Dictionary = _body_to_dictionary(response_body)
	FeagiCache.morphology_cache.update_morphology_by_dict(morphology_dict)

func GET_MON_neuron_membranePotential(response_code: int, response_body: PackedByteArray, corticalID: String) -> void:
	if response_code == 404:
		push_warning("FEAGI unable to check for membrane potential monitoring status!")
		VisConfig.UI_manager.make_notification("Unable to get Membrane Potential Monitoring State. Are you running the insights DB?", SingleNotification.NOTIFICATION_TYPE.WARNING)
		return
	if corticalID not in FeagiCache.cortical_areas_cache.cortical_areas.keys():
		push_error("Unable to locate cortical ID " + corticalID)
		return
	FeagiCache.cortical_areas_cache.cortical_areas[corticalID].is_monitoring_membrane_potential = FEAGIUtils.string_2_bool(response_body.get_string_from_utf8())

func GET_MON_neuron_synapticPotential(response_code: int, response_body: PackedByteArray, corticalID: String) -> void:
	if response_code == 404:
		push_warning("FEAGI unable to check for synaptic potential monitoring status!")
		VisConfig.UI_manager.make_notification("Unable to get Synaptic Potential Monitoring State. Are you running the insights DB?", SingleNotification.NOTIFICATION_TYPE.WARNING)
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
	var _arr: Array[String] = _body_to_string_array(response_body)
	# TODO what to do with this?

func GET_PNS_current_opu(response_code: int, response_body: PackedByteArray, _irrelevant_data: Variant) -> void:
	if response_code != 200:
		push_error("Unknown error trying to get current PNS OPU templates!")
		return
	var _arr: Array[String] = _body_to_string_array(response_body)
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
	var statuses: Dictionary = _body_to_dictionary(response_body)
	FeagiEvents.retrieved_latest_FEAGI_health.emit(
		statuses["burst_engine"],
		statuses["genome_availability"],
		statuses["genome_validity"],
		statuses["brain_readiness"]
	)
	# TEMP amalgamation stuff
	if "amalgamation_pending" in statuses.keys():
		
		if VisConfig.TEMP_last_amalgamation_ID == statuses["amalgamation_pending"]["amalgamation_id"]:
			return
		VisConfig.TEMP_last_amalgamation_ID = statuses["amalgamation_pending"]["amalgamation_id"]
		
		# We have an amalgamation pending
		VisConfig.UI_manager.window_manager.spawn_amalgamation_window(statuses["amalgamation_pending"]["amalgamation_id"], statuses["amalgamation_pending"]["genome_title"], FEAGIUtils.array_to_vector3i(statuses["amalgamation_pending"]["circuit_size"]))

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
	var cortical_type: BaseCorticalArea.CORTICAL_AREA_TYPE = other_properties["cortical_type"]
	var template: CorticalTemplate = FeagiCache.cortical_templates[BaseCorticalArea.cortical_type_to_str(cortical_type)].templates[created_cortical_ID]
	
	var is_2D_coordinates_defined: bool = false
	var coordinates_2D: Vector2 = Vector2(0,0)
	
	if "coordinates_2d" in other_properties.keys():
		is_2D_coordinates_defined = true
		coordinates_2D = other_properties["coordinates_2d"]
	
	match(cortical_type):
		BaseCorticalArea.CORTICAL_AREA_TYPE.IPU:
			FeagiCache.cortical_areas_cache.add_input_cortical_area(created_cortical_ID, template, other_properties["coordinates_3d"], is_2D_coordinates_defined, coordinates_2D)
		BaseCorticalArea.CORTICAL_AREA_TYPE.OPU:
			FeagiCache.cortical_areas_cache.add_output_cortical_area(created_cortical_ID, template, other_properties["coordinates_3d"], is_2D_coordinates_defined, coordinates_2D)
		_:
			push_error("Unknown type of cortical area created! Skipping!")


func POST_GE_customCorticalArea(_response_code: int, response_body: PackedByteArray, other_properties: Dictionary) -> void:
	# returns a dict of cortical ID
	if _response_code == 422:
		push_error("Unable to process new custom cortical area dict, skipping!")
		return

	var cortical_ID_raw: Dictionary = _body_to_dictionary(response_body)

	if "cortical_id" not in cortical_ID_raw.keys():
		push_error("FEAGI did not respond with a cortical ID when trying to generate a custom cortical area, something likely went wrong")
		return
	
	FeagiCache.cortical_areas_cache.add_cortical_area_from_dict(other_properties, cortical_ID_raw["cortical_id"])
	
	VisConfig.UI_manager.make_notification("Cortical Area Created!")

func POST_FE_burstEngine(_response_code: int, _response_body: PackedByteArray, _irrelevant_data: Variant) -> void:
	# no real error handling from FEAGI right now, so we cannot do anything here
	pass

func POST_GE_morphology(_response_code: int, _response_body: PackedByteArray, requested_properties: Dictionary) -> void:
	if _response_code == 422:
		push_error("Unable to process add morphology %s, skipping!" % [requested_properties["morphology_name"]])
		return
	FeagiCache.morphology_cache.add_morphology_by_dict(requested_properties)

func POST_GE_append(_response_code: int, _response_body: PackedByteArray, _requested_properties: Dictionary) -> void:
	return #TODO trigger reload?

func POST_MON_neuron_membranePotential(response_code: int, _response_body: PackedByteArray, set_values: Dictionary) -> void:
	if response_code == 404:
		push_error("FEAGI unable to set setting for membrane potential monitoring!")
		VisConfig.UI_manager.make_notification("FEAGI unable to set setting for membrane potential monitoring!", SingleNotification.NOTIFICATION_TYPE.ERROR)
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
		VisConfig.UI_manager.make_notification("FEAGI unable to set setting for synaptic potential monitoring!", SingleNotification.NOTIFICATION_TYPE.ERROR)
		FeagiCache.cortical_areas_cache.cortical_areas[set_values["ID"]].is_monitoring_synaptic_potential = FeagiCache.cortical_areas_cache.cortical_areas[set_values["ID"]].is_monitoring_synaptic_potential
		return	
	if set_values["ID"] not in FeagiCache.cortical_areas_cache.cortical_areas.keys():
		push_error("Unable to find cortical area %s in cache to update monitoring status of synaptic potential" % set_values["ID"])
		FeagiCache.cortical_areas_cache.cortical_areas[set_values["ID"]].is_monitoring_synaptic_potential = FeagiCache.cortical_areas_cache.cortical_areas[set_values["ID"]].is_monitoring_synaptic_potential
		return
	FeagiCache.cortical_areas_cache.cortical_areas[set_values["ID"]].is_monitoring_synaptic_potential = set_values["state"]

func POST_GE_amalgamationDestination(response_code: int, _response_body: PackedByteArray, _irrelevant: Variant) -> void:
	print("Feagi recieved amalgamation destination response!")
	pass

func PUT_GE_mappingProperties(_response_code: int, _response_body: PackedByteArray, src_dst_data: Dictionary) -> void:
	if _response_code == 422:
		push_error("Unable to process new mappings! Skipping!")
		return
	var cortical_src: BaseCorticalArea = src_dst_data["src"]
	var cortical_dst: BaseCorticalArea = src_dst_data["dst"]
	print("FEAGI sucessfully updated the mapping between %s and %s" % [cortical_src.cortical_ID, cortical_dst.cortical_ID])
	var mappings: Array[MappingProperty] = []
	var dict_arr: Array[Dictionary] = []
	dict_arr.assign(src_dst_data["mapping_data_raw"])
	mappings.assign(MappingProperty.from_array_of_dict(dict_arr))
	cortical_src.set_mappings_to_efferent_area(cortical_dst, mappings)


func PUT_GE_corticalArea(response_code: int, _response_body: PackedByteArray, changed_cortical_ID: StringName) -> void:
	if response_code == 422:
		push_error("Unable to process new properties for cortical area %s, skipping!" % [changed_cortical_ID])
		return
	
	# Property change accepted, pull latest details
	FeagiRequests.refresh_cortical_area(FeagiCache.cortical_areas_cache.cortical_areas[changed_cortical_ID], true)
	pass

func PUT_GE_morphology(response_code: int, _response_body: PackedByteArray, changed_morphology_name: StringName) -> void:
	if response_code == 422:
		push_error("Unable to process new properties for morphology %s, skipping!" % [changed_morphology_name])
		return
	FeagiRequests.refresh_morphology_properties(changed_morphology_name)

func PUT_GE_coord2D(_response_code: int, _response_body: PackedByteArray, changed_IDs_and_locations: Dictionary) -> void:
	# TODO catch errors - at this time feagi only returns 200
	print("FEAGI: Confirmed the mass 2D movement of %d cortical areas" % len(changed_IDs_and_locations.keys()))
	FeagiCache.cortical_areas_cache.FEAGI_mass_update_2D_positions(changed_IDs_and_locations)

## returns nothing, so we passthrough the deleted cortical ID
func DELETE_GE_corticalArea(_response_code: int, _response_body: PackedByteArray, deleted_cortical_ID: StringName) -> void:
	print("FEAGI confirmed deletion of cortical area " + deleted_cortical_ID)
	VisConfig.UI_manager.make_notification("Cortical Area %s Deleted!" %FeagiCache.cortical_areas_cache.cortical_areas[deleted_cortical_ID].name)
	FeagiCache.cortical_areas_cache.remove_cortical_area(deleted_cortical_ID)

func DELETE_GE_morphology(_response_code: int, _response_body: PackedByteArray, deleted_morphology_name: StringName) -> void:
	print("FEAGI confirmed deletion of morphology " + deleted_morphology_name)
	FeagiCache.morphology_cache.remove_morphology(deleted_morphology_name)

func DELETE_GE_amalgamationCancelation(_response_code: int, _response_body: PackedByteArray, _irrelevant: Variant) -> void:
	print("FEAGI deleted amalgamation request")
	


func _body_to_untyped_array(response_body: PackedByteArray) -> Array:
	var data = response_body.get_string_from_utf8()
	return JSON.parse_string(data)

func _body_to_string_array(response_body: PackedByteArray) -> PackedStringArray:
	return JSON.parse_string(response_body.get_string_from_utf8())

func _body_to_dictionary(response_body: PackedByteArray) -> Dictionary:
	return JSON.parse_string(response_body.get_string_from_utf8())

func _body_to_float(response_body: PackedByteArray) -> float:
	return (str(response_body.get_string_from_utf8())).to_float()



