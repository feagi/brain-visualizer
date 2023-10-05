extends Object
class_name CallList
## The specific calls made to FEAGI

var _address_list: AddressList
var _interface_ref: NetworkInterface
var _response_functions_ref: ResponseProxyFunctions

func _init(interface_reference: NetworkInterface, response_functions_reference: ResponseProxyFunctions):
	_interface_ref = interface_reference
	_response_functions_ref = response_functions_reference
	_address_list = AddressList.new(_interface_ref.feagi_root_web_address)

## Get current IPU list
func GET_FE_pns_current_ipu():
	_interface_ref.single_FEAGI_request(_address_list.GET_feagi_pns_current_ipu, HTTPClient.Method.METHOD_GET, _response_functions_ref.GET_FE_pns_current_ipu)

## Get current OPU list
func GET_FE_pns_current_opu():
	_interface_ref.single_FEAGI_request(_address_list.GET_feagi_pns_current_opu, HTTPClient.Method.METHOD_GET, _response_functions_ref.GET_FE_pns_current_opu)

## Get Cortical Area ID lists
func GET_GE_corticalAreaIDList():
	_interface_ref.single_FEAGI_request(_address_list.GET_genome_corticalAreaIDList, HTTPClient.Method.METHOD_GET, _response_functions_ref.GET_GE_corticalAreaIDList)

## Get list of morphologies
func GET_GE_morphologyList():
	_interface_ref.single_FEAGI_request(_address_list.GET_genome_morphologyList, HTTPClient.Method.METHOD_GET, _response_functions_ref.GET_GE_morphologyList)

## Get genome filename
func GET_GE_fileName():
	_interface_ref.single_FEAGI_request(_address_list.GET_genome_fileName, HTTPClient.Method.METHOD_GET, _response_functions_ref.GET_GE_fileName)

## return dict of cortical IDs mapped with dict of connected cortical area and number of mappings
func GET_GE_corticalMap():
	_interface_ref.single_FEAGI_request(_address_list.GET_genome_corticalMap, HTTPClient.Method.METHOD_GET, _response_functions_ref.GET_GE_corticalMap)

## return dict of cortical IDs mapped with list of connected cortical areas
func GET_CO_properties_mappings():
	_interface_ref.single_FEAGI_request(_address_list.GET_connectome_properties_mappings, HTTPClient.Method.METHOD_GET, _response_functions_ref.GET_CO_properties_mappings)

## return list of cortical area names
func GET_GE_corticalAreaNameList():
	_interface_ref.single_FEAGI_request(_address_list.GET_genome_corticalAreaNameList, HTTPClient.Method.METHOD_GET, _response_functions_ref.GET_GE_corticalAreaNameList)

## by cortical name, returns 3D coordinates of the cortical area
func GET_GE_corticalNameLocation(corticalName: String):
	_interface_ref.single_FEAGI_request(_address_list.GET_genome_corticalNameLocation+corticalName, HTTPClient.Method.METHOD_GET, _response_functions_ref.GET_GE_corticalNameLocation)

## By corticalID, returns dictionary of all cortical area details
func GET_GE_corticalArea(corticalID: StringName):
	_interface_ref.single_FEAGI_request(_address_list.GET_genome_corticalArea + corticalID, HTTPClient.Method.METHOD_GET, _response_functions_ref.GET_GE_corticalArea)

## By corticalID, returns dictionary of all cortical area details, but keeps polling until the cortical area is no longer transforming
func GET_GE_corticalArea_POLL(corticalID: StringName):
	var searching_for: PollingMethodDictionaryValue = PollingMethodDictionaryValue.new("transforming", false)
	_interface_ref.repeating_FEAGI_request(_address_list.GET_genome_corticalArea + corticalID, HTTPClient.Method.METHOD_GET, _response_functions_ref.GET_GE_corticalArea,
		Callable() ,searching_for)
	

## returns dict of cortical names, mapped to an array of positions, unknown boolean, size, and ID
func GET_CO_properties_dimensions():
	_interface_ref.single_FEAGI_request(_address_list.GET_connectome_properties_dimensions, HTTPClient.Method.METHOD_GET, _response_functions_ref.GET_CO_properties_dimensions)

## returns pause between bursts in seconds
func GET_BU_stimulationPeriod():
	_interface_ref.single_FEAGI_request(_address_list.GET_burstEngine_stimulationPeriod, HTTPClient.Method.METHOD_GET, _response_functions_ref.GET_BU_stimulationPeriod)

## returns dict of cortical IDs mapped to their names
func GET_GE_corticalIDNameMapping():
	_interface_ref.single_FEAGI_request(_address_list.GET_genome_corticalIDNameMapping, HTTPClient.Method.METHOD_GET, _response_functions_ref.GET_GE_corticalIDNameMapping)

## returns list of connected cortical IDs upsteam given ID
func GET_GE_corticalMappings_afferents_corticalArea(corticalID: StringName):
	_interface_ref.single_FEAGI_request(_address_list.GET_genome_corticalMappings_afferents_corticalArea_CORTICALAREAEQUALS+corticalID, HTTPClient.Method.METHOD_GET, _response_functions_ref.GET_GE_corticalMappings_afferents_corticalArea)

## returns list of connected cortical IDs downstream given ID
func GET_GE_corticalMappings_efferents_corticalArea(corticalID: StringName):
	_interface_ref.single_FEAGI_request(_address_list.GET_genome_corticalMappings_efferents_corticalArea_CORTICALAREAEQUALS+corticalID, HTTPClient.Method.METHOD_GET, _response_functions_ref.GET_GE_corticalMappings_efferents_corticalArea)

## given name of morphology, returns dict of morphlogy details
func GET_GE_morphology(morphologyName: String):
	_interface_ref.single_FEAGI_request(_address_list.GET_genome_morphologyName+morphologyName, HTTPClient.Method.METHOD_GET, _response_functions_ref.GET_GE_morphology)

## given morphology name, returns an array of arrays of source to destination cortical IDs where said morphology is used
func GET_GE_morphologyUsage(morphologyName: String):
	_interface_ref.single_FEAGI_request(_address_list.GET_genome_morphologyUsage+morphologyName, HTTPClient.Method.METHOD_GET, _response_functions_ref.GET_GE_morphologyUsage, null,  morphologyName)

## returns an array of dicts of morphology details of morphologies used between 2 cortical areas
func GET_GE_mappingProperties(sourceCorticalID: StringName, destinationCorticalID: StringName):
	# Pass through the source and destination cortical areas
	_interface_ref.single_FEAGI_request(_address_list.GET_genome_mappingProperties+sourceCorticalID+"&dst_cortical_area="+destinationCorticalID, HTTPClient.Method.METHOD_GET, _response_functions_ref.GET_GE_mappingProperties, null, [sourceCorticalID, destinationCorticalID])

## returns a string array of circuit file names found in feagi
func GET_GE_circuits():
	_interface_ref.single_FEAGI_request(_address_list.GET_genome_circuits, HTTPClient.Method.METHOD_GET, _response_functions_ref.GET_GE_circuits)

## returns a dictionary of the properties of the given circuit
func GET_GE_circuitDescription(circuit_file_name: String):
	## Pass Through circuit name so we know what circuit we are referring to at the response side
	_interface_ref.single_FEAGI_request(_address_list.GET_genome_circuitDescription+circuit_file_name, HTTPClient.Method.METHOD_GET, _response_functions_ref.GET_GE_circuitDescription, null, circuit_file_name)

## returns dict by cortical ID of int arrays of 2D location of cortical area (array will be null null if no location is saved in FEAGI)
func GET_GE_CorticalLocations2D():
	_interface_ref.single_FEAGI_request(_address_list.GET_genome_corticalLocations2D , HTTPClient.Method.METHOD_GET, _response_functions_ref.GET_GE_CorticalLocations2D)

## returns dict by cortical ID of cortical name, type, visibility, 2d and 3d positions, and dimensions
func GET_GE_CorticalArea_geometry():
	_interface_ref.single_FEAGI_request(_address_list.GET_genome_corticalArea_geometry , HTTPClient.Method.METHOD_GET, _response_functions_ref.GET_GE_CorticalArea_geometry)

## returns dict by cortical type of different cortical templates for non-custom cortical areas
func GET_GE_corticalTypes():
	_interface_ref.single_FEAGI_request(_address_list.GET_genome_corticalTypes , HTTPClient.Method.METHOD_GET, _response_functions_ref.GET_GE_corticalTypes)

## returns bool of if a cortical area is monitoring membrane potential
func GET_MO_neuron_membranePotential(corticalID: StringName):
	_interface_ref.single_FEAGI_request(_address_list.GET_monitoring_neuron_membranePotential+corticalID, HTTPClient.Method.METHOD_GET, _response_functions_ref.GET_MON_neuron_membranePotential, null, corticalID)

## returns bool of if a cortical area is monitoring synaptic potential
func GET_MO_neuron_synapticPotential(corticalID: StringName):
	_interface_ref.single_FEAGI_request(_address_list.GET_monitoring_neuron_synapticPotential+corticalID, HTTPClient.Method.METHOD_GET, _response_functions_ref.GET_MON_neuron_synapticPotential, null, corticalID)

func GET_GE_corticalTypeOptions(corticalType: String):
	_interface_ref.single_FEAGI_request(_address_list.GET_genome_corticalTypeOptions_CORTICALTYPEQUALS+corticalType, HTTPClient.Method.METHOD_GET, _response_functions_ref.GET_GE_corticalTypeOptions)

## returns dict of various feagi health stats as booleans
func GET_healthCheck():
	_interface_ref.single_FEAGI_request(_address_list.GET_healthCheck, HTTPClient.Method.METHOD_GET, _response_functions_ref.GET_healthCheck)

## returns dict of various feagi health stats as booleans
func GET_healthCheck_POLL_GENOME():
	var searching_for: PollingMethodDictionaryValue = PollingMethodDictionaryValue.new("genome_availability", true)
	_interface_ref.repeating_FEAGI_request(_address_list.GET_healthCheck, HTTPClient.Method.METHOD_GET, _response_functions_ref.GET_healthCheck_POLL_genome_availability, Callable(), searching_for)

## returns dict of various feagi health stats as booleans
func GET_healthCheck_POLL_MONITORING():
	var dont_stop: PollingMethodNone = PollingMethodNone.new(false)
	_interface_ref.repeating_FEAGI_request(_address_list.GET_healthCheck, HTTPClient.Method.METHOD_GET, _response_functions_ref.GET_healthCheck_POLL_health, _response_functions_ref.GET_healthCheck_POLL_health, dont_stop, null, null, 10.0)

## returns dict by corticalID, with name, type, and 2d position
func GET_CO_corticalAreas_list_detailed():
	_interface_ref.single_FEAGI_request(_address_list.GET_connectome_corticalAreas_list_detailed, HTTPClient.Method.METHOD_GET, _response_functions_ref.GET_CO_corticalAreas_list_detailed)

## returns dict of morphology names keyd to their type string
func GET_MO_list_types(): # USED 1x
	_interface_ref.single_FEAGI_request(_address_list.GET_morphologies_list_types, HTTPClient.Method.METHOD_GET, _response_functions_ref.GET_MO_list_types)

## Returns membrane potential monitoring state of a cortical area
func GET_MON_neuron_membranePotential(cortical_ID: StringName) -> void:
	_interface_ref.single_FEAGI_request(_address_list.GET_monitoring_neuron_membranePotential+cortical_ID, HTTPClient.Method.METHOD_GET, _response_functions_ref.GET_MON_neuron_membranePotential)

## Returns synaptic potential monitoring state of a cortical area
func GET_MON_neuron_synapticPotential(cortical_ID: StringName) -> void:
	_interface_ref.single_FEAGI_request(_address_list.GET_monitoring_neuron_synapticPotential+cortical_ID, HTTPClient.Method.METHOD_GET, _response_functions_ref.GET_MON_neuron_membranePotential)

## returns a list of IDs (not cortical loaded) of areas for initing IPUs
func GET_PNS_current_ipu() -> void:
	_interface_ref.single_FEAGI_request(_address_list.GET_pns_current_ipu, HTTPClient.Method.METHOD_GET, _response_functions_ref.GET_PNS_current_ipu)

## returns a list of IDs (not cortical loaded) of areas for initing OPUs
func GET_PNS_current_opu() -> void:
	_interface_ref.single_FEAGI_request(_address_list.GET_pns_current_opu, HTTPClient.Method.METHOD_GET, _response_functions_ref.GET_PNS_current_opu)



## sets delay between bursts in seconds
func POST_FE_burstEngine(newBurstRate: float):
	_interface_ref.single_FEAGI_request(_address_list.POST_feagi_burstEngine, HTTPClient.Method.METHOD_POST, _response_functions_ref.POST_FE_burstEngine, {"burst_duration": newBurstRate})

## Adds a non-custom cortical area with non-definable dimensions
func POST_GE_corticalArea(template_cortical_ID: StringName, type: CorticalArea.CORTICAL_AREA_TYPE, coordinates_3D: Vector3i, 
	is_coordinate_2D_defined: bool, channel_count: int = 0, coordinates_2D: Vector2i = Vector2(0,0)) -> void:

	var to_send: Dictionary = {
		"cortical_id": template_cortical_ID,
		"coordinates_3d": FEAGIUtils.vector3i_to_array(coordinates_3D),
		"cortical_type": CorticalArea.CORTICAL_AREA_TYPE.keys()[type],
		"channel_count": channel_count
	}

	var to_buffer: Dictionary = {
		"template_cortical_ID": template_cortical_ID,
		"coordinates_3d": coordinates_3D,
		"channel_count": channel_count,
		"cortical_type_str": CorticalArea.CORTICAL_AREA_TYPE.keys()[type],
	}

	if is_coordinate_2D_defined:
		to_send["coordinates_2d"] = FEAGIUtils.vector2i_to_array(coordinates_2D)
		to_buffer["coordinates_2d"] = coordinates_2D
	else:
		to_send["coordinates_2d"] = [null,null]

	_interface_ref.single_FEAGI_request(_address_list.POST_genome_corticalArea, HTTPClient.Method.METHOD_POST, _response_functions_ref.POST_GE_corticalArea, to_send, to_buffer)



## Adds cortical area (with definable dimensions)
func POST_GE_customCorticalArea(name: StringName, coordinates_3D: Vector3i, dimensions: Vector3i, 
	is_coordinate_2D_defined: bool, coordinates_2D: Vector2i = Vector2(0,0)) -> void:

	var to_send: Dictionary = {
		"cortical_name": str(name),
		"coordinates_3d": FEAGIUtils.vector3i_to_array(coordinates_3D),
		"cortical_dimensions": FEAGIUtils.vector3i_to_array(dimensions),
		"cortical_type": CorticalArea.CORTICAL_AREA_TYPE.keys()[CorticalArea.CORTICAL_AREA_TYPE.CUSTOM]
	}

	var to_buffer: Dictionary = {
		"cortical_name": name,
		"coordinates_3d": coordinates_3D,
		"cortical_dimensions": dimensions,
	}

	if is_coordinate_2D_defined:
		to_send["coordinates_2d"] = FEAGIUtils.vector2i_to_array(coordinates_2D)
		to_buffer["coordinates_2d"] = coordinates_2D
	else:
		to_send["coordinates_2d"] = [null,null]
	

	
	# Passthrough properties so we have them to build cortical area
	_interface_ref.single_FEAGI_request(_address_list.POST_genome_customCorticalArea, HTTPClient.Method.METHOD_POST, _response_functions_ref.POST_GE_customCorticalArea, to_send, to_buffer) 

## Adds a morphology
func POST_GE_morphology(morphology_name: StringName, morphology_type: Morphology.MORPHOLOGY_TYPE, parameters: Dictionary) -> void:
	var to_buffer: Dictionary = parameters.duplicate()
	to_buffer["type"] = morphology_type
	to_buffer["morphology_name"] = morphology_name
	_interface_ref.single_FEAGI_request(_address_list.POST_genome_morphology+morphology_name+"&morphology_type="+Morphology.MORPHOLOGY_TYPE.find_key(morphology_type).to_lower(), HTTPClient.Method.METHOD_POST, _response_functions_ref.POST_GE_morphology, parameters, to_buffer)

## adds a circuit
func POST_GE_append(circuit_file_name: StringName, position: Vector3i) -> void:
	var address: StringName = _address_list.POST_genome_append+circuit_file_name+"&circuit_origin_x="+str(position.x)+"&circuit_origin_y="+str(position.y)+"&circuit_origin_z="+str(position.z)
	_interface_ref.single_FEAGI_request(address, HTTPClient.Method.METHOD_POST, _response_functions_ref.POST_GE_append, {}, {})

## Sets membrane potential monitoring
func POST_MON_neuron_membranePotential(cortical_ID: StringName, state: bool):
	var boolean: StringName = FEAGIUtils.bool_2_string(state)
	var passthrough: Dictionary = {
		"ID": cortical_ID,
		"state": state
	}
	_interface_ref.single_FEAGI_request(_address_list.POST_monitoring_neuron_membranePotential+cortical_ID+"&state="+boolean, HTTPClient.Method.METHOD_POST, _response_functions_ref.POST_MON_neuron_membranePotential, {}, passthrough) 

## Sets membrane synaptic monitoring
func POST_MON_neuron_synapticPotential(cortical_ID: StringName, state: bool):
	var boolean: StringName = FEAGIUtils.bool_2_string(state)
	var passthrough: Dictionary = {
		"ID": cortical_ID,
		"state": state
	}
	_interface_ref.single_FEAGI_request(_address_list.POST_monitoring_neuron_synapticPotential+cortical_ID+"&state="+boolean, HTTPClient.Method.METHOD_POST, _response_functions_ref.POST_MON_neuron_synapticPotential, {}, passthrough) 







## Sets the properties of a specific cortical area
## Due to the numerous combinations possible, you must format the dictionary itself to the keys expected
## Only the keys being changed should be input, no need to pull everything
func PUT_GE_corticalArea(cortical_ID: StringName, data_to_set: Dictionary):
	data_to_set["cortical_id"] = str(cortical_ID)
	# Passthrough the corticalID so we know what cortical area was updated
	_interface_ref.single_FEAGI_request(_address_list.PUT_genome_corticalArea, HTTPClient.Method.METHOD_PUT, _response_functions_ref.PUT_GE_corticalArea, data_to_set, cortical_ID) 
	

func PUT_GE_morphology(morphology_name: StringName, morphology_type: Morphology.MORPHOLOGY_TYPE, parameters: Dictionary) -> void:
	var to_buffer: Dictionary = parameters.duplicate()
	to_buffer["type"] = morphology_type
	to_buffer["morphology_name"] = morphology_name
	# passthrough morphology name so we know what was updated
	_interface_ref.single_FEAGI_request(_address_list.PUT_genome_morphology+morphology_name+"&morphology_type="+Morphology.MORPHOLOGY_TYPE.find_key(morphology_type).to_lower(), HTTPClient.Method.METHOD_PUT, _response_functions_ref.PUT_GE_morphology, to_buffer, morphology_name)

## modifies the mapping properties between 2 cortical areas. The input array must be already formatted for FEAGI
func PUT_GE_mappingProperties(source_cortical: CorticalArea, destination_cortical: CorticalArea, mapping_data: Array):
	_interface_ref.single_FEAGI_request(_address_list.PUT_genome_mappingProperties + "?src_cortical_area=" + source_cortical.cortical_ID + "&dst_cortical_area=" + destination_cortical.cortical_ID,
	HTTPClient.Method.METHOD_PUT,  _response_functions_ref.PUT_GE_mappingProperties, mapping_data, {"src": source_cortical, "dst": destination_cortical, "count": mapping_data.size()})

## TODO clean up this
func PUT_GE_mappingProperties_DEFUNCT(dataIn, extra_name := ""): ## We should rename these variables
	_interface_ref.single_FEAGI_request(_address_list.PUT_genome_mappingProperties + extra_name, HTTPClient.Method.METHOD_PUT, _response_functions_ref.PUT_GE_mappingProperties, dataIn)


 ## deletes cortical area
func DELETE_GE_corticalArea(corticalID: StringName):
	_interface_ref.single_FEAGI_request(_address_list.DELETE_GE_corticalArea + corticalID, HTTPClient.Method.METHOD_DELETE, _response_functions_ref.DELETE_GE_corticalArea, null, corticalID) # pass through cortical ID to know what we deleted

## Deletes a morphology
func DELETE_GE_morphology(morphology_name: StringName):
	_interface_ref.single_FEAGI_request(_address_list.DELETE_GE_morphology + morphology_name, HTTPClient.Method.METHOD_DELETE, _response_functions_ref.DELETE_GE_morphology, null, morphology_name) # pass through morphology name to know what we deleted
