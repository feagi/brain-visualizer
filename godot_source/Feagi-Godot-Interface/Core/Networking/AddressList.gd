extends Object
class_name AddressList
## Essentially a list of endpoints to FEAGI

# Get Requests
var GET_corticalAreas_ipu: StringName = "/v1/cortical_area/ipu"
var GET_corticalAreas_opu: StringName = "/v1/cortical_area/opu"
var GET_corticalAreas_corticalAreaIDList: StringName = "/v1/cortical_area/cortical_area_id_list"
var GET_neuronMorphologies_morphologyList: StringName = "/v1/morphology/morphology_list"
var GET_genome_fileName: StringName = "/v1/genome/file_name"
var GET_corticalAreas_corticalAreaNameList: StringName = "/v1/cortical_area/cortical_area_name_list"
var POST_corticalAreas_corticalNameLocation: StringName = "/v1/cortical_area/cortical_name_location"
var POST_corticalArea_corticalAreaProperties: StringName = "/v1/cortical_area/cortical_area"
var GET_corticalArea_corticalMapDetailed: StringName = "/v1/cortical_area/cortical_map_detailed"
var POST_corticalMappings_afferents: StringName = "/v1/cortical_mapping/afferents"
var POST_corticalMappings_efferents: StringName = "/v1/cortical_mapping/efferents"
var POST_corticalMappings_mappingProperties: StringName = "/v1/cortical_mapping/mapping_properties"
var GET_genome_circuits: StringName = "/v1/genome/circuits"
var GET_morphology_morphology_types: StringName = "/v1/morphology/morphology_types"
var POST_morphology_morphologyProperties: StringName = "/v1/morphology/morphology_properties"
var POST_morphology_morphologyUsage: StringName = "/v1/morphology/morphology_usage"
var POST_corticalArea_corticalTypeOptions: StringName = '/v1/cortical_area/cortical_type_options'
var GET_corticalArea_corticalIDNameMapping: StringName = '/v1/cortical_area/cortical_id_name_mapping'
var GET_corticalArea_corticalLocations2D: StringName = '/v1/cortical_area/cortical_locations_2d'
var GET_corticalArea_corticalArea_geometry: StringName = '/v1/cortical_area/cortical_area/geometry'
var GET_corticalArea_corticalTypes: StringName = "/v1/cortical_area/cortical_types"
var GET_connectome_properties_dimensions: StringName = "/v1/connectome/properties/dimensions"
var GET_connectome_properties_mappings: StringName = "/v1/connectome/properties/mappings"
var GET_connectome_corticalAreas_list_detailed: StringName = "/v1/connectome/cortical_areas/list/detailed"
var GET_burstEngine_stimulationPeriod: StringName = "/v1/burst_engine/stimulation_period"
var GET_system_healthCheck: StringName = "/v1/system/health_check"
var POST_insight_neurons_membranePotentialStatus: StringName = '/v1/insight/neurons/membrane_potential_status'
var POST_insight_neuron_synapticPotentialStatus: StringName = '/v1/insight/neuron/synaptic_potential_status'
var GET_morphology_list_types: StringName = '/v1/morphology/list/types'

# Post Requests
var POST_feagi_burstEngine: StringName = "/v1/burst_engine/stimulation_period"
var POST_genome_corticalArea: StringName = "/v1/cortical_area/cortical_area"
var POST_genome_customCorticalArea: StringName = "/v1/cortical_area/custom_cortical_area"
var POST_genome_morphology: StringName = "/v1/morphology/morphology?morphology_name="
var POST_genome_append: StringName = "/v1/feagi/genome/append?circuit_name=" # Leave this to Amir
var POST_genome_amalgamationDestination: StringName = "/v1/genome/amalgamation_destination?circuit_origin_x=" # actual example: http://127.0.0.1:8000/v1/genome/amalgamation_destination?circuit_origin_x=1&circuit_origin_y=2&circuit_origin_z=3&amalgamation_id=4
var POST_monitoring_neuron_membranePotential_set: StringName = "/v1/insight/neurons/membrane_potential"
var POST_monitoring_neuron_synapticPotential_set: StringName = "/v1/insight/neuron/synaptic_potential"

# Put Requests
var PUT_genome_corticalArea: StringName = "/v1/cortical_area/cortical_area"
var PUT_genome_mappingProperties: StringName = "/v1/cortical_mapping/mapping_properties"
var PUT_genome_morphology: StringName = "/v1/morphology/morphology?morphology_name="
var PUT_genome_coord2d: StringName = "/v1/cortical_area/coord_2d"

# Delete Requests
var DELETE_GE_corticalArea: StringName = "/v1/cortical_area/cortical_area?cortical_area_name="
var DELETE_GE_morphology: StringName = "/v1/morphology/morphology?morphology_name="
var DELETE_GE_amalgamationCancellation = "/v1/genome/amalgamation_cancellation?amalgamation_id="

func _init(FEAGIFullAddress: StringName) -> void:
	GET_corticalAreas_ipu = FEAGIFullAddress + GET_corticalAreas_ipu
	GET_corticalAreas_opu = FEAGIFullAddress + GET_corticalAreas_opu
	GET_corticalAreas_corticalAreaIDList = FEAGIFullAddress + GET_corticalAreas_corticalAreaIDList
	GET_neuronMorphologies_morphologyList = FEAGIFullAddress + GET_neuronMorphologies_morphologyList
	GET_genome_fileName = FEAGIFullAddress + GET_genome_fileName
	GET_corticalAreas_corticalAreaNameList = FEAGIFullAddress + GET_corticalAreas_corticalAreaNameList
	POST_corticalAreas_corticalNameLocation = FEAGIFullAddress + POST_corticalAreas_corticalNameLocation
	POST_corticalArea_corticalAreaProperties = FEAGIFullAddress + POST_corticalArea_corticalAreaProperties
	GET_corticalArea_corticalMapDetailed = FEAGIFullAddress + GET_corticalArea_corticalMapDetailed
	POST_corticalMappings_afferents = FEAGIFullAddress + POST_corticalMappings_afferents
	POST_corticalMappings_efferents = FEAGIFullAddress + POST_corticalMappings_efferents
	POST_corticalMappings_mappingProperties = FEAGIFullAddress + POST_corticalMappings_mappingProperties
	GET_genome_circuits = FEAGIFullAddress + GET_genome_circuits
	GET_connectome_properties_dimensions = FEAGIFullAddress + GET_connectome_properties_dimensions
	GET_morphology_morphology_types = FEAGIFullAddress + GET_morphology_morphology_types
	POST_morphology_morphologyProperties = FEAGIFullAddress + POST_morphology_morphologyProperties
	POST_morphology_morphologyUsage = FEAGIFullAddress + POST_morphology_morphologyUsage
	POST_corticalArea_corticalTypeOptions = FEAGIFullAddress + POST_corticalArea_corticalTypeOptions
	GET_corticalArea_corticalIDNameMapping = FEAGIFullAddress + GET_corticalArea_corticalIDNameMapping
	GET_corticalArea_corticalLocations2D = FEAGIFullAddress + GET_corticalArea_corticalLocations2D
	GET_corticalArea_corticalArea_geometry = FEAGIFullAddress + GET_corticalArea_corticalArea_geometry
	GET_corticalArea_corticalTypes = FEAGIFullAddress + GET_corticalArea_corticalTypes
	GET_connectome_properties_mappings = FEAGIFullAddress + GET_connectome_properties_mappings
	GET_burstEngine_stimulationPeriod = FEAGIFullAddress + GET_burstEngine_stimulationPeriod
	GET_system_healthCheck = FEAGIFullAddress + GET_system_healthCheck
	POST_insight_neurons_membranePotentialStatus = FEAGIFullAddress + POST_insight_neurons_membranePotentialStatus
	POST_insight_neuron_synapticPotentialStatus = FEAGIFullAddress + POST_insight_neuron_synapticPotentialStatus
	GET_morphology_list_types = FEAGIFullAddress + GET_morphology_list_types

	POST_feagi_burstEngine = FEAGIFullAddress + POST_feagi_burstEngine
	POST_genome_corticalArea = FEAGIFullAddress + POST_genome_corticalArea
	POST_genome_customCorticalArea = FEAGIFullAddress + POST_genome_customCorticalArea
	POST_genome_morphology = FEAGIFullAddress + POST_genome_morphology
	POST_genome_append = FEAGIFullAddress +  POST_genome_append
	POST_genome_amalgamationDestination = FEAGIFullAddress + POST_genome_amalgamationDestination
	POST_monitoring_neuron_membranePotential_set = FEAGIFullAddress + POST_monitoring_neuron_membranePotential_set
	POST_monitoring_neuron_synapticPotential_set = FEAGIFullAddress + POST_monitoring_neuron_synapticPotential_set
	
	PUT_genome_corticalArea = FEAGIFullAddress + PUT_genome_corticalArea
	PUT_genome_mappingProperties = FEAGIFullAddress + PUT_genome_mappingProperties
	PUT_genome_morphology = FEAGIFullAddress + PUT_genome_morphology
	PUT_genome_coord2d = FEAGIFullAddress + PUT_genome_coord2d
	
	DELETE_GE_corticalArea = FEAGIFullAddress + DELETE_GE_corticalArea
	DELETE_GE_morphology = FEAGIFullAddress + DELETE_GE_morphology
	DELETE_GE_amalgamationCancellation = FEAGIFullAddress + DELETE_GE_amalgamationCancellation
