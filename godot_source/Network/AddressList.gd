extends Object
class_name AddressList
# Just a list of addresses to feagi 

var _security = network_setting.SSL
var _rootAddress := ""


var GET_feagi_pns_current_ipu: String:
	get: return _security + _rootAddress + "/v1/feagi/feagi/pns/current/ipu"
var GET_feagi_pns_current_opu: String:
	get: return  _security + _rootAddress + "/v1/feagi/feagi/pns/current/opu"
var GET_genome_corticalAreaIDList: String:
	get: return  _security + _rootAddress + "/v1/feagi/genome/cortical_area_id_list"
var GET_genome_morphologyList: String:
	get: return  _security + _rootAddress + "/v1/feagi/genome/morphology_list"
var GET_genome_fileName: String:
	get: return  _security + _rootAddress + "/v1/feagi/genome/file_name"
var GET_genome_corticalAreaNameList: String:
	get: return  _security + _rootAddress + "/v1/feagi/genome/cortical_area_name_list"
var GET_genome_corticalNameLocation: String:
	get: return  _security + _rootAddress + "/v1/feagi/genome/cortical_name_location?cortical_name="
var GET_genome_corticalArea_CORTICALAREAEQUALS: String:
	get: return  _security + _rootAddress + "/v1/feagi/genome/cortical_area?cortical_area="
var GET_genome_corticalMap: String:
	get: return  _security + _rootAddress + "/v1/feagi/genome/cortical_map"
var GET_genome_corticalMappings_afferents_corticalArea_CORTICALAREAEQUALS: String:
	get: return  _security + _rootAddress + "/v1/feagi/genome/cortical_mappings/afferents?cortical_area="
var GET_genome_corticalMappings_efferents_corticalArea_CORTICALAREAEQUALS: String:
	get: return  _security + _rootAddress + "/v1/feagi/genome/cortical_mappings/efferents?cortical_area="
var GET_genome_mappingProperties_CORTICALAREAEQUALS: String:
	get: return  _security + _rootAddress + "/v1/feagi/genome/mapping_properties?src_cortical_area="
var GET_genome_circuits: String:
	get: return  _security + _rootAddress + "/v1/feagi/genome/circuits"
var GET_genome_circuitsize_CIRCUITNAMEEQUALS: String:
	get: return  _security + _rootAddress + "/v1/feagi/genome/circuit_size?circuit_name="
var GET_connectome_properties_dimensions: String:
	get: return  _security + _rootAddress + "/v1/feagi/connectome/properties/dimensions"
var GET_genome_morphology_types: String:
	get: return  _security + _rootAddress + "/v1/feagi/genome/morphology_types"
var GET_genome_morphologyNameEQUALS: String:
	get: return  _security + _rootAddress + "/v1/feagi/genome/morphology?morphology_name="
var GET_genome_morphologyUsage_MORPHOLOGYNAMEEQUALS: String:
	get: return  _security + _rootAddress + "/v1/feagi/genome/morphology_usage?morphology_name="
var GET_genome_corticalTypeOptions_CORTICALTYPEQUALS: String:
	get: return  _security + _rootAddress + '/v1/feagi/genome/cortical_type_options?cortical_type='
var GET_genome_corticalIDNameMapping: String:
	get: return  _security + _rootAddress + '/v1/feagi/genome/cortical_id_name_mapping'
var GET_connectome_properties_mappings: String:
	get: return  _security + _rootAddress + "/v1/feagi/connectome/properties/mappings"
var GET_connectome_corticalAreas_list_detailed: String:
	get: return  _security + _rootAddress + "/v1/feagi/connectome/cortical_areas/list/detailed"
var GET_burstEngine_stimulationPeriod: String:
	get: return  _security + _rootAddress + "/v1/feagi/feagi/burst_engine/stimulation_period"
var GET_healthCheck: String:
	get: return  _security + _rootAddress + "/v1/feagi/health_check"
var GET_monitoring_neuron_membranePotential_CORTICALAREAEQUALS: String:
	get: return  _security + _rootAddress + '/v1/feagi/monitoring/neuron/membrane_potential?cortical_area='
var GET_monitoring_neuron_synapticPotential_CORTICALAREAEQUALS: String:
	get: return  _security + _rootAddress + '/v1/feagi/monitoring/neuron/synaptic_potential?cortical_area='
	
# Post Requests
var POST_feagi_burstEngine: String:
	get: return  _security + _rootAddress + "/v1/feagi/feagi/burst_engine"
var POST_genome_corticalArea: String:
	get: return  _security + _rootAddress + "/v1/feagi/genome/cortical_area"
var POST_genome_customCorticalArea: String:
	get: return  _security + _rootAddress + "/v1/feagi/genome/custom_cortical_area"

# Put Requests
var PUT_genome_corticalArea: String:
	get: return  _security + _rootAddress + "/v1/feagi/genome/cortical_area"
var PUT_genome_mappingProperties: String:
	get: return  _security + _rootAddress + "/v1/feagi/genome/mapping_properties"

	
# Delete Requests
var DELETE_genome_corticalArea: String:
	get: return  _security + _rootAddress + "/v1/feagi/genome/cortical_area?cortical_area_name="

func _init(FEAGIRootAddress: StringName, securitySSL: StringName) -> void:
	_rootAddress = FEAGIRootAddress
	_security = securitySSL
