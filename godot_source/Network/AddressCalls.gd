extends Object
class_name AddressCalls
 # Handles Making Specific Calls to Feagis. Outputs are sent to relay functions in core


var FEAGIRootAddress: StringName:
	get: return _ADD._rootAddress
	set(v): _ADD._rootAddress = v

var FEAGISecurity: StringName:
	get: return _ADD._security
	set(v): _ADD._security = v

var _ADD: AddressList
var _CALL: NetworkCall
var _coreRef: Core


func _init(coreReference: Core, addressListRef: AddressList, networkCallRef: NetworkCall):
	_ADD = addressListRef
	_CALL = networkCallRef
	_coreRef = coreReference

func GET_FE_pns_current_ipu(): _CALL.GET(_ADD.GET_feagi_pns_current_ipu, _coreRef._Relay_IPUs)
func GET_FE_pns_current_opu(): _CALL.GET(_ADD.GET_feagi_pns_current_opu, _coreRef._Relay_OPUs)
func GET_GE_corticalAreaIDList(): _CALL.GET(_ADD.GET_genome_corticalAreaIDList, _coreRef._Relay_CorticalAreasIDs)
func GET_GE_morphologyList(): _CALL.GET(_ADD.GET_genome_morphologyList, _coreRef._Relay_MorphologyList)
func GET_GE_fileName(): _CALL.GET(_ADD.GET_genome_fileName, _coreRef._Relay_GenomeFileName)
func GET_GE_corticalMap(): _CALL.GET(_ADD.GET_genome_corticalMap, _coreRef._Relay_Genome_CorticalMappings)
func GET_CO_properties_mappings(): _CALL.GET(_ADD.GET_connectome_properties_mappings, _coreRef._Relay_ConnectomeMappingReport)
func GET_GE_corticalAreaNameList(): _CALL.GET(_ADD.GET_genome_corticalAreaNameList, _coreRef._Relay_CorticalAreaNameList)
func GET_GE_corticalNameLocation(corticalName: String): _CALL.GET(_ADD.GET_genome_corticalNameLocation+corticalName, _coreRef._Relay_CorticalAreaLOCATION)
func GET_GE_corticalArea(corticalID: String): _CALL.GET(_ADD.GET_genome_corticalArea_CORTICALAREAEQUALS + corticalID, _coreRef._Relay_GET_GE_corticalArea) 
func GET_CO_properties_dimensions(): _CALL.GET(_ADD.GET_connectome_properties_dimensions, _coreRef._Relay_Dimensions)
func GET_BU_stimulationPeriod(): _CALL.GET(_ADD.GET_burstEngine_stimulationPeriod, _coreRef._Relay_Get_BurstRate)
func GET_GE_corticalIDNameMapping(): _CALL.GET(_ADD.GET_genome_corticalIDNameMapping, _coreRef._Relay_Cortical_grab_id)
func GET_GE_corticalMappings_afferents_corticalArea(corticalArea: String): _CALL.GET(_ADD.GET_genome_corticalMappings_afferents_corticalArea_CORTICALAREAEQUALS+corticalArea, _coreRef._Relay_Afferent)
func GET_GE_corticalMappings_efferents_corticalArea(corticalArea: String): _CALL.GET(_ADD.GET_genome_corticalMappings_efferents_corticalArea_CORTICALAREAEQUALS+corticalArea, _coreRef._Relay_Efferent)
func GET_GE_morphology(morphologyName: String): _CALL.GET(_ADD.GET_genome_morphology+morphologyName, _coreRef._Relay_Morphology_information)
func GET_GE_morphologyUsage(morphologyName: String): _CALL.GET(_ADD.GET_genome_morphologyUsage+morphologyName, _coreRef._Relay_Morphology_usuage)
func GET_GE_mappingProperties(sourceCorticalName: String, destinationCorticalName: String): _CALL.GET(_ADD.GET_genome_mappingProperties+sourceCorticalName+"&dst_cortical_area="+destinationCorticalName, _coreRef._Relay_Update_Destination)
func GET_GE_circuits(): _CALL.GET(_ADD.GET_genome_circuits, _coreRef._Relay_circuit_list)
func GET_GE_circuitsize(circuitName: String): _CALL.GET(_ADD.GET_genome_circuitsize_CIRCUITNAMEEQUALS+circuitName, _coreRef._Relay_circuit_size)
func GET_MO_neuron_membranePotential(corticalArea: String): _CALL.GET(_ADD.GET_monitoring_neuron_membranePotential+corticalArea, _coreRef._Relay_Update_mem)
func GET_MO_neuron_synapticPotential(corticalArea: String): _CALL.GET(_ADD.GET_monitoring_neuron_synapticPotential+corticalArea, _coreRef._Relay_Update_syn)
func GET_GE_corticalTypeOptions(corticalType: String): _CALL.GET(_ADD.GET_genome_corticalTypeOptions_CORTICALTYPEQUALS+corticalType, _coreRef._Relay_update_OPU)
func GET_healthCheck(): _CALL.GET(_ADD.GET_healthCheck, _coreRef._Relay_Get_Health)
func GET_CO_corticalAreas_list_detailed(): _CALL.GET(_ADD.GET_connectome_corticalAreas_list_detailed, _coreRef._Relay_ConnectomeCorticalAreasListDetailed)

func POST_FE_burstEngine(newBurstRate: float): _CALL.POST(_ADD.POST_feagi_burstEngine, _coreRef._Relay_ChangedBurstRate, {"burst_duration": newBurstRate})
	

func POST_GE_corticalArea(corticalProperties: Dictionary): _CALL.POST(_ADD.POST_genome_corticalArea, _coreRef._Relay_updated_cortical, corticalProperties)
	
func POST_GE_customCorticalArea(corticalProperties: Dictionary): _CALL.POST(_ADD.POST_genome_customCorticalArea, _coreRef._Relay_updated_cortical, corticalProperties)
	
func POST_Request_Brain_visualizer(url, dataIn):
	#using _coreRef._Relay_updated_cortical since they both pass, thats it. leverage the same to save space
	_CALL.POST(url, _coreRef._Relay_updated_cortical, dataIn)
	
func PUT_GE_mappingProperties(dataIn, extra_name := ""): # We should rename these variables
	_CALL.PUT(_ADD.PUT_genome_mappingProperties + extra_name, _coreRef._Relay_PUT_Mapping_Properties, dataIn)

func PUT_Request_Brain_visualizer(url, dataIn): 
	_CALL.PUT(url, _coreRef._Relay_PUT_BV_functions, dataIn)

func DELETE_GE_corticalArea(corticalAreaName: String): 
	_CALL.DELETE(_ADD.DELETE_GE_corticalArea + corticalAreaName, _coreRef._Relay_DELETE_Cortical_area)

func DELETE_Request_Brain_visualizer(url):
	_CALL.DELETE(url, _coreRef._Relay_DELETE_Cortical_area)

func PUT_GE_corticalArea(dataIn: Dictionary): _CALL.PUT(_ADD.PUT_genome_corticalArea, _coreRef._Relay_PUT_GE_corticalArea, dataIn)
