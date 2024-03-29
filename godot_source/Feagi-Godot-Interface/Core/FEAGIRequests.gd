extends Node
## AUTOLOADED
## General actions to request of FEAGI
## Try to use the functions here to call feagi actions instead of through FEAGIInterface

var feagi_interface: FEAGIInterface:
	get: return _feagi_interface

var _feagi_interface: FEAGIInterface # MUST be set ASAP externally or the below will crash!


#region Cortical Areas

## Requests from FEAGI summary of all cortical areas (name, dimensions, 2D/3D location, and visibility)
## Triggers an update in FEAGI Cached cortical areas
## Success emits cortical_area_added, cortical_area_removed, cortical_area_updated depending on situation
func refresh_cortical_areas() -> void:
	print("User requesting cortical area geometry data")
	_feagi_interface.calls.GET_GE_CorticalArea_geometry() # This will afterwards trigger "refresh_connection_list()"

## Requests from FEAGI to send back all details of an EXISTING cortical area
## Success emits cortical_area_updated
func refresh_cortical_area(cortical_area: BaseCorticalArea, polling: bool = false) -> void:
	print("Pinging FEAGI latest cortical area details for " + cortical_area.cortical_ID)
	if polling:
		_feagi_interface.calls.GET_GE_corticalArea_POLL(cortical_area.cortical_ID)
	else:
		_feagi_interface.calls.GET_GE_corticalArea(cortical_area.cortical_ID)
	request_membrane_monitoring_status(cortical_area)
	request_synaptic_monitoring_status(cortical_area)

## Requests from FEAGI to add a cortical area using the custom call
## the call returns the FEAGI generated cortical ID
## Success emits cortical_area_added
func add_custom_cortical_area(cortical_name: StringName, coordinates_3D: Vector3i, dimensions: Vector3i, is_coordinate_2D_defined: bool,
	coordinates_2D: Vector2i = Vector2(0,0)) -> void:
	_feagi_interface.calls.POST_GE_customCorticalArea(cortical_name, coordinates_3D, dimensions, is_coordinate_2D_defined, coordinates_2D)

## TODO should only be 1,1,1 dimension
## Requests from FEAGI to add a cortical area using the custom call (subgroup memory)
## the call returns the FEAGI generated cortical ID
## Success emits cortical_area_added
func add_memory_cortical_area(cortical_name: StringName, coordinates_3D: Vector3i, dimensions: Vector3i, is_coordinate_2D_defined: bool,
	coordinates_2D: Vector2i = Vector2(0,0)) -> void:
	_feagi_interface.calls.POST_GE_customCorticalArea(cortical_name, coordinates_3D, dimensions, is_coordinate_2D_defined, coordinates_2D, true)


func request_add_IOPU_cortical_area(IOPU_template: CorticalTemplate, channel_count: int, coordinates_3D: Vector3i, is_coordinate_2D_defined: bool, coordinates_2D: Vector2i = Vector2(0,0)) -> void:
	print("User requested adding OPU/IPU cortical area")
	if !(IOPU_template.cortical_type  in [BaseCorticalArea.CORTICAL_AREA_TYPE.IPU, BaseCorticalArea.CORTICAL_AREA_TYPE.OPU]):
		push_error("Unable to create non-IPU/OPU area using the request IPU/OPU call!, Skipping!")
		return
	if channel_count < 1:
		push_error("Channel count must be greater than 0 for a IPU/OPU area!, Skipping!")
		return
	_feagi_interface.calls.POST_GE_corticalArea(IOPU_template.ID, IOPU_template.cortical_type, coordinates_3D, is_coordinate_2D_defined, channel_count, coordinates_2D)

func request_membrane_monitoring_status(cortical_area: BaseCorticalArea) -> void:
	print("User requested membrane monitoring state for " + cortical_area.cortical_ID)
	_feagi_interface.calls.GET_MO_neuron_membranePotential(cortical_area.cortical_ID)

func request_synaptic_monitoring_status(cortical_area: BaseCorticalArea) -> void:
	print("User requested synaptic monitoring state for " + cortical_area.cortical_ID)
	_feagi_interface.calls.GET_MO_neuron_synapticPotential(cortical_area.cortical_ID)

func request_clone_cortical_area(cloning_area: BaseCorticalArea, new_name: StringName, new_position_2D: Vector2i, new_position_3D: Vector3i) -> void:
	if !cloning_area.user_can_clone_this_cortical_area:
		push_error("Unable to clone cortical area %s as it is of type %s! Skipping!" % [cloning_area.cortical_ID, cloning_area.type_as_string])
		return
	print("User requested cloning cortical area " + cloning_area.cortical_ID)
	var is_cloning_source_memory_type: bool = cloning_area.group == BaseCorticalArea.CORTICAL_AREA_TYPE.MEMORY
	_feagi_interface.calls.POST_GE_customCorticalArea(new_name, new_position_3D, cloning_area.dimensions, true, new_position_2D, is_cloning_source_memory_type, cloning_area.cortical_ID)

## Refresh ID list of IPU and OPU templates
## TODO: Currently saves data nowhere!
func request_refresh_IPU_OPU_template_IDs() -> void:
	print("Requesting up to date IPU and OPU template IDs")
	_feagi_interface.calls.GET_PNS_current_ipu()
	_feagi_interface.calls.GET_PNS_current_opu()

func request_refresh_cortical_templates() -> void:
	print("Requesting up to date cortical templates")
	_feagi_interface.calls.GET_GE_corticalTypes()

## Sets the properties of a given cortical area
## MAKE SURE THE DICTIONARY IS FORMATTED CORRECTLY!
## Convert Vectors to arrays, StringNames to Strings
## Success emits cortical_area_updated since this calls "refresh_cortical_area" on success
func set_cortical_area_properties(ID: StringName, formatted_properties_to_set: Dictionary) -> void:
	
	_feagi_interface.calls.PUT_GE_corticalArea(ID, formatted_properties_to_set)

func request_change_membrane_monitoring_status(cortical_area: BaseCorticalArea, requested_state: bool) -> void:
	print("User requested modification of membrane monitoring state for " + cortical_area.cortical_ID)
	_feagi_interface.calls.POST_MON_neuron_membranePotential(cortical_area.cortical_ID, requested_state)

func request_change_synaptic_monitoring_status(cortical_area: BaseCorticalArea, requested_state: bool) -> void:
	print("User requested modification of synaptic monitoring state for " + cortical_area.cortical_ID)
	_feagi_interface.calls.POST_MON_neuron_synapticPotential(cortical_area.cortical_ID, requested_state)

## To request the changing of 2D positions of a number of cortical areas with little processing delay
func request_mass_change_2D_positions(cortical_IDs_mapped_to_vector2i_positions: Dictionary) -> void:
	print("User requests a mass cortical area movement change")
	_feagi_interface.calls.PUT_GE_coord2D(cortical_IDs_mapped_to_vector2i_positions)

## Requests FEAGI to delete a cortical area by ID
## if sucessful,  causes the cortical area cache to remove said cortical area, and cached connections to remove connections to/from this area
## Success emits cortical_area_removed, and possibly various morphology_removed
func delete_cortical_area(cortical_id: StringName) -> void:
	print("User requesting cortical area deletion of area " + cortical_id)
	_feagi_interface.calls.DELETE_GE_corticalArea(cortical_id)
#endregion

#region Morphologies
## Requests from FEAGI a dict of all morphologies in the genome and each type.
## Triggers an update in FEAGI Cached morphologies, which cascades to signals for morphologies added / removed
func refresh_morphology_list() -> void:
	print("User requested refresh of the morphology listing")
	_feagi_interface.calls.GET_morphology_morphologies()

## Requests the latest info on a specific morphology name
## Success emits morphology_updated
func refresh_morphology_properties(morphology_name: StringName) -> void:
	print("User requested refresh of properties of morphology " + morphology_name)
	_feagi_interface.calls.GET_GE_morphology(morphology_name)

func get_morphology_usage(morphology_name: StringName) -> void:
	if morphology_name not in FeagiCache.morphology_cache.available_morphologies.keys():
		push_error("Unable to retrieve usage of morphology not found in cache with name of " + morphology_name + ". Skipping!")
		return
	print("Requesting FEAGI for usage of morphology " + morphology_name)
	_feagi_interface.calls.GET_GE_morphologyUsage(morphology_name)

func request_updating_morphology(morphology_updating: Morphology) -> void:
	if morphology_updating.name not in FeagiCache.morphology_cache.available_morphologies.keys():
		push_error("Unable to update morphology not found in cache with name of " + morphology_updating.name + ". Skipping!")
		return
	print("Requesting FEAGI to update morphology " + morphology_updating.name)
	_feagi_interface.calls.PUT_GE_morphology(morphology_updating.name, morphology_updating.type, morphology_updating.to_dictionary())
	
## Requests FEAGI to create a morphology given a morphology object of a supported type
func request_create_morphology(morphology_to_create: Morphology) -> void:
	if morphology_to_create.type == Morphology.MORPHOLOGY_TYPE.NULL:
		push_warning("Unable to create Null type morphology. Skipping!")
		return
	if morphology_to_create.name in FeagiCache.morphology_cache.available_morphologies.keys():
		push_warning("Attempting to create morphology of name %s when one of the same name already exists. Skipping!" % [morphology_to_create.name])
		return

	print("Requesting FEAGI to create morphology " + morphology_to_create.name)
	_feagi_interface.calls.POST_GE_morphology(morphology_to_create.name, morphology_to_create.type, morphology_to_create.to_dictionary())

## Requests feagi to delete a morphology
func request_delete_morphology(morphology: Morphology) -> void:
	print("User requested deletion of morphology " + morphology.name)
	if morphology not in FeagiCache.morphology_cache.available_morphologies.values():
		push_error("Attempted to delete morphology %s that not located in cache! Skipping!" % morphology.name)
		return
	if morphology.get_latest_known_deletability() in [Morphology.DELETABILITY.NOT_DELETABLE_USED, Morphology.DELETABILITY.NOT_DELETABLE_UNKNOWN]:
		push_error("Unable to delete morphology %s that is not allowed for deletion! Skipping!" % morphology.name)
		return
	_feagi_interface.calls.DELETE_GE_morphology(morphology.name)

#TODO this should be updated
func request_creating_function_morphology(morphology_name: StringName, parameters: Dictionary) -> void:
	print("Use requested creation of function morphology " + morphology_name)
	_feagi_interface.calls.POST_GE_morphology(morphology_name, Morphology.MORPHOLOGY_TYPE.FUNCTIONS, parameters)
#endregion

#region Connections
## Requests from FEAGI a dict of all conneciton mappings between cortical areas, and the number of mappings per each
## Triggers an update in FEAGI cached connections, which cascades to signals for connections added and removed
## NOTE FOR STARTUP: This should be called after cortical areas have been loaded into memory, otherwise cortical ID references here will be invalid
func refresh_connection_list() -> void:
	_feagi_interface.calls.GET_GE_corticalMap_detailed()

## Requests from FEAGI the mapping properties between 2 cortical areas
func get_mapping_properties_between_two_areas(source_area: BaseCorticalArea, destination_area: BaseCorticalArea) -> void:
	_feagi_interface.calls.GET_GE_mappingProperties(source_area.cortical_ID, destination_area.cortical_ID)

## Requese from FEAGI to fully remove the mapping between 2 cortical areas (set the mapping arrays to empty)
func request_delete_mapping_between_corticals(source_area: BaseCorticalArea, destination_area: BaseCorticalArea) -> void:
	print("User Requested Deletion of the connection from cortical area %s toward %s" % [source_area.cortical_ID, destination_area.cortical_ID])
	# This essentially works by sending an empty array for the mappings
	_feagi_interface.calls.PUT_GE_mappingProperties(source_area, destination_area, [])

## Request FEAGI to set a specific mapping between 2 cortical areas (overridding previous setting)
func request_set_mapping_between_corticals(source_area: BaseCorticalArea, destination_area: BaseCorticalArea, mappings: Array[MappingProperty]) -> void:
	print("User Requested modification of the connection from cortical area %s toward %s" % [source_area.cortical_ID, destination_area.cortical_ID])
	if MappingProperty.is_mapping_property_array_invalid_for_cortical_areas(mappings, source_area, destination_area):
		push_error("Requested Mapping appears to be invalid! Skip sending requesting mapping configuration to FEAGI!")
		return
	_feagi_interface.calls.PUT_GE_mappingProperties(source_area, destination_area, MappingProperties.mapping_properties_to_FEAGI_formated_array(mappings))

## Request FEAGI to append mappings to a current mappings
## NOTE: This assumes Cache is up to date on the current mapping state
func append_mapping_between_corticals(source_area: BaseCorticalArea, destination_area: BaseCorticalArea, additional_mappings: Array[MappingProperty]) -> void:
	var current_mapping: MappingProperties = source_area.get_mappings_to(destination_area).duplicate()
	var current_mappings: Array[MappingProperty] = current_mapping.mappings
	current_mappings.append_array(additional_mappings)
	request_set_mapping_between_corticals(source_area, destination_area, current_mappings)

## Request FEAGI to append a default mapping (given a morphology) between 2 cortical areas
func request_add_default_mapping_between_corticals(source_area: BaseCorticalArea, destination_area: BaseCorticalArea, morphology: Morphology) -> void:
	var additional_mappings: Array[MappingProperty] = [MappingProperty.create_default_mapping(morphology)]
	append_mapping_between_corticals(source_area, destination_area, additional_mappings)
#endregion

#region Circuits

## Gets the current available circuits of FEAGI
func refresh_available_circuits() -> void:
	_feagi_interface.calls.GET_GE_circuits()

## Retrieves the details of a circuit given a circuit name (include the ''.json')
## On Success, emits signal 'retrieved_circuit_details' in autoload node FEAGIEvents
func get_circuit_details(circuit_file_name: StringName) -> void:
	_feagi_interface.calls.GET_GE_circuitDescription(circuit_file_name)

func request_add_circuit(circuit_file_name: StringName, circuit_position: Vector3i) -> void:
	_feagi_interface.calls.POST_GE_append(circuit_file_name, circuit_position)
#endregion

#region General

const DELAY_BETWEEN_WEBSOCKET_PINGS: float = 0.5

var _ping_timer: Timer

## Get current burst rate
func refresh_delay_between_bursts() -> void:
	_feagi_interface.calls.GET_BU_stimulationPeriod()

## Set a burst rate
func set_delay_between_bursts(delay_between_bursts_in_seconds: float) -> void:
	_feagi_interface.calls.POST_FE_burstEngine(delay_between_bursts_in_seconds)

## Retrieves initial data needed to get started following genome load
func initial_FEAGI_calls() -> void:
	refresh_morphology_list()
	refresh_cortical_areas() # This also causes a refresh of connections afterwards
	refresh_delay_between_bursts()
	request_refresh_cortical_templates()

## Call when a genome is hard reset, triggers a cache wipe and reset from frsh feagi data
func hard_reset_genome_from_FEAGI() -> void:
	FeagiEvents.genome_is_about_to_reset.emit()
	VisConfig.UI_manager.window_manager.force_close_all_windows()
	VisConfig.visualizer_state = VisConfig.STATES.LOADING_INITIAL
	FeagiCache.hard_wipe()
	initial_FEAGI_calls()

## Calls feagi to retrieve the currently loaded filename.
func get_loaded_genome() -> void:
	_feagi_interface.calls.GET_GE_fileName()

## Calls feagi to retrieve genome health. Polls if genome is unavailable. used for launch since this will launch "initial_FEAGI_calls" once genome is available
func poll_genome_availability_launch() -> void:
	_feagi_interface.calls.GET_healthCheck_POLL_GENOME()

## Calls feagi to retrieve genome health. Polls constantly to update health stats 
func poll_genome_availability_monitoring() -> void:
	_feagi_interface.calls.GET_healthCheck_POLL_MONITORING()

func request_import_amalgamation(circuit_position: Vector3i, amalgamation_ID: StringName) -> void:
	_feagi_interface.calls.POST_GE_amalgamationDestination(circuit_position, amalgamation_ID, null)

func request_cancel_amalgamation(amalgamation_ID: StringName) -> void:
	_feagi_interface.calls.DELETE_GE_amalgamationCancelation(amalgamation_ID)


#endregion
