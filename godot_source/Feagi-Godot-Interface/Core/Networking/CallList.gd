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

#region GET requests
## Get current IPU list
func GET_FE_pns_current_ipu():
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(
		_address_list.GET_corticalAreas_ipu,
		_response_functions_ref.GET_FE_pns_current_ipu
	)
	_interface_ref.FEAGI_API_Request(request)

## Get current OPU list
func GET_FE_pns_current_opu():
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(
		_address_list.GET_corticalAreas_opu,
		_response_functions_ref.GET_FE_pns_current_opu
	)
	_interface_ref.FEAGI_API_Request(request)

## Get Cortical Area ID lists
func GET_GE_corticalAreaIDList():
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(
		_address_list.GET_corticalAreas_corticalAreaIDList,
		_response_functions_ref.GET_GE_corticalAreaIDList
	)
	_interface_ref.FEAGI_API_Request(request)


## Get list of morphologies
func GET_GE_morphologyList():
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(
		_address_list.GET_neuronMorphologies_morphologyList,
		_response_functions_ref.GET_GE_morphologyList
	)
	_interface_ref.FEAGI_API_Request(request)

## Get genome filename
func GET_GE_fileName():
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(
		_address_list.GET_genome_fileName,
		_response_functions_ref.GET_GE_fileName
	)
	_interface_ref.FEAGI_API_Request(request)

## return dict of cortical IDs mapped with dict of connected cortical area and number of mappings
func GET_GE_corticalMap_detailed():
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(
		_address_list.GET_corticalArea_corticalMapDetailed,
		_response_functions_ref.GET_GE_corticalMap_detailed
	)
	_interface_ref.FEAGI_API_Request(request)

## return dict of cortical IDs mapped with list of connected cortical areas
func GET_CO_properties_mappings():
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(
		_address_list.GET_connectome_properties_mappings,
		_response_functions_ref.GET_CO_properties_mappings
	)
	_interface_ref.FEAGI_API_Request(request)

## return list of cortical area names
func GET_GE_corticalAreaNameList():
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(
		_address_list.GET_corticalAreas_corticalAreaNameList,
		_response_functions_ref.GET_GE_corticalAreaNameList
	)
	_interface_ref.FEAGI_API_Request(request)

## by cortical name, returns 3D coordinates of the cortical area
func GET_GE_corticalNameLocation(corticalName: String):
	var to_send: Dictionary = {
		"cortical_name": corticalName
	}
	
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_call(
		_address_list.POST_corticalAreas_corticalNameLocation,
		HTTPClient.METHOD_POST,
		to_send,
		{},
		_response_functions_ref.GET_GE_corticalNameLocation
	)
	_interface_ref.FEAGI_API_Request(request)

## By corticalID, returns dictionary of all cortical area details
func GET_GE_corticalArea(corticalID: StringName):
	var to_send: Dictionary = {
		"cortical_id": corticalID
	}
	
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_call(
		_address_list.POST_corticalArea_corticalAreaProperties,
		HTTPClient.METHOD_POST,
		to_send,
		{},
		_response_functions_ref.GET_GE_corticalArea
	)
	_interface_ref.FEAGI_API_Request(request)

## By corticalID, returns dictionary of all cortical area details, but keeps polling until the cortical area is no longer transforming
func GET_GE_corticalArea_POLL(corticalID: StringName):
	var to_send: Dictionary = {
		"cortical_id": corticalID
	}
	var searching_for: PollingMethodDictionaryValue = PollingMethodDictionaryValue.new("transforming", false)

	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_polling_call(
		_address_list.POST_corticalArea_corticalAreaProperties,
		HTTPClient.Method.METHOD_POST,
		to_send,
		null,
		_response_functions_ref.GET_GE_corticalArea,
		0.2,
		searching_for
	)
	_interface_ref.FEAGI_API_Request(request)
	
	

## returns dict of cortical names, mapped to an array of positions, unknown boolean, size, and ID
func GET_CO_properties_dimensions():
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(
		_address_list.GET_connectome_properties_dimensions,
		_response_functions_ref.GET_CO_properties_dimensions
	)
	_interface_ref.FEAGI_API_Request(request)

## returns pause between bursts in seconds
func GET_BU_stimulationPeriod():
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(
		_address_list.GET_burstEngine_stimulationPeriod,
		_response_functions_ref.GET_BU_stimulationPeriod
	)
	_interface_ref.FEAGI_API_Request(request)

## returns dict of cortical IDs mapped to their names
func GET_GE_corticalIDNameMapping():
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(
		_address_list.GET_corticalArea_corticalIDNameMapping,
		_response_functions_ref.GET_GE_corticalIDNameMapping
	)
	_interface_ref.FEAGI_API_Request(request)

## returns list of connected cortical IDs upsteam given ID
func GET_GE_corticalMappings_afferents_corticalArea(corticalID: StringName):
	var to_send: Dictionary = {
		"cortical_id": corticalID
	}
	
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_call(
		_address_list.POST_corticalMappings_afferents,
		HTTPClient.METHOD_POST,
		to_send,
		{},
		_response_functions_ref.GET_GE_corticalMappings_afferents_corticalArea
	)
	_interface_ref.FEAGI_API_Request(request)

## returns list of connected cortical IDs downstream given ID
func GET_GE_corticalMappings_efferents_corticalArea(corticalID: StringName):
	var to_send: Dictionary = {
		"cortical_id": corticalID
	}
	
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_call(
		_address_list.POST_corticalMappings_efferents,
		HTTPClient.METHOD_POST,
		to_send,
		{},
		_response_functions_ref.GET_GE_corticalMappings_efferents_corticalArea
	)
	_interface_ref.FEAGI_API_Request(request)
	
## given name of morphology, returns dict of morphlogy details
func GET_GE_morphology(morphologyName: String):
	var to_send: Dictionary = {
		"morphology_name": morphologyName
	}
	
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_call(
		_address_list.POST_morphology_morphologyProperties,
		HTTPClient.METHOD_POST,
		to_send,
		{},
		_response_functions_ref.GET_GE_morphology
	)
	_interface_ref.FEAGI_API_Request(request)

## given morphology name, returns an array of arrays of source to destination cortical IDs where said morphology is used
func GET_GE_morphologyUsage(morphologyName: String):

	var to_send: Dictionary = {
		"morphology_name": morphologyName
	}
	
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_call(
		_address_list.POST_morphology_morphologyUsage,
		HTTPClient.METHOD_POST,
		to_send,
		morphologyName,
		_response_functions_ref.GET_GE_morphologyUsage
	)
	_interface_ref.FEAGI_API_Request(request)
	

## returns an array of dicts of morphology details of morphologies used between 2 cortical areas
func GET_GE_mappingProperties(sourceCorticalID: StringName, destinationCorticalID: StringName):
	# Pass through the source and destination cortical areas
	var to_send: Dictionary = {
		"src_cortical_area": sourceCorticalID,
		"dst_cortical_area": destinationCorticalID
	}
	
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_call(
		_address_list.POST_corticalMappings_mappingProperties,
		HTTPClient.METHOD_POST,
		to_send,
		[sourceCorticalID, destinationCorticalID],
		_response_functions_ref.GET_GE_mappingProperties
	)
	_interface_ref.FEAGI_API_Request(request)
	
## returns a string array of circuit file names found in feagi
func GET_GE_circuits():
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(
		_address_list.GET_genome_circuits,
		_response_functions_ref.GET_GE_circuits
	)
	_interface_ref.FEAGI_API_Request(request)

## returns a dictionary of the properties of the given circuit
func GET_GE_circuitDescription(circuit_file_name: String):
	## Pass Through circuit name so we know what circuit we are referring to at the response side
	#TODO catch any uses and delete! Defunct!
	print("Circuit Description Deprecated!")
	pass

## returns dict by cortical ID of int arrays of 2D location of cortical area (array will be null null if no location is saved in FEAGI)
func GET_GE_CorticalLocations2D():
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(
		_address_list.GET_corticalArea_corticalLocations2D,
		_response_functions_ref.GET_GE_CorticalLocations2D
	)
	_interface_ref.FEAGI_API_Request(request)

## returns dict by cortical ID of cortical name, type, visibility, 2d and 3d positions, and dimensions
func GET_GE_CorticalArea_geometry():
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(
		_address_list.GET_corticalArea_corticalArea_geometry,
		_response_functions_ref.GET_GE_CorticalArea_geometry
	)
	_interface_ref.FEAGI_API_Request(request)

## returns dict by cortical type of different cortical templates for non-custom cortical areas
func GET_GE_corticalTypes():
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(
		_address_list.GET_corticalArea_corticalTypes,
		_response_functions_ref.GET_GE_corticalTypes
	)
	_interface_ref.FEAGI_API_Request(request)

## returns bool of if a cortical area is monitoring membrane potential
func GET_MO_neuron_membranePotential(corticalID: StringName):
	var to_send: Dictionary = {
		"cortical_id": corticalID
	}
	
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_call(
		_address_list.POST_insight_neurons_membranePotentialStatus,
		HTTPClient.METHOD_POST,
		to_send,
		corticalID,
		_response_functions_ref.GET_MON_neuron_membranePotential
	)
	_interface_ref.FEAGI_API_Request(request)
	
## returns bool of if a cortical area is monitoring synaptic potential
func GET_MO_neuron_synapticPotential(corticalID: StringName):
	var to_send: Dictionary = {
		"cortical_id": corticalID
	}
	
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_call(
		_address_list.POST_insight_neuron_synapticPotentialStatus,
		HTTPClient.METHOD_POST,
		to_send,
		corticalID,
		_response_functions_ref.GET_MON_neuron_synapticPotential
	)
	_interface_ref.FEAGI_API_Request(request)

## returns dict of various feagi health stats as booleans
func GET_healthCheck():
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(
		_address_list.GET_healthCheck,
		_response_functions_ref.GET_healthCheck
	)
	_interface_ref.FEAGI_API_Request(request)

## returns dict of various feagi health stats as booleans
func GET_healthCheck_POLL_GENOME():
	var searching_for: PollingMethodDictionaryValue = PollingMethodDictionaryValue.new("genome_availability", true)
	const SECONDS_BETWEEN_POLLS: float = 0.5
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_polling_call(
		_address_list.GET_system_healthCheck,
		HTTPClient.Method.METHOD_GET,
		{},
		{},
		_response_functions_ref.GET_healthCheck_POLL_genome_availability,
		SECONDS_BETWEEN_POLLS,
		searching_for
	)
	_interface_ref.FEAGI_API_Request(request)

## returns dict of various feagi health stats as booleans
func GET_healthCheck_POLL_MONITORING():
	const SECONDS_BETWEEN_POLLS: float = 5.0
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_polling_call(
		_address_list.GET_system_healthCheck,
		HTTPClient.Method.METHOD_GET,
		{},
		{},
		_response_functions_ref.GET_healthCheck_POLL_health,
		SECONDS_BETWEEN_POLLS,
	)
	_interface_ref.FEAGI_API_Request(request)

## returns dict by corticalID, with name, type, and 2d position
func GET_CO_corticalAreas_list_detailed():
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(
		_address_list.GET_connectome_corticalAreas_list_detailed,
		_response_functions_ref.GET_CO_corticalAreas_list_detailed
	)
	_interface_ref.FEAGI_API_Request(request)
	_interface_ref.single_FEAGI_request(_address_list.GET_connectome_corticalAreas_list_detailed, HTTPClient.Method.METHOD_GET, _response_functions_ref.GET_CO_corticalAreas_list_detailed)

## returns dict of morphology names keyd to their type string
func GET_MO_list_types():
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(
		_address_list.GET_morphology_list_types,
		_response_functions_ref.GET_MO_list_types
	)
	_interface_ref.FEAGI_API_Request(request)

## Returns membrane potential monitoring state of a cortical area
func GET_MON_neuron_membranePotential(cortical_ID: StringName) -> void:
	var to_send: Dictionary = {
		"cortical_id": cortical_ID
	}
	
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_call(
		_address_list.POST_insight_neurons_membranePotentialStatus,
		HTTPClient.METHOD_POST,
		to_send,
		{},
		_response_functions_ref.GET_MON_neuron_membranePotential
	)
	_interface_ref.FEAGI_API_Request(request)

## Returns synaptic potential monitoring state of a cortical area
func GET_MON_neuron_synapticPotential(cortical_ID: StringName) -> void:
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_call(
		_address_list.POST_insight_neuron_synapticPotentialStatus,
		HTTPClient.METHOD_GET,
		null,
		cortical_ID,
		_response_functions_ref.GET_MON_neuron_synapticPotential
	)
	_interface_ref.FEAGI_API_Request(request)

## returns a list of IDs (not cortical loaded) of areas for initing IPUs
func GET_PNS_current_ipu() -> void:
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(
		_address_list.GET_pns_current_ipu,
		_response_functions_ref.GET_PNS_current_ipu
	)
	_interface_ref.FEAGI_API_Request(request)

## returns a list of IDs (not cortical loaded) of areas for initing OPUs
func GET_PNS_current_opu() -> void:
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(
		_address_list.GET_pns_current_opu,
		_response_functions_ref.GET_PNS_current_opu
	)
	_interface_ref.FEAGI_API_Request(request)
#endregion

#region POST requests
## sets delay between bursts in seconds
func POST_FE_burstEngine(newBurstRate: float):
	_interface_ref.single_FEAGI_request(_address_list.POST_feagi_burstEngine, HTTPClient.Method.METHOD_POST, _response_functions_ref.POST_FE_burstEngine, {"burst_duration": newBurstRate})

## Adds a non-custom cortical area with non-definable dimensions
func POST_GE_corticalArea(template_cortical_ID: StringName, type: BaseCorticalArea.CORTICAL_AREA_TYPE, coordinates_3D: Vector3i, 
	is_coordinate_2D_defined: bool, channel_count: int = 0, coordinates_2D: Vector2i = Vector2(0,0)) -> void:

	var to_send: Dictionary = {
		"cortical_id": template_cortical_ID,
		"coordinates_3d": FEAGIUtils.vector3i_to_array(coordinates_3D),
		"cortical_type": BaseCorticalArea.cortical_type_to_str(type),
		"channel_count": channel_count
	}

	var to_buffer: Dictionary = {
		"template_cortical_ID": template_cortical_ID,
		"coordinates_3d": coordinates_3D,
		"channel_count": channel_count,
		"cortical_type": type,
	}

	if is_coordinate_2D_defined:
		to_send["coordinates_2d"] = FEAGIUtils.vector2i_to_array(coordinates_2D)
		to_buffer["coordinates_2d"] = coordinates_2D
	else:
		to_send["coordinates_2d"] = [null,null]


	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_call(
		_address_list.POST_genome_corticalArea,
		HTTPClient.METHOD_POST,
		to_send,
		to_buffer,
		_response_functions_ref.POST_GE_corticalArea
	)
	_interface_ref.FEAGI_API_Request(request)


## Adds cortical area (custom or memory) (with definable dimensions)
## If copying a cortical ID, dimensions should be the same as the source dimensions
func POST_GE_customCorticalArea(name: StringName, coordinates_3D: Vector3i, dimensions: Vector3i, 
	is_coordinate_2D_defined: bool, coordinates_2D: Vector2i = Vector2(0,0), memory_type: bool = false, cortical_ID_to_copy: StringName = "") -> void:

	var to_send: Dictionary = {
		"cortical_name": str(name),
		"coordinates_3d": FEAGIUtils.vector3i_to_array(coordinates_3D),
		"cortical_dimensions": FEAGIUtils.vector3i_to_array(dimensions),
		"cortical_group": BaseCorticalArea.cortical_type_to_str(BaseCorticalArea.CORTICAL_AREA_TYPE.CUSTOM)
	}

	var to_buffer: Dictionary = {
		"cortical_name": name,
		"coordinates_3d": FEAGIUtils.vector3i_to_array(coordinates_3D),
		"cortical_dimensions": FEAGIUtils.vector3i_to_array(dimensions),
		"cortical_group": BaseCorticalArea.cortical_type_to_str(BaseCorticalArea.CORTICAL_AREA_TYPE.CUSTOM),
		"cortical_sub_group": ""
	}

	if is_coordinate_2D_defined:
		to_send["coordinates_2d"] = FEAGIUtils.vector2i_to_array(coordinates_2D)
		to_buffer["coordinates_2d"] = FEAGIUtils.vector2i_to_array(coordinates_2D)
	else:
		to_send["coordinates_2d"] = [null,null]
	
	if memory_type:
		to_send["sub_group_id"] = "MEMORY"
		to_buffer["cortical_group"] = BaseCorticalArea.cortical_type_to_str(BaseCorticalArea.CORTICAL_AREA_TYPE.MEMORY)
	
	if cortical_ID_to_copy != "":
		to_send["copy_of"] = cortical_ID_to_copy
		#to_send.erase("cortical_dimensions")
	
	# Passthrough properties so we have them to build cortical area
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_call(
		_address_list.POST_genome_customCorticalArea,
		HTTPClient.METHOD_POST,
		to_send,
		to_buffer,
		_response_functions_ref.POST_GE_customCorticalArea
	)
	_interface_ref.FEAGI_API_Request(request)

## Adds a morphology
func POST_GE_morphology(morphology_name: StringName, morphology_type: Morphology.MORPHOLOGY_TYPE, parameters: Dictionary) -> void:
	var to_buffer: Dictionary = parameters.duplicate()
	to_buffer["type"] = morphology_type
	to_buffer["morphology_name"] = morphology_name
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_call(
		_address_list.POST_genome_customCorticalArea,
		HTTPClient.METHOD_POST,
		parameters,
		to_buffer,
		_response_functions_ref.POST_GE_customCorticalArea
	)
	_interface_ref.FEAGI_API_Request(request)

## adds a circuit
func POST_GE_append(circuit_file_name: StringName, position: Vector3i) -> void:
	var address: StringName = _address_list.POST_genome_append
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_call(
		address,
		HTTPClient.METHOD_POST,
		{},
		{},
		_response_functions_ref.POST_GE_append
	)
	_interface_ref.FEAGI_API_Request(request)

## Sets membrane potential monitoring
func POST_MON_neuron_membranePotential(cortical_ID: StringName, state: bool):
	var boolean: StringName = FEAGIUtils.bool_2_string(state)
	var passthrough: Dictionary = {
		"ID": cortical_ID,
		"state": state
	}
	
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_call(
		_address_list.POST_monitoring_neuron_membranePotential_set,
		HTTPClient.METHOD_POST,
		{},
		passthrough,
		_response_functions_ref.POST_MON_neuron_membranePotential
	)
	_interface_ref.FEAGI_API_Request(request)


## Sets membrane synaptic monitoring
func POST_MON_neuron_synapticPotential(cortical_ID: StringName, state: bool):
	var boolean: StringName = FEAGIUtils.bool_2_string(state)
	var passthrough: Dictionary = {
		"ID": cortical_ID,
		"state": state
	}
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_call(
		_address_list.POST_monitoring_neuron_synapticPotential_set,
		HTTPClient.METHOD_POST,
		{},
		passthrough,
		_response_functions_ref.POST_MON_neuron_synapticPotential
	)
	_interface_ref.FEAGI_API_Request(request)

func POST_GE_amalgamationDestination(circuit_position: Vector3i, amalgamation_ID: StringName, _irrelevant: Variant) -> void:
	var address: StringName = _address_list.POST_genome_amalgamationDestination
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_call(
		address,
		HTTPClient.METHOD_POST,
		{},
		{},
		_response_functions_ref.POST_GE_amalgamationDestination
	)
	_interface_ref.FEAGI_API_Request(request)
#endregion

#region PUT requests
## Sets the properties of a specific cortical area
## Due to the numerous combinations possible, you must format the dictionary itself to the keys expected
## Only the keys being changed should be input, no need to pull everything
func PUT_GE_corticalArea(cortical_ID: StringName, data_to_set: Dictionary):
	data_to_set["cortical_id"] = str(cortical_ID)
	# Passthrough the corticalID so we know what cortical area was updated
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_call(
		_address_list.PUT_genome_corticalArea,
		HTTPClient.METHOD_PUT,
		data_to_set,
		cortical_ID,
		_response_functions_ref.PUT_GE_corticalArea
	)
	_interface_ref.FEAGI_API_Request(request)

func PUT_GE_morphology(morphology_name: StringName, morphology_type: Morphology.MORPHOLOGY_TYPE, parameters: Dictionary) -> void:
	var to_send: Dictionary = {
		"morphology_name": morphology_name,
		"morphology_type": Morphology.morphology_type_to_string(morphology_type),
		"morphology_parameters": parameters.duplicate()
	}

	# passthrough morphology name so we know what was updated
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_call(
		_address_list.PUT_genome_morphology,
		HTTPClient.METHOD_PUT,
		to_send,
		morphology_name,
		_response_functions_ref.PUT_GE_morphology
	)
	_interface_ref.FEAGI_API_Request(request)

## modifies the mapping properties between 2 cortical areas. The input array must be already formatted for FEAGI
func PUT_GE_mappingProperties(source_cortical: BaseCorticalArea, destination_cortical: BaseCorticalArea, mapping_data: Array):
	var to_buffer: Dictionary = {
		"src": source_cortical, 
		"dst": destination_cortical, 
		"mapping_data_raw": mapping_data
	}
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_call(
		_address_list.PUT_genome_mappingProperties,
		HTTPClient.METHOD_PUT,
		mapping_data,
		to_buffer,
		_response_functions_ref.PUT_GE_mappingProperties
	)
	_interface_ref.FEAGI_API_Request(request)

## Modifies the 2D location of many cortical areas at once without the need for polling
func PUT_GE_coord2D(cortical_IDs_mapped_to_vector2is: Dictionary):
	var to_send: Dictionary = {}
	for key in cortical_IDs_mapped_to_vector2is.keys():
		to_send[key] = FEAGIUtils.vector2i_to_array(cortical_IDs_mapped_to_vector2is[key])
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_call(
		_address_list.PUT_genome_coord2d,
		HTTPClient.METHOD_PUT,
		to_send,
		cortical_IDs_mapped_to_vector2is,
		_response_functions_ref.PUT_GE_coord2D
	)
	_interface_ref.FEAGI_API_Request(request)
#endregion

#region DELETE requests
 ## deletes cortical area
func DELETE_GE_corticalArea(corticalID: StringName):
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_call(
		_address_list.DELETE_GE_corticalArea,
		HTTPClient.METHOD_DELETE,
		{},
		corticalID, # buffer this so we know what we deleted
		_response_functions_ref.DELETE_GE_corticalArea
	)
	_interface_ref.FEAGI_API_Request(request)

## Deletes a morphology
func DELETE_GE_morphology(morphology_name: StringName):
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_call(
		_address_list.DELETE_GE_morphology,
		HTTPClient.METHOD_DELETE,
		{},
		morphology_name, # buffer this so we know what we deleted
		_response_functions_ref.DELETE_GE_morphology
	)
	_interface_ref.FEAGI_API_Request(request)

func DELETE_GE_amalgamationCancelation(amalgamation_ID: StringName) -> void:
	var address: StringName = _address_list.DELETE_GE_amalgamationCancellation
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_call(
		address,
		HTTPClient.METHOD_DELETE,
		{},
		{},
		_response_functions_ref.DELETE_GE_amalgamationCancelation
	)
	_interface_ref.FEAGI_API_Request(request)

#endregion
