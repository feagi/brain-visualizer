extends Object
class_name AddressList
## Essentially a list of endpoints to FEAGI

# Get Requests
var GET_feagi_pns_current_ipu: StringName = "/v1/feagi/feagi/pns/current/ipu"
var GET_feagi_pns_current_opu: StringName = "/v1/feagi/feagi/pns/current/opu"
var GET_genome_corticalAreaIDList: StringName = "/v1/feagi/genome/cortical_area_id_list"
var GET_genome_morphologyList: StringName = "/v1/feagi/genome/morphology_list"
var GET_genome_fileName: StringName = "/v1/feagi/genome/file_name"
var GET_genome_corticalAreaNameList: StringName = "/v1/feagi/genome/cortical_area_name_list"
var GET_genome_corticalNameLocation: StringName = "/v1/feagi/genome/cortical_name_location?cortical_name="
var GET_genome_corticalArea: StringName = "/v1/feagi/genome/cortical_area?cortical_area="
var GET_genome_corticalMap: StringName = "/v1/feagi/genome/cortical_map"
var GET_genome_corticalMappings_afferents_corticalArea: StringName = "/v1/feagi/genome/cortical_mappings/afferents?cortical_area="
var GET_genome_corticalMappings_efferents_corticalArea: StringName = "/v1/feagi/genome/cortical_mappings/efferents?cortical_area="
var GET_genome_mappingProperties: StringName = "/v1/feagi/genome/mapping_properties?src_cortical_area="
var GET_genome_circuits: StringName = "/v1/feagi/genome/circuits"
var GET_genome_circuitsize: StringName = "/v1/feagi/genome/circuit_size?circuit_name="
var GET_genome_morphology_types: StringName = "/v1/feagi/genome/morphology_types"
var GET_genome_morphologyName: StringName = "/v1/feagi/genome/morphology?morphology_name="
var GET_genome_morphologyUsage: StringName = "/v1/feagi/genome/morphology_usage?morphology_name="
var GET_genome_corticalTypeOptions: StringName = '/v1/feagi/genome/cortical_type_options?cortical_type='
var GET_genome_corticalIDNameMapping: StringName = '/v1/feagi/genome/cortical_id_name_mapping'
var GET_genome_corticalLocations2D: StringName = '/v1/feagi/genome/cortical_locations_2d'
var GET_genome_corticalArea_geometry: StringName = '/v1/feagi/genome/cortical_area/geometry'
var GET_genome_corticalTypes: StringName = "/v1/feagi/genome/cortical_types"
var GET_connectome_properties_dimensions: StringName = "/v1/feagi/connectome/properties/dimensions"
var GET_connectome_properties_mappings: StringName = "/v1/feagi/connectome/properties/mappings"
var GET_connectome_corticalAreas_list_detailed: StringName = "/v1/feagi/connectome/cortical_areas/list/detailed"
var GET_burstEngine_stimulationPeriod: StringName = "/v1/feagi/feagi/burst_engine/stimulation_period"
var GET_healthCheck: StringName = "/v1/feagi/health_check"
var GET_monitoring_neuron_membranePotential: StringName = '/v1/feagi/monitoring/neuron/membrane_potential?cortical_area='
var GET_monitoring_neuron_synapticPotential: StringName = '/v1/feagi/monitoring/neuron/synaptic_potential?cortical_area='
var GET_morphologies_list_types: StringName = '/v1/feagi/morphologies/list/types'
var GET_pns_current_ipu: StringName = '/v1/feagi/feagi/pns/current/ipu'
var GET_pns_current_opu: StringName = '/v1/feagi/feagi/pns/current/opu'

# Post Requests
var POST_feagi_burstEngine: StringName = "/v1/feagi/feagi/burst_engine"
var POST_genome_corticalArea: StringName = "/v1/feagi/genome/cortical_area"
var POST_genome_customCorticalArea: StringName = "/v1/feagi/genome/custom_cortical_area"
var POST_genome_morphology: StringName = "/v1/feagi/genome/morphology?morphology_name="
var POST_monitoring_neuron_membranePotential: StringName = "/v1/feagi/monitoring/neuron/membrane_potential?cortical_area="
var POST_monitoring_neuron_synapticPotential: StringName = "/v1/feagi/monitoring/neuron/synaptic_potential?cortical_area="

# Put Requests
var PUT_genome_corticalArea: StringName = "/v1/feagi/genome/cortical_area"
var PUT_genome_mappingProperties: StringName = "/v1/feagi/genome/mapping_properties"
var PUT_genome_morphology: StringName = "/v1/feagi/genome/morphology?morphology_name="

# Delete Requests
var DELETE_GE_corticalArea: StringName = "/v1/feagi/genome/cortical_area?cortical_area_name="
var DELETE_GE_morphology: StringName = "/v1/feagi/genome/morphology?morphology_name="

func _init(FEAGIFullAddress: StringName) -> void:
	GET_feagi_pns_current_ipu = FEAGIFullAddress + GET_feagi_pns_current_ipu
	GET_feagi_pns_current_opu = FEAGIFullAddress + GET_feagi_pns_current_opu
	GET_genome_corticalAreaIDList = FEAGIFullAddress + GET_genome_corticalAreaIDList
	GET_genome_morphologyList = FEAGIFullAddress + GET_genome_morphologyList
	GET_genome_fileName = FEAGIFullAddress + GET_genome_fileName
	GET_genome_corticalAreaNameList = FEAGIFullAddress + GET_genome_corticalAreaNameList
	GET_genome_corticalNameLocation = FEAGIFullAddress + GET_genome_corticalNameLocation
	GET_genome_corticalArea = FEAGIFullAddress + GET_genome_corticalArea
	GET_genome_corticalMap = FEAGIFullAddress + GET_genome_corticalMap
	GET_genome_corticalMappings_afferents_corticalArea = FEAGIFullAddress + GET_genome_corticalMappings_afferents_corticalArea
	GET_genome_corticalMappings_efferents_corticalArea = FEAGIFullAddress + GET_genome_corticalMappings_efferents_corticalArea
	GET_genome_mappingProperties = FEAGIFullAddress + GET_genome_mappingProperties
	GET_genome_circuits = FEAGIFullAddress + GET_genome_circuits
	GET_genome_circuitsize = FEAGIFullAddress + GET_genome_circuitsize
	GET_connectome_properties_dimensions = FEAGIFullAddress + GET_connectome_properties_dimensions
	GET_genome_morphology_types = FEAGIFullAddress + GET_genome_morphology_types
	GET_genome_morphologyName = FEAGIFullAddress + GET_genome_morphologyName
	GET_genome_morphologyUsage = FEAGIFullAddress + GET_genome_morphologyUsage
	GET_genome_corticalTypeOptions = FEAGIFullAddress + GET_genome_corticalTypeOptions
	GET_genome_corticalIDNameMapping = FEAGIFullAddress + GET_genome_corticalIDNameMapping
	GET_genome_corticalLocations2D = FEAGIFullAddress + GET_genome_corticalLocations2D
	GET_genome_corticalArea_geometry = FEAGIFullAddress + GET_genome_corticalArea_geometry
	GET_genome_corticalTypes = FEAGIFullAddress + GET_genome_corticalTypes
	GET_connectome_properties_mappings = FEAGIFullAddress + GET_connectome_properties_mappings
	GET_burstEngine_stimulationPeriod = FEAGIFullAddress + GET_burstEngine_stimulationPeriod
	GET_healthCheck = FEAGIFullAddress + GET_healthCheck
	GET_monitoring_neuron_membranePotential = FEAGIFullAddress + GET_monitoring_neuron_membranePotential
	GET_monitoring_neuron_synapticPotential = FEAGIFullAddress + GET_monitoring_neuron_synapticPotential
	GET_morphologies_list_types = FEAGIFullAddress + GET_morphologies_list_types
	GET_pns_current_ipu = FEAGIFullAddress + GET_pns_current_ipu
	GET_pns_current_opu = FEAGIFullAddress + GET_pns_current_opu

	POST_feagi_burstEngine = FEAGIFullAddress + POST_feagi_burstEngine
	POST_genome_corticalArea = FEAGIFullAddress + POST_genome_corticalArea
	POST_genome_customCorticalArea = FEAGIFullAddress + POST_genome_customCorticalArea
	POST_genome_morphology = FEAGIFullAddress + POST_genome_morphology
	POST_monitoring_neuron_membranePotential = FEAGIFullAddress + POST_monitoring_neuron_membranePotential
	POST_monitoring_neuron_synapticPotential = FEAGIFullAddress + POST_monitoring_neuron_synapticPotential
	PUT_genome_corticalArea = FEAGIFullAddress + PUT_genome_corticalArea
	PUT_genome_mappingProperties = FEAGIFullAddress + PUT_genome_mappingProperties
	PUT_genome_morphology = FEAGIFullAddress + PUT_genome_morphology
	DELETE_GE_corticalArea = FEAGIFullAddress + DELETE_GE_corticalArea
