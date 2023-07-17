extends Object
# Just a list of addresses to feagi 


var FEAGI_RootAddress = ""
const FEAGI_SEC = "HTTP://"

var ADD_GET_feagi_pns_current_ipu: String:
	get: return FEAGI_SEC + FEAGI_RootAddress + "/v1/feagi/feagi/pns/current/ipu"
var ADD_GET_feagi_pns_current_opu: String:
	get: return  FEAGI_SEC + FEAGI_RootAddress + "/v1/feagi/feagi/pns/current/opu"
var ADD_GET_genome_corticalAreaIDList: String:
	get: return  FEAGI_SEC + FEAGI_RootAddress + "/v1/feagi/genome/cortical_area_id_list"
var ADD_GET_genome_morphologyList: String:
	get: return  FEAGI_SEC + FEAGI_RootAddress + "/v1/feagi/genome/morphology_list"
var ADD_GET_genome_fileName: String:
	get: return  FEAGI_SEC + FEAGI_RootAddress + "/v1/feagi/genome/file_name"
var ADD_GET_genome_corticalAreaNameList: String:
	get: return  FEAGI_SEC + FEAGI_RootAddress + "/v1/feagi/genome/cortical_area_name_list"
var ADD_GET_genome_corticalNameLocation_CORTICALNAMEEQUALS: String:
	get: return  FEAGI_SEC + FEAGI_RootAddress + "/v1/feagi/genome/cortical_name_location?cortical_name="
var ADD_GET_genome_corticalArea_CORTICALAREAEQUALS: String:
	get: return  FEAGI_SEC + FEAGI_RootAddress + "/v1/feagi/genome/cortical_area?cortical_area="
var ADD_GET_genome_corticalMap: String:
	get: return  FEAGI_SEC + FEAGI_RootAddress + "/v1/feagi/genome/cortical_map"
var ADD_GET_genome_corticalMappings_afferents_corticalArea_CORTICALAREAEQUALS: String:
	get: return  FEAGI_SEC + FEAGI_RootAddress + "/v1/feagi/genome/cortical_mappings/afferents?cortical_area="
var ADD_GET_genome_corticalMappings_efferents_corticalArea_CORTICALAREAEQUALS: String:
	get: return  FEAGI_SEC + FEAGI_RootAddress + "/v1/feagi/genome/cortical_mappings/efferents?cortical_area="
var ADD_GET_genome_mappingProperties_CORTICALAREAEQUALS: String:
	get: return  FEAGI_SEC + FEAGI_RootAddress + "/v1/feagi/genome/mapping_properties?src_cortical_area="
var ADD_GET_genome_circuits: String:
	get: return  FEAGI_SEC + FEAGI_RootAddress + "/v1/feagi/genome/circuits"
var ADD_GET_genome_circuitSize_CIRCUITNAMEEQUALS: String:
	get: return  FEAGI_SEC + FEAGI_RootAddress + "/v1/feagi/genome/circuit_size?circuit_name="
var ADD_GET_connectome_properties_dimensions: String:
	get: return  FEAGI_SEC + FEAGI_RootAddress + "/v1/feagi/connectome/properties/dimensions"
var ADD_GET_genome_morphology_types: String:
	get: return  FEAGI_SEC + FEAGI_RootAddress + "/v1/feagi/genome/morphology_types"
var ADD_GET_genome_morphologyNameEQUALS: String:
	get: return  FEAGI_SEC + FEAGI_RootAddress + "/v1/feagi/genome/morphology?morphology_name="
var ADD_GET_genome_morphologyUsage_MORPHOLOGYNAMEEQUALS: String:
	get: return  FEAGI_SEC + FEAGI_RootAddress + "/v1/feagi/genome/morphology_usage?morphology_name="
var ADD_GET_genome_corticalTypeOptions_CORTICALTYPEQUALS: String:
	get: return  FEAGI_SEC + FEAGI_RootAddress + '/v1/feagi/genome/cortical_type_options?cortical_type='
var ADD_GET_genome_corticalIDNameMapping: String:
	get: return  FEAGI_SEC + FEAGI_RootAddress + '/v1/feagi/genome/cortical_id_name_mapping'
var ADD_GET_connectome_properties_mappings: String:
	get: return  FEAGI_SEC + FEAGI_RootAddress + "/v1/feagi/connectome/properties/mappings"
var ADD_GET_connectome_corticalAreas_list_detailed: String:
	get: return  FEAGI_SEC + FEAGI_RootAddress + "/v1/feagi/connectome/cortical_areas/list/detailed"
var ADD_GET_burstEngine_stimulationPeriod: String:
	get: return  FEAGI_SEC + FEAGI_RootAddress + "/v1/feagi/feagi/burst_engine/stimulation_period"
var ADD_GET_healthCheck: String:
	get: return  FEAGI_SEC + FEAGI_RootAddress + "/v1/feagi/health_check"
var ADD_GET_monitoring_neuron_membranePotential_CORTICALAREAEQUALS: String:
	get: return  FEAGI_SEC + FEAGI_RootAddress + '/v1/feagi/monitoring/neuron/membrane_potential?cortical_area='
var ADD_GET_monitoring_neuron_synapticPotential_CORTICALAREAEQUALS: String:
	get: return  FEAGI_SEC + FEAGI_RootAddress + '/v1/feagi/monitoring/neuron/synaptic_potential?cortical_area='

# Post Requests
var ADD_POST_feagi_burstEngine: String:
	get: return  FEAGI_SEC + FEAGI_RootAddress + "/v1/feagi/feagi/burst_engine"
var ADD_POST_genome_corticalArea: String:
	get: return  FEAGI_SEC + FEAGI_RootAddress + "/v1/feagi/genome/cortical_area"
var ADD_POST_genome_customCorticalArea: String:
	get: return  FEAGI_SEC + FEAGI_RootAddress + "/v1/feagi/genome/custom_cortical_area"

# Put Requests
var ADD_PUT_genome_corticalArea: String:
	get: return  FEAGI_SEC + FEAGI_RootAddress + "/v1/feagi/genome/cortical_area"
var ADD_PUT_genome_mappingProperties: String:
	get: return  FEAGI_SEC + FEAGI_RootAddress + "/v1/feagi/genome/mapping_properties"

	
# Delete Requests
var ADD_DELETE_genome_corticalArea_CORTICALAREANAMEEQUALS: String:
	get: return  FEAGI_SEC + FEAGI_RootAddress + "/v1/feagi/genome/cortical_area?cortical_area_name="
