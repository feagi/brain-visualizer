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
	_interface_ref.FEAGI_GET(_address_list.GET_feagi_pns_current_ipu, _response_functions_ref.GET_FE_pns_current_ipu)

## Get current OPU list
func GET_FE_pns_current_opu():
	_interface_ref.FEAGI_GET(_address_list.GET_feagi_pns_current_opu, _response_functions_ref.GET_FE_pns_current_opu)

## Get Cortical Area ID lists
func GET_GE_corticalAreaIDList():
	_interface_ref.FEAGI_GET(_address_list.GET_genome_corticalAreaIDList, _response_functions_ref.GET_GE_corticalAreaIDList)

## Get list of morphologies
func GET_GE_morphologyList():
	_interface_ref.FEAGI_GET(_address_list.GET_genome_morphologyList, _response_functions_ref.GET_GE_morphologyList)

## Get genome filename
func GET_GE_fileName():
	_interface_ref.FEAGI_GET(_address_list.GET_genome_fileName, _response_functions_ref.GET_GE_fileName)

## return dict of cortical IDs mapped with dict of connected cortical area and number of mappings
func GET_GE_corticalMap():
	_interface_ref.FEAGI_GET(_address_list.GET_genome_corticalMap, _response_functions_ref.GET_GE_corticalMap)

## return dict of cortical IDs mapped with list of connected cortical areas
func GET_CO_properties_mappings():
	_interface_ref.FEAGI_GET(_address_list.GET_connectome_properties_mappings, _response_functions_ref.GET_CO_properties_mappings)

## return list of cortical area names
func GET_GE_corticalAreaNameList():
	_interface_ref.FEAGI_GET(_address_list.GET_genome_corticalAreaNameList, _response_functions_ref.GET_GE_corticalAreaNameList)

## by cortical name, returns 3D coordinates of the cortical area
func GET_GE_corticalNameLocation(corticalName: String):
	_interface_ref.FEAGI_GET(_address_list.GET_genome_corticalNameLocation+corticalName, _response_functions_ref.GET_GE_corticalNameLocation)

## By corticalID, returns dictionary of all cortical area details
func GET_GE_corticalArea(corticalID: StringName):
	_interface_ref.FEAGI_GET(_address_list.GET_genome_corticalArea + corticalID, _response_functions_ref.GET_GE_corticalArea)

## returns dict of cortical names, mapped to an array of positions, unknown boolean, size, and ID
func GET_CO_properties_dimensions():
	_interface_ref.FEAGI_GET(_address_list.GET_connectome_properties_dimensions, _response_functions_ref.GET_CO_properties_dimensions)

## returns pause between bursts in seconds
func GET_BU_stimulationPeriod():
	_interface_ref.FEAGI_GET(_address_list.GET_burstEngine_stimulationPeriod, _response_functions_ref.GET_BU_stimulationPeriod)

## returns dict of cortical IDs mapped to their names
func GET_GE_corticalIDNameMapping():
	_interface_ref.FEAGI_GET(_address_list.GET_genome_corticalIDNameMapping, _response_functions_ref.GET_GE_corticalIDNameMapping)

## returns list of connected cortical IDs upsteam given ID
func GET_GE_corticalMappings_afferents_corticalArea(corticalID: StringName):
	_interface_ref.FEAGI_GET(_address_list.GET_genome_corticalMappings_afferents_corticalArea_CORTICALAREAEQUALS+corticalID, _response_functions_ref.GET_GE_corticalMappings_afferents_corticalArea)

## returns list of connected cortical IDs downstream given ID
func GET_GE_corticalMappings_efferents_corticalArea(corticalID: StringName):
	_interface_ref.FEAGI_GET(_address_list.GET_genome_corticalMappings_efferents_corticalArea_CORTICALAREAEQUALS+corticalID, _response_functions_ref.GET_GE_corticalMappings_efferents_corticalArea)

## given name of morphology, returns dict of morphlogy details
func GET_GE_morphology(morphologyName: String):
	_interface_ref.FEAGI_GET(_address_list.GET_genome_morphologyNameEQUALS+morphologyName, _response_functions_ref.GET_GE_morphology)

## given morphology name, returns an array of arrays of source to destination cortical IDs where said morphology is used
func GET_GE_morphologyUsage(morphologyName: String):
	_interface_ref.FEAGI_GET(_address_list.GET_genome_morphologyUsage_MORPHOLOGYNAMEEQUALS+morphologyName, _response_functions_ref.GET_GE_morphologyUsage)

## returns an array of dicts of morphology details of morphologies used between 2 cortical areas
func GET_GE_mappingProperties(sourceCorticalID: StringName, destinationCorticalID: StringName):
	# Pass through the source and destination cortical areas
	_interface_ref.FEAGI_GET(_address_list.GET_genome_mappingProperties_CORTICALAREAEQUALS+sourceCorticalID+"&dst_cortical_area="+destinationCorticalID, _response_functions_ref.GET_GE_mappingProperties, [sourceCorticalID, destinationCorticalID])

## returns a string array of circuit file names found in feagi
func GET_GE_circuits():
	_interface_ref.FEAGI_GET(_address_list.GET_genome_circuits, _response_functions_ref.GET_GE_circuits)

## returns int array of given circuit name (.json included)
func GET_GE_circuitsize(circuit_name: String):
	## Pass Through circuit name so we know what circuit we are referring to at the response side
	_interface_ref.FEAGI_GET(_address_list.GET_genome_circuitsize+circuit_name, _response_functions_ref.GET_GE_circuitsize, circuit_name)

## returns dict by cortical ID of int arrays of 2D location of cortical area (array will be null null if no location is saved in FEAGI)
func GET_GE_CorticalLocations2D():
	_interface_ref.FEAGI_GET(_address_list.GET_genome_corticalLocations2D , _response_functions_ref.GET_GE_CorticalLocations2D)

## returns dict by cortical ID of cortical name, type, visibility, 2d and 3d positions, and dimensions
func GET_GE_CorticalArea_geometry():
	_interface_ref.FEAGI_GET(_address_list.GET_genome_corticalArea_geometry , _response_functions_ref.GET_GE_CorticalArea_geometry)


func GET_MO_neuron_membranePotential(corticalID: StringName):
	_interface_ref.FEAGI_GET(_address_list.GET_monitoring_neuron_membranePotential+corticalID, _response_functions_ref.GET_MO_neuron_membranePotential)


func GET_MO_neuron_synapticPotential(corticalID: StringName):
	_interface_ref.FEAGI_GET(_address_list.GET_monitoring_neuron_synapticPotential+corticalID, _response_functions_ref.GET_MO_neuron_synapticPotential)


func GET_GE_corticalTypeOptions(corticalType: String):
	_interface_ref.FEAGI_GET(_address_list.GET_genome_corticalTypeOptions_CORTICALTYPEQUALS+corticalType, _response_functions_ref.GET_GE_corticalTypeOptions)

## returns dict of various feagi health stats as booleans
func GET_healthCheck():
	_interface_ref.FEAGI_GET(_address_list.GET_healthCheck, _response_functions_ref.GET_healthCheck)

## returns dict by corticalID, with name, type, and 2d position
func GET_CO_corticalAreas_list_detailed():
	_interface_ref.FEAGI_GET(_address_list.GET_connectome_corticalAreas_list_detailed, _response_functions_ref.GET_CO_corticalAreas_list_detailed)

## returns dict of morphology names keyd to their type string
func GET_MO_list_types(): # USED 1x
	_interface_ref.FEAGI_GET(_address_list.GET_morphologies_list_types, _response_functions_ref.GET_MO_list_types)

## sets delay between bursts in seconds
func POST_FE_burstEngine(newBurstRate: float):
	_interface_ref.FEAGI_POST(_address_list.POST_feagi_burstEngine, _response_functions_ref.POST_FE_burstEngine, {"burst_duration": newBurstRate})

 ## Adds cortical area (Dimensions however are autocalculated)
func POST_GE_corticalArea(corticalProperties: Dictionary):
	_interface_ref.FEAGI_POST(_address_list.POST_genome_corticalArea, _response_functions_ref.POST_GE_corticalArea, corticalProperties)

## Adds cortical area (with definable dimensions)
func POST_GE_customCorticalArea(name: StringName, coordinates_3D: Vector3i, dimensions: Vector3i, 
	is_coordinate_2D_defined: bool, coordinates_2D: Vector2i = Vector2(0,0), 
	cortical_type: CorticalArea.CORTICAL_AREA_TYPE = CorticalArea.CORTICAL_AREA_TYPE.CUSTOM) -> void:

	var to_send: Dictionary = {
		"cortical_name": str(name),
		"coordinates_3d": FEAGIUtils.vector3i_to_array(coordinates_3D),
		"cortical_dimensions": FEAGIUtils.vector3i_to_array(dimensions),
		"cortical_type": str(cortical_type)
	}
	if is_coordinate_2D_defined:
		to_send["coordinates_2d"] = FEAGIUtils.vector2i_to_array(coordinates_2D)
	else:
		to_send["coordinates_2d"] = [null,null]
	
	var to_buffer: Dictionary = {
		"cortical_name": name,
		"coordinates_3d": coordinates_3D,
		"cortical_dimensions": dimensions,
		"cortical_type": cortical_type
	}
	if is_coordinate_2D_defined:
		to_send["coordinates_2d"] = coordinates_2D
	
	# Passthrough properties so we have them to build cortical area
	_interface_ref.FEAGI_POST(_address_list.POST_genome_customCorticalArea, _response_functions_ref.POST_GE_customCorticalArea, to_send, to_buffer) 

## Adds a morphology
func POST_GE_morphology(morphology_name: StringName, morphology_type: Morphology.MORPHOLOGY_TYPE, parameters: Dictionary) -> void:
	var to_buffer: Dictionary = parameters.duplicate()
	to_buffer["type"] = morphology_type
	to_buffer["morphology_name"] = morphology_name
	_interface_ref.FEAGI_POST(_address_list.POST_genome_morphology+morphology_name+"&morphology_type="+Morphology.MORPHOLOGY_TYPE.find_key(morphology_type).to_lower(), _response_functions_ref.POST_GE_morphology, parameters, to_buffer)

## Sets the properties of a specific cortical area
## Due to the numerous combinations possible, you must format the dictionary itself to the keys expected
## Only the keys being changed should be input, no need to pull everything
func PUT_GE_corticalArea(cortical_ID: StringName, data_to_set: Dictionary):
	data_to_set["cortical_id"] = str(cortical_ID)
	# Passthrough the corticalID so we know what cortical area was updated
	_interface_ref.FEAGI_PUT(_address_list.PUT_genome_corticalArea, _response_functions_ref.PUT_GE_corticalArea, data_to_set, cortical_ID) 
	pass

## TODO clean up this
func PUT_GE_mappingProperties(dataIn, extra_name := ""): ## We should rename these variables
	_interface_ref.FEAGI_PUT(_address_list.PUT_genome_mappingProperties + extra_name, _response_functions_ref.PUT_GE_mappingProperties, dataIn)
	
 ## deletes cortical area
func DELETE_GE_corticalArea(corticalID: StringName):
	_interface_ref.FEAGI_DELETE(_address_list.DELETE_GE_corticalArea + corticalID, _response_functions_ref.DELETE_GE_corticalArea, corticalID) # pass through cortical ID to know what we deleted


