extends Object
class_name CallList
## The specific calls made to FEAGI

var _address_list: AddressList
var _interface_ref: NetworkInterface
var _response_functions_ref: ResponseProxyFunctions

func _init(interface_reference: NetworkInterface, response_functions_reference: ResponseProxyFunctions):
    _interface_ref = interface_reference
    _response_functions_ref = response_functions_reference


func GET_FE_pns_current_ipu(): _interface_ref.FEAGI_GET(_address_list.GET_feagi_pns_current_ipu, _interface_ref._Relay_IPUs)
func GET_FE_pns_current_opu(): _interface_ref.FEAGI_GET(_address_list.GET_feagi_pns_current_opu, _interface_ref._Relay_OPUs)
func GET_GE_corticalAreaIDList(): _interface_ref.FEAGI_GET(_address_list.GET_genome_corticalAreaIDList, _interface_ref._Relay_CorticalAreasIDs)
func GET_GE_morphologyList(): _interface_ref.FEAGI_GET(_address_list.GET_genome_morphologyList, _interface_ref._Relay_MorphologyList)
func GET_GE_fileName(): _interface_ref.FEAGI_GET(_address_list.GET_genome_fileName, _interface_ref._Relay_GenomeFileName)
func GET_GE_corticalMap(): _interface_ref.FEAGI_GET(_address_list.GET_genome_corticalMap, _interface_ref._Relay_Genome_CorticalMappings)
func GET_CO_properties_mappings(): _interface_ref.FEAGI_GET(_address_list.GET_connectome_properties_mappings, _interface_ref._Relay_ConnectomeMappingReport)
func GET_GE_corticalAreaNameList(): _interface_ref.FEAGI_GET(_address_list.GET_genome_corticalAreaNameList, _interface_ref._Relay_CorticalAreaNameList)
func GET_GE_corticalNameLocation(corticalName: String): _interface_ref.FEAGI_GET(_address_list.GET_genome_corticalNameLocation+corticalName, _interface_ref._Relay_CorticalAreaLOCATION)
func GET_GE_corticalArea(corticalID: String): _interface_ref.FEAGI_GET(_address_list.GET_genome_corticalArea_CORTICALAREAEQUALS + corticalID, _interface_ref._Relay_GET_GE_corticalArea) 
func GET_CO_properties_dimensions(): _interface_ref.FEAGI_GET(_address_list.GET_connectome_properties_dimensions, _interface_ref._Relay_Dimensions)
func GET_BU_stimulationPeriod(): _interface_ref.FEAGI_GET(_address_list.GET_burstEngine_stimulationPeriod, _interface_ref._Relay_Get_BurstRate)
func GET_GE_corticalIDNameMapping(): _interface_ref.FEAGI_GET(_address_list.GET_genome_corticalIDNameMapping, _interface_ref._Relay_Cortical_grab_id)
func GET_GE_corticalMappings_afferents_corticalArea(corticalID: String): _interface_ref.FEAGI_GET(_address_list.GET_genome_corticalMappings_afferents_corticalArea_CORTICALAREAEQUALS+corticalID, _interface_ref._Relay_Afferent)
func GET_GE_corticalMappings_efferents_corticalArea(corticalID: String): _interface_ref.FEAGI_GET(_address_list.GET_genome_corticalMappings_efferents_corticalArea_CORTICALAREAEQUALS+corticalID, _interface_ref._Relay_Efferent)
func GET_GE_morphology(morphologyName: String): _interface_ref.FEAGI_GET(_address_list.GET_genome_morphologyNameEQUALS+morphologyName, _interface_ref._Relay_Morphology_information)
func GET_GE_morphologyUsage(morphologyName: String): _interface_ref.FEAGI_GET(_address_list.GET_genome_morphologyUsage_MORPHOLOGYNAMEEQUALS+morphologyName, _interface_ref._Relay_Morphology_usuage)
func GET_GE_mappingProperties(sourceCorticalID: String, destinationCorticalID: String): _interface_ref.FEAGI_GET(_address_list.GET_genome_mappingProperties_CORTICALAREAEQUALS+sourceCorticalID+"&dst_cortical_area="+destinationCorticalID, _interface_ref._Relay_Update_Destination)
func GET_GE_circuits(): _interface_ref.FEAGI_GET(_address_list.GET_genome_circuits, _interface_ref._Relay_circuit_list)
func GET_GE_circuitsize(circuitName: String): _interface_ref.FEAGI_GET(_address_list.GET_genome_circuitsize_CIRCUITNAMEEQUALS+circuitName, _interface_ref._Relay_circuit_size)
func GET_GE_CorticalLocations2D(): _interface_ref.FEAGI_GET(_address_list.GET_genome_corticalLocations2D , _interface_ref._Relay_CorticalAreaLocations2D)
func GET_MO_neuron_membranePotential(corticalID: String): _interface_ref.FEAGI_GET(_address_list.GET_monitoring_neuron_membranePotential+corticalID, _interface_ref._Relay_Update_mem)
func GET_MO_neuron_synapticPotential(corticalID: String): _interface_ref.FEAGI_GET(_address_list.GET_monitoring_neuron_synapticPotential+corticalID, _interface_ref._Relay_Update_syn)
func GET_GE_corticalTypeOptions(corticalType: String): _interface_ref.FEAGI_GET(_address_list.GET_genome_corticalTypeOptions_CORTICALTYPEQUALS+corticalType, _interface_ref._Relay_update_OPU)
func GET_healthCheck(): _interface_ref.FEAGI_GET(_address_list.GET_healthCheck, _interface_ref._Relay_Get_Health)
func GET_CO_corticalAreas_list_detailed(): _interface_ref.FEAGI_GET(_address_list.GET_connectome_corticalAreas_list_detailed, _interface_ref._Relay_ConnectomeCorticalAreasListDetailed)


func POST_FE_burstEngine(newBurstRate: float): _interface_ref.FEAGI_POST(_address_list.POST_feagi_burstEngine, _interface_ref._Relay_ChangedBurstRate, {"burst_duration": newBurstRate})
	
# Adds cortical area
func POST_GE_corticalArea(corticalProperties: Dictionary): _interface_ref.FEAGI_POST(_address_list.POST_genome_corticalArea, _interface_ref._Relay_updated_cortical, corticalProperties)
# Above and Below accomplish same thing, hence the same return function
func POST_GE_customCorticalArea(corticalProperties: Dictionary): _interface_ref.FEAGI_POST(_address_list.POST_genome_customCorticalArea, _interface_ref._Relay_updated_cortical, corticalProperties)
	

func PUT_GE_mappingProperties(dataIn, extra_name := ""): # We should rename these variables
    _interface_ref.FEAGI_PUT(_address_list.PUT_genome_mappingProperties + extra_name, _interface_ref._Relay_PUT_Mapping_Properties, dataIn)
	

func DELETE_GE_corticalArea(corticalID: String): 
    _interface_ref.FEAGI_DELETE(_address_list.DELETE_GE_corticalArea + corticalID, _interface_ref._Relay_DELETE_Cortical_area)


func PUT_GE_corticalArea(dataIn: Dictionary, corticalIDStr: String = ""):
    # TODO whats this?
    #if corticalIDStr == "": corticalIDStr = dataIn["cortical_id"]
    #_interface_ref.FEAGI_GET(_address_list.GET_genome_corticalArea_CORTICALAREAEQUALS + corticalIDStr, RELAYED_PUT_GE_CORTICALAREA)
    pass


func RELAYED_PUT_GE_CORTICALAREA(_result, _response_code, _headers, body: PackedByteArray):
    # TODO whats this>
    #var specificCortex: Dictionary = JSON.parse_string(body.get_string_from_utf8())
    #specificCortex.merge(TEMP, true)
    #_interface_ref.PUT(_address_list.PUT_genome_corticalArea, _interface_ref._Relay_PUT_GE_corticalArea, specificCortex)
    pass
