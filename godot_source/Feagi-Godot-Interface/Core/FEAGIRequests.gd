extends Node
## AUTOLOADED
## General actions to request of FEAGI
## Try to use the functions here to call feagi actions instead of through FEAGIInterface

var feagi_interface: FEAGIInterface:
	get: return _feagi_interface

var _feagi_interface: FEAGIInterface # MUST be set ASAP externally or the below will crash!

################################ Cortical Areas #################################

## Requests from FEAGI summary of all cortical areas (name, dimensions, 2D/3D location, and visibility)
## Triggers an update in FEAGI Cached cortical areas
## Success emits cortical_area_added, cortical_area_removed, cortical_area_updated depending on situation
func refresh_cortical_areas() -> void:
	print("User requesting cortical area geometry data")
	_feagi_interface.calls.GET_GE_CorticalArea_geometry() # This will afterwards trigger "refresh_connection_list()"

## Requests from FEAGI to send back all details of an EXISTING cortical area
## Success emits cortical_area_updated
func refresh_cortical_area(cortical_area: CorticalArea, polling: bool = false) -> void:
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

func request_add_IOPU_cortical_area(IOPU_template: CorticalTemplate, channel_count: int, coordinates_3D: Vector3i, is_coordinate_2D_defined: bool, coordinates_2D: Vector2i = Vector2(0,0)) -> void:
	print("User requested adding OPU/IPU cortical area")
	if !(IOPU_template.cortical_type  in [CorticalArea.CORTICAL_AREA_TYPE.IPU, CorticalArea.CORTICAL_AREA_TYPE.OPU]):
		push_error("Unable to create non-IPU/OPU area using the request IPU/OPU call!, Skipping!")
		return
	if channel_count < 1:
		push_error("Channel count must be greater than 0 for a IPU/OPU area!, Skipping!")
		return
	_feagi_interface.calls.POST_GE_corticalArea(IOPU_template.ID, IOPU_template.cortical_type, coordinates_3D, is_coordinate_2D_defined, channel_count, coordinates_2D)

func request_membrane_monitoring_status(cortical_area: CorticalArea) -> void:
	print("User requested membrane monitoring state for " + cortical_area.cortical_ID)
	_feagi_interface.calls.GET_MO_neuron_membranePotential(cortical_area.cortical_ID)

func request_synaptic_monitoring_status(cortical_area: CorticalArea) -> void:
	print("User requested synaptic monitoring state for " + cortical_area.cortical_ID)
	_feagi_interface.calls.GET_MO_neuron_synapticPotential(cortical_area.cortical_ID)

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

func request_change_membrane_monitoring_status(cortical_area: CorticalArea, requested_state: bool) -> void:
	print("User requested modification of membrane monitoring state for " + cortical_area.cortical_ID)
	_feagi_interface.calls.POST_MON_neuron_membranePotential(cortical_area.cortical_ID, requested_state)

func request_change_synaptic_monitoring_status(cortical_area: CorticalArea, requested_state: bool) -> void:
	print("User requested modification of synaptic monitoring state for " + cortical_area.cortical_ID)
	_feagi_interface.calls.POST_MON_neuron_synapticPotential(cortical_area.cortical_ID, requested_state)

## Requests FEAGI to delete a cortical area by ID
## if sucessful,  causes the cortical area cache to remove said cortical area, and cached connections to remove connections to/from this area
## Success emits cortical_area_removed, and possibly various morphology_removed
func delete_cortical_area(cortical_id: StringName) -> void:
	print("User requesting cortical area deletion of area " + cortical_id)
	_feagi_interface.calls.DELETE_GE_corticalArea(cortical_id)

################################# Morphologies ##################################

## Requests from FEAGI a dict of all morphologies in the genome and each type.
## Triggers an update in FEAGI Cached morphologies, which cascades to signals for morphologies added / removed
func refresh_morphology_list() -> void:
	print("Use requested refresh of the morphology listing")
	_feagi_interface.calls.GET_MO_list_types()

## Requests the latest info on a specific morphology name
## Success emits morphology_updated
func refresh_morphology_properties(morphology_name: StringName) -> void:
	print("Use requested refresh of properties of morphology " + morphology_name)
	_feagi_interface.calls.GET_GE_morphology(morphology_name)

func get_morphology_usuage(morphology_name: StringName) -> void:
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
func request_delete_morphology(morphology_name: StringName) -> void:
	print("User requested deletion of morphology " + morphology_name)
	if morphology_name not in FeagiCache.morphology_cache.available_morphologies.keys():
		push_error("Attempted to delete morphology %s that not located in cache! Skipping!" % [morphology_name])
		return
	_feagi_interface.calls.DELETE_GE_morphology(morphology_name)

#TODO this should be updated
func request_creating_function_morphology(morphology_name: StringName, parameters: Dictionary) -> void:
	print("Use requested creation of function morphology " + morphology_name)
	_feagi_interface.calls.POST_GE_morphology(morphology_name, Morphology.MORPHOLOGY_TYPE.FUNCTIONS, parameters)

################################## Connections ##################################

## Requests from FEAGI a dict of all conneciton mappings between cortical areas, and the number of mappings per each
## Triggers an update in FEAGI cached connections, which cascades to signals for connections added and removed
## NOTE FOR STARTUP: This should be called after cortical areas have been loaded into memory, otherwise cortical ID references here will be invalid
func refresh_connection_list() -> void:
	_feagi_interface.calls.GET_GE_corticalMap()

## Requests from FEAGI the mapping properties between 2 cortical areas
func get_mapping_properties_between_two_areas(source_area: CorticalArea, destination_area: CorticalArea) -> void:
	_feagi_interface.calls.GET_GE_mappingProperties(source_area.cortical_ID, destination_area.cortical_ID)

## Requese from FEAGI to fully remove the mapping between 2 cortical areas (set the mapping arrays to empty)
func request_delete_mapping_between_corticals(source_area: CorticalArea, destination_area: CorticalArea) -> void:
	print("User Requested Deletion of the connection from cortical area %s toward %s" % [source_area.cortical_ID, destination_area.cortical_ID])
	# This essentially works by sending an empty array for the mappings
	_feagi_interface.calls.PUT_GE_mappingProperties(source_area, destination_area, [])

## Request FEAGI to set a specific mapping between 2 cortical areas
func request_set_mapping_between_corticals(source_area: CorticalArea, destination_area: CorticalArea, mapping_data: MappingProperties) -> void:
	print("User Requested modification of the connection from cortical area %s toward %s" % [source_area.cortical_ID, destination_area.cortical_ID])
	_feagi_interface.calls.PUT_GE_mappingProperties(source_area, destination_area, mapping_data.to_array())

## Request FEAGI to set a default mapping (given a morphology) between 2 cortical areas
func request_default_mapping_between_corticals(source_area: CorticalArea, destination_area: CorticalArea, morphology: Morphology) -> void:
	request_set_mapping_between_corticals(source_area, destination_area, MappingProperties.create_default_mapping(source_area, destination_area, morphology))

################################# FEAGI General #################################

## Get current burst rate
func refresh_delay_between_bursts() -> void:
	_feagi_interface.calls.GET_BU_stimulationPeriod()

## Set a burst rate
func set_delay_between_bursts(delay_between_bursts_in_seconds: float) -> void:
	_feagi_interface.calls.POST_FE_burstEngine(delay_between_bursts_in_seconds)

## Gets the current available circuits of FEAGI
func refresh_available_circuits() -> void:
	_feagi_interface.calls.GET_GE_circuits()

## Retrieves the size of a circuit given a circuit name (include the ''.json')
## On Success, emits signal 'retrieved_circuit_size' in autoload node FEAGIEvents
func get_circuit_size(circuit_name: StringName) -> void:
	if circuit_name not in FeagiCache.available_circuits:
		push_warning("Attempted to get the size of non-cached circuit %s! Skipping! You may want to refresh available circuits first!")
		return
	_feagi_interface.calls.GET_GE_circuitsize(circuit_name)

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

## Calls feagi to retrieve the currently loaded filename. Polls if unavailable. Used to wait for feagi to launch before initializing
## since this method triggers "initial_FEAGI_calls" if there is no genome name cached at all
func get_loaded_genome_name_launch() -> void:
	_feagi_interface.calls.GET_GE_fileName_POLL()
