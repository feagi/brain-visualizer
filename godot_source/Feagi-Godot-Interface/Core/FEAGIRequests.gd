extends Node
## AUTOLOADED
## General actions to request of FEAGI
## Try to use the functions here to call feagi actions instead of through FEAGIInterface


var _feagi_interface: FEAGIInterface # MUST be set ASAP externally or the below will crash!

################################ Cortical Areas #################################

## Requests from FEAGI summary of all cortical areas (name, dimensions, 2D/3D location, and visibility)
## Triggers an update in FEAGI Cached cortical areas
## Success emits cortical_area_added, cortical_area_removed, cortical_area_updated depending on situation
func refresh_cortical_areas() -> void:
	_feagi_interface.calls.GET_GE_CorticalArea_geometry() # This will afterwards trigger "refresh_connection_list()"

## Requests from FEAGI to send back all details of an EXISTING cortical area
## Success emits cortical_area_updated
func refresh_cortical_area(ID: StringName) -> void:
	_feagi_interface.calls.GET_GE_corticalArea(ID)

## Requests from FEAGI to add a cortical area using the custom call
## the call returns the FEAGI generated cortical ID
## Success emits cortical_area_added
func add_custom_cortical_area(cortical_name: StringName, coordinates_3D: Vector3i, dimensions: Vector3i, is_coordinate_2D_defined: bool,
	coordinates_2D: Vector2i = Vector2(0,0), cortical_type: CorticalArea.CORTICAL_AREA_TYPE = CorticalArea.CORTICAL_AREA_TYPE.CUSTOM) -> void:

	_feagi_interface.calls.POST_GE_customCorticalArea(cortical_name, coordinates_3D, dimensions, is_coordinate_2D_defined, coordinates_2D, cortical_type)

## Sets the properties of a given cortical area
## MAKE SURE THE DICTIONARY IS FORMATTED CORRECTLY!
## Convert Vectors to arrays, StringNames to Strings
## Success emits cortical_area_updated since this calls "refresh_cortical_area" on success
func set_cortical_area_properties(ID: StringName, formatted_properties_to_set: Dictionary) -> void:
	_feagi_interface.calls.PUT_GE_corticalArea(ID, formatted_properties_to_set)

## Requests FEAGI to delete a cortical area by ID
## if sucessful,  causes the cortical area cache to remove said cortical area, and cached connections to remove connections to/from this area
## Success emits cortical_area_removed, and possibly various morphology_removed
func delete_cortical_area(cortical_id: StringName) -> void:
	_feagi_interface.calls.DELETE_GE_corticalArea(cortical_id)

################################# Morphologies ##################################

## Requests from FEAGI a dict of all morphologies in the genome and each type.
## Triggers an update in FEAGI Cached morphologies, which cascades to signals for morphologies added / removed
func refresh_morphology_list() -> void:
	_feagi_interface.calls.GET_MO_list_types()

## Requests the latest info on a specific morphology name
## Success emits morphology_updated
func refresh_morphology_properties(morphology_name: StringName) -> void:
	_feagi_interface.calls.GET_GE_morphology(morphology_name)

func request_creating_composite_morphology(morphology_name: StringName, source_seed: Vector3i, source_pattern: Array[Vector2i]) -> void:
	var requesting_morphology: Dictionary = {
		"parameters": {
			"src_seed": FEAGIUtils.vector3i_to_array(source_seed),
			"src_pattern": FEAGIUtils.vector2i_array_to_array_of_arrays(source_pattern)
		}
	}
	_feagi_interface.calls.POST_GE_morphology(morphology_name, Morphology.MORPHOLOGY_TYPE.COMPOSITE, requesting_morphology)

func request_creating_vector_morphology(morphology_name: StringName, vectors: Array[Vector3i]) -> void:
	var requesting_morphology: Dictionary = {
		"parameters": {
			"vectors": FEAGIUtils.vector3i_array_to_array_of_arrays(vectors)
		}
	}
	_feagi_interface.calls.POST_GE_morphology(morphology_name, Morphology.MORPHOLOGY_TYPE.VECTORS, requesting_morphology)


func request_creating_function_morphology(morphology_name: StringName, parameters: Dictionary) -> void:
	_feagi_interface.calls.POST_GE_morphology(morphology_name, Morphology.MORPHOLOGY_TYPE.FUNCTIONS, parameters)


func request_creating_pattern_morphology(morphology_name: StringName, patterns: Array[PatternVector3Pairs]) -> void:
	var requesting_morphology: Dictionary = {
		"parameters": {
			"patterns": FEAGIUtils.array_of_PatternVector3Pairs_to_array_of_array_of_array_of_array_of_elements(patterns)
		}
	}
	_feagi_interface.calls.POST_GE_morphology(morphology_name, Morphology.MORPHOLOGY_TYPE.VECTORS, requesting_morphology)


################################## Connections ##################################

## Requests from FEAGI a dict of all conneciton mappings between cortical areas, and the number of mappings per each
## Triggers an update in FEAGI cached connections, which cascades to signals for connections added and removed
## NOTE FOR STARTUP: This should be called after cortical areas have been loaded into memory, otherwise cortical ID references here will be invalid
func refresh_connection_list() -> void:
	_feagi_interface.calls.GET_GE_corticalMap()

#TODO this name should be for general core use, do not use naming conventions for a single UI element
func quick_connect_between_two_corticals(src: String, morphology_name: String, dest: String):
	# docs string section begin
	# src = source, dest = destination, morphology_name = morphology that is selected within quick connect
	# docsstring sectin ends
	if (src != "Click any cortical" and src != "Source") and (dest != "Click any cortical" and dest != "Destination") and morphology_name != "ARROW_PLACEHOLDER" and morphology_name != "ARROW PLACEHOLDER":
		var dst_data = {}
		var combine_url = '?src_cortical_area=#&dst_cortical_area=$'
		combine_url = combine_url.replace("#", src)
		combine_url = combine_url.replace("$", dest)
		dst_data["cortical_destinations"] = {}
		dst_data["cortical_destinations"][src] = []
		var dst = {}
		dst["morphology_id"] = morphology_name
		dst["morphology_scalar"] = [1,1,1]
		dst["postSynapticCurrent_multiplier"] = float(1.0)
		dst["plasticity_flag"] = false
		dst_data["cortical_destinations"][src].append(dst)
		_feagi_interface.calls.PUT_GE_mappingProperties(dst_data["cortical_destinations"][src],combine_url)

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
