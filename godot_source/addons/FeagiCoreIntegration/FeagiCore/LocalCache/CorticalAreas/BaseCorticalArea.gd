extends GenomeObject
class_name BaseCorticalArea
## Holds details pertaining to a specific cortical area
## Should not be instantiated directly

# Main functionality for cortical area, and base details such as ID, name, and positions
#region Base Functionality
## The type of cortical area, not 1-1 mapped with feagi
enum CORTICAL_AREA_TYPE {
	IPU,
	CORE,
	MEMORY,
	CUSTOM,
	OPU,
	UNKNOWN
}

## Any specific flags to be aware of for a cortical area? 
enum CORTICAL_FLAGS {
	EACH_AFFERENT_CONNECTION_MAX_ONE_MAPPING,
	EACH_EFFERENT_CONNECTION_MAX_ONE_MAPPING
}

signal about_to_be_deleted()
signal name_updated(cortical_name: StringName, this_cortical_area: BaseCorticalArea)
signal dimensions_updated(dim: Vector3i, this_cortical_area: BaseCorticalArea)
signal coordinates_3D_updated(coords: Vector3i, this_cortical_area: BaseCorticalArea)
signal coordinates_2D_updated(coords: Vector2i, this_cortical_area: BaseCorticalArea)
signal cortical_visibility_updated(visibility: bool, this_cortical_area: BaseCorticalArea)
signal cortical_neuron_per_vox_count_updated(density: int, this_cortical_area: BaseCorticalArea)
signal cortical_synaptic_attractivity_updated(attractivity: int, this_cortical_area: BaseCorticalArea)
signal changed_monitoring_membrane_potential(is_monitoring: bool)
signal changed_monitoring_synaptic_potential(is_monitoring: bool)


## Unique identifier of the cortical area, generated by FEAGI
var cortical_ID: StringName:
	get:
		return _cortical_ID

## Human readable name of the cortical area. NOT AN IDENTIFIER
var name: StringName:
	get:
		return _name
	set(v):
		_set_name(v)

## The base type of cortical area as understood by FEAGI
var group: CORTICAL_AREA_TYPE: #TODO rename me to type or something
	get: 
		return _get_group()

var type_as_string: StringName:
	get:
		return BaseCorticalArea.cortical_type_to_str(_get_group())

## Is cortical area visible?
var cortical_visibility: bool:
	get:
		return _cortical_visiblity
	set(v):
		_set_cortical_visibility(v)

## XYZ size and structure of the cortical area
var dimensions: Vector3i:
	get:
		return _dimensions
	set(v):
		_set_dimensions(v)

## Used for Circuit Builder
var coordinates_2D: Vector2i:
	get:
		return _coordinates_2D
	set(v):
		_set_2D_coordinates(v)

## Used for Brain Monitor
var coordinates_3D: Vector3i:
	get:
		return _coordinates_3D
	set(v):
		_set_3D_coordinates(v)

var cortical_neuron_per_vox_count: int:
	get:
		return _cortical_neuron_per_vox_count
	set(v):
		_set_cortical_neuron_per_vox_count(v)

var cortical_synaptic_attractivity: int:
	get:
		return _cortical_synaptic_attractivity
	set(v):
		_set_cortical_synaptic_attractivity(v)

var are_details_placeholder_data: bool = true ## We don't have the true values for details yet

## Has a 2D location been specified in FEAGI yet or is still unknown?
var is_coordinates_2D_available: bool:
	get: 
		return _coordinates_2D_available

## Has a 3D location been specified in FEAGI yet or is still unknown?
var is_coordinates_3D_available: bool:
	get: 
		return _coordinates_3D_available

## Can a user edit the name of this cortical area?
var user_can_edit_name: bool:
	get:
		return _user_can_edit_name()

## Can a user edit the dimensions of this cortical area?
var user_can_edit_dimensions: bool:
	get:
		return _user_can_edit_dimensions()

## Can a user edit the dimensions of this cortical area?
var user_can_delete_this_area: bool:
	get:
		return _user_can_delete_area()

var user_can_edit_cortical_neuron_per_vox_count: bool:
	get:
		return _user_can_edit_cortical_neuron_per_vox_count()

var user_can_edit_cortical_synaptic_attractivity: bool:
	get:
		return _user_can_edit_cortical_synaptic_attractivity()

var user_can_clone_this_cortical_area: bool:
	get:
		return _user_can_clone_this_area()

var has_neuron_firing_parameters: bool:
	get: 
		return _has_neuron_firing_parameters()

var has_memory_parameters: bool:
	get:
		return _has_memory_parameters()

# Private Properties
var _cortical_ID: StringName
var _name: StringName
var _dimensions: Vector3i = Vector3i(-1,-1,-1) # invalid default that will be surely changed on init
var _coordinates_2D: Vector2i = Vector2i(0,0)
var _coordinates_3D: Vector3i = Vector3i(0,0,0)
var _cortical_neuron_per_vox_count: int = 1
var _cortical_synaptic_attractivity: int = 100
var _coordinates_2D_available: bool = false  # if coordinates_2D are available from FEAGI
var _coordinates_3D_available: bool = false  # if coordinates_3D are available from FEAGI
var _cortical_visiblity: bool = true

#TODO this shouldn't be here
## BV uses an alternate space for its coordinates currently, this acts as a translation
static func true_position_to_BV_position(true_position: Vector3, scale: Vector3) -> Vector3:
	return Vector3(
		(int(scale.x / 2.0) + true_position.x),
		(int(scale.y / 2.0) + true_position.y),
		-(int(scale.z / 2.0) + true_position.z))

## Array of Cortical Areas to Array of Cortical IDs
static func CorticalAreaArray2CorticalIDArray(arr: Array[BaseCorticalArea]) -> Array[StringName]:
	var output: Array[StringName] = []
	for area: BaseCorticalArea in arr:
		output.append(area.cortical_ID)
	return output

## From a string of cortical type, returns the cortical type enum
static func cortical_type_str_to_type(cortical_type_raw: String) -> CORTICAL_AREA_TYPE:
	cortical_type_raw = cortical_type_raw.to_upper()
	if cortical_type_raw in CORTICAL_AREA_TYPE.keys():
		return CORTICAL_AREA_TYPE[cortical_type_raw]
	else:
		push_error("Unknown Cortical Type " + cortical_type_raw +". Marking as INVALID!")
		return CORTICAL_AREA_TYPE.UNKNOWN

## From a human readable string of cortical type, to cortical type enum
static func cortical_type_human_readable_str_to_type(cortical_type_raw: String) -> CORTICAL_AREA_TYPE:
	cortical_type_raw = cortical_type_raw.to_lower()
	match(cortical_type_raw):
		"input":
			return CORTICAL_AREA_TYPE.IPU
		"output":
			return CORTICAL_AREA_TYPE.OPU
		"core":
			return CORTICAL_AREA_TYPE.CORE
		"interconnect":
			return CORTICAL_AREA_TYPE.CUSTOM
		"memory":
			return CORTICAL_AREA_TYPE.MEMORY
		_:
			return CORTICAL_AREA_TYPE.UNKNOWN


## Given a cortical type enum, return the string
static func cortical_type_to_str(cortical_type: CORTICAL_AREA_TYPE) -> StringName:
	return CORTICAL_AREA_TYPE.keys()[cortical_type]

#TODO this shouldn't be here
## Get 3D coordinates that BV uses currently
func BV_position() -> Vector3:
	return BaseCorticalArea.true_position_to_BV_position(coordinates_3D, dimensions)

## Called from [CorticalAreasCache] when cortical area is being deleted
func FEAGI_delete_cortical_area() -> void:
	remove_all_connections()
	about_to_be_deleted.emit()
	# [CorticalAreasCache] then deletes this object

## Applies every detail from the dictionary from FEAGI
func FEAGI_apply_full_dictionary(data: Dictionary) -> void:
	if data == {}:
		return
	if "cortical_id" not in data.keys():
		push_error("Input dictionary to update cortical area %s is invalid! Skipping!" % _cortical_ID)
		return
	if data["cortical_id"] != _cortical_ID:
		push_error("Input dictionary to update cortical area %s has sent to %s! Skipping!" % [data["cortical_id"], _cortical_ID])
		return
	
	if "cortical_name" in data.keys():
		name = data["cortical_name"]
	if "cortical_visibility" in data.keys():
		cortical_visibility = data["cortical_visibility"]
	if "cortical_dimensions" in data.keys():
		dimensions = FEAGIUtils.array_to_vector3i(data["cortical_dimensions"])
	
	if "coordinates_2d" in data.keys():
		if data["coordinates_2d"][0] == null:
			_coordinates_2D_available = false
		else:
			coordinates_2D = FEAGIUtils.array_to_vector2i(data["coordinates_2d"])

	if "coordinates_3d" in data.keys():
		if data["coordinates_3d"] == null:
			_coordinates_3D_available = false
		else:
			coordinates_3D = FEAGIUtils.array_to_vector3i(data["coordinates_3d"])

	FEAGI_apply_detail_dictionary(data)

# NOTE: This function applies all details (but not base information such as name, visibility, dimensions or positions), and may be expanded in other cortical types
## Updates all cortical details in here from a dict from FEAGI
func FEAGI_apply_detail_dictionary(data: Dictionary) -> void:
	
	are_details_placeholder_data = false # Assuming if ANY data is updated here, that all data here is not placeholders
	# Cortical Parameters
	if "cortical_neuron_per_vox_count" in data.keys(): 
		cortical_neuron_per_vox_count = data["cortical_neuron_per_vox_count"]
	if "cortical_synaptic_attractivity" in data.keys(): 
		cortical_synaptic_attractivity = data["cortical_synaptic_attractivity"]
	
	post_synaptic_potential_paramamters.FEAGI_apply_detail_dictionary(data)

	return

func _set_name(new_name: StringName) -> void:
		if new_name == _name: 
			return
		_name = new_name
		name_updated.emit(new_name, self)

func _set_cortical_visibility(is_visible: bool) -> void:
	if is_visible == _cortical_visiblity:
		return
	_cortical_visiblity = is_visible
	cortical_visibility_updated.emit(_cortical_visiblity, self)
	
func _set_dimensions(new_dimensions: Vector3i) -> void:
		if new_dimensions == _dimensions: 
			return
		_dimensions = new_dimensions
		dimensions_updated.emit(new_dimensions, self)

func _set_2D_coordinates(new_coords: Vector2i) -> void:
	_coordinates_2D_available = true
	if new_coords == _coordinates_2D: 
		return
	_coordinates_2D = new_coords
	coordinates_2D_updated.emit(new_coords, self)

func _set_3D_coordinates(new_coords: Vector3i) -> void:
	_coordinates_3D_available = true
	if new_coords == _coordinates_3D: 
		return
	_coordinates_3D = new_coords
	coordinates_3D_updated.emit(new_coords, self)

func _set_cortical_neuron_per_vox_count(new_density: int) -> void:
	if new_density == _cortical_neuron_per_vox_count:
		return
	_cortical_neuron_per_vox_count = new_density
	cortical_neuron_per_vox_count_updated.emit(new_density, self)

func _set_cortical_synaptic_attractivity(new_attractivity: int) -> void:
	if new_attractivity == _cortical_synaptic_attractivity:
		return
	_cortical_synaptic_attractivity = new_attractivity
	cortical_synaptic_attractivity_updated.emit(new_attractivity, self)

# The following functions are often overridden in child classes
func _get_group() -> CORTICAL_AREA_TYPE:
	## OVERRIDE THIS
	return CORTICAL_AREA_TYPE.UNKNOWN

func _user_can_edit_dimensions() -> bool:
	return true

func _user_can_edit_name() -> bool:
	return true

func _user_can_delete_area() -> bool:
	return true

func _user_can_edit_cortical_neuron_per_vox_count() -> bool:
	return true

func _user_can_edit_cortical_synaptic_attractivity() -> bool:
	return true

func _user_can_clone_this_area() -> bool:
	return false

func _has_neuron_firing_parameters() -> bool:
	return false

func _has_memory_parameters() -> bool:
	return false


#endregion

# Functionality and references to how this cortical area is mapped / connected to other cortical areas
#region Mapping



var afferent_connections: Array[BaseCorticalArea]: ## Incoming cortical area connections
	get: return _afferent_connections
var num_afferent_connections: int: ## Number of incoming cortical area connections
	get: return len(_afferent_connections)
## OUTGOING connections
var efferent_connections: Array[BaseCorticalArea]: ## Outgoing cortical area connections
	get: return _get_efferents()
var efferent_mappings: Dictionary: ## Outgoing cortical area mappings as [MappingProperties], key'd by their cortical ID string
	get: return _efferent_mappings
var num_efferent_connections: int: ## Number of outgoing cortical area connections
	get: return len(_get_efferents())

signal efferent_mapping_retrieved_from_feagi(mapping_properties: MappingProperties)
signal efferent_mapping_added(mapping_properties: MappingProperties)
signal efferent_mapping_edited(mapping_properties: MappingProperties)
signal efferent_mapping_removed(mapping_properties: MappingProperties)
signal afferent_mapping_added(mapping_properties: MappingProperties)
signal afferent_mapping_edited(mapping_properties: MappingProperties)
signal afferent_mapping_removed(mapping_properties: MappingProperties)
signal refreshed_mapping_to_destination(destination: BaseCorticalArea) ## mappings to a destination has changed
signal refreshed_mapping_from_source(source: BaseCorticalArea) ## mappings from a source has changed

var _afferent_connections: Array[BaseCorticalArea]
var _efferent_mappings: Dictionary = {} ## Key'd by cortical ID

# Mapping Related

func is_cortical_area_afferent_to_this_area(possibly_afferent_cortical_area: BaseCorticalArea) -> bool:
	return possibly_afferent_cortical_area in _afferent_connections

func is_cortical_area_efferent_to_this_area(possibly_efferent_cortical_area: BaseCorticalArea) -> bool:
	return possibly_efferent_cortical_area.cortical_ID in _efferent_mappings.keys()

## SHOULD ONLY BE CALLED FROM FEAGI! Set (create / overwrite / clear) the mappings to a destination area
func set_mappings_to_efferent_area(destination_area: BaseCorticalArea, mappings: Array[MappingProperty]) -> void:
	
	var retrieved_mapping_properties = MappingProperties.new(self, destination_area, mappings)
	efferent_mapping_retrieved_from_feagi.emit(retrieved_mapping_properties)
	if !(destination_area.cortical_ID in _efferent_mappings.keys()):
		# we dont have the mappings in the system
		if len(mappings) == 0:
			# A nonexistant mapping was just set to be empty. ignore this
			return
		## Add the mapping
		_efferent_mappings[destination_area.cortical_ID] = retrieved_mapping_properties
		destination_area.add_afferent_area_from_efferent(_efferent_mappings[destination_area.cortical_ID])
		efferent_mapping_added.emit(_efferent_mappings[destination_area.cortical_ID])
		print("FEAGI CACHE: Added mapping from %s to %s containing %s connections" % [cortical_ID, destination_area.cortical_ID, retrieved_mapping_properties.number_mappings]) 
		return
	
	if len(mappings) == 0:
		# A previously existing mapping was now emptied. Treat as a deletion
		_efferent_mappings[destination_area.cortical_ID].mappings_about_to_be_deleted.emit() # Announce deletions from cached [MappingProperties] itself
		efferent_mapping_removed.emit(_efferent_mappings[destination_area.cortical_ID]) # Announce deletion from cortical area
		_efferent_mappings[destination_area.cortical_ID].clear()
		destination_area.remove_afferent_area_from_efferent(_efferent_mappings[destination_area.cortical_ID])
		_efferent_mappings.erase(destination_area.cortical_ID)
		print("FEAGI CACHE: Removed mapping from %s to %s" % [cortical_ID, destination_area.cortical_ID]) 
		return
	
	# A previously existing mapping now has new data, treat as an edit
	_efferent_mappings[destination_area.cortical_ID].update_mappings(mappings)
	destination_area.set_afferent_area_from_efferent(_efferent_mappings[destination_area.cortical_ID])
	efferent_mapping_edited.emit(_efferent_mappings[destination_area.cortical_ID])
	refreshed_mapping_to_destination.emit(destination_area)
	destination_area.refreshed_mapping_from_source.emit(self)
	print("FEAGI CACHE: CORTICAL_AREA: Set Connection from %s to %s with %d mappings" % [cortical_ID, destination_area.cortical_ID, len(mappings)])

## ONLY TO BE CALLED FROM THE SOURCE AREA. A source area is connecting towards this area
func add_afferent_area_from_efferent(mapping_properties: MappingProperties) -> void:
	_afferent_connections.append(mapping_properties.source_cortical_area)
	afferent_mapping_added.emit(mapping_properties)

## ONLY TO BE CALLED FROM THE SOURCE AREA. A source area is disconnected towards this area
func remove_afferent_area_from_efferent(mapping_properties: MappingProperties) -> void:
	var index: int = _afferent_connections.find(mapping_properties.source_cortical_area)
	if index == -1:
		# Unable to find source area
		push_warning("FEAGI CACHE: CORTICAL_AREA: Attempted to disconnect afferent cortical area %s from %s when it is already nonexistant in afferent cache!" % 
		[mapping_properties.source_cortical_area.cortical_ID, cortical_ID])
		return
	afferent_mapping_removed.emit(mapping_properties)
	_afferent_connections.remove_at(index)
	
func set_afferent_area_from_efferent(mapping_properties: MappingProperties) -> void:
	var index: int = _afferent_connections.find(mapping_properties.source_cortical_area)
	if index == -1:
		# Unable to find source area
		push_warning("FEAGI CACHE: CORTICAL_AREA: Attempted to edit afferent cortical area %s from %s when is nonexistant in afferent cache!" % 
		[mapping_properties.source_cortical_area.cortical_ID, cortical_ID])
		return
	afferent_mapping_edited.emit(mapping_properties)

## removes all efferent and afferent connections, typically called right before deletion. SHOULD ONLY BE CALLED BY CACHE
func remove_all_connections() -> void:
	print("FEAGI CACHE: Removing all connections to and from cortical area  %s" % cortical_ID)
	var empty_mappings: Array[MappingProperty] = []
	
	while len(efferent_connections) > 0:
		set_mappings_to_efferent_area(efferent_connections[0], empty_mappings)
	
	while len(afferent_connections) > 0:
		afferent_connections[0].set_mappings_to_efferent_area(self, empty_mappings)
	
## Retrieves the [MappingProperties] to a cortical area from this one. Returns an empty [MappingProperties] if no connecitons are defined
func get_mappings_to(destination_cortical_area: BaseCorticalArea) -> MappingProperties:
	if destination_cortical_area.cortical_ID not in _efferent_mappings.keys():
		return MappingProperties.create_empty_mapping(self, destination_cortical_area)
	else:
		return _efferent_mappings[destination_cortical_area.cortical_ID]

func get_efferent_connections_with_count() -> Dictionary:
	var output: Dictionary = {}
	for mapping: MappingProperties in _efferent_mappings.values():
		output[mapping.destination_cortical_area.cortical_ID] = mapping.number_mappings
	return output

func _get_efferents() -> Array[BaseCorticalArea]:
	var output: Array[BaseCorticalArea] = []
	for efferent_ID: StringName in _efferent_mappings.keys():
		output.append(FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas[efferent_ID])
	return output
	
# The following functions are often overridden in child classes
## What moprphologies are allowed to connect to this cortical area? return empty if no restriction
func get_allowed_afferent_morphology_names() -> PackedStringArray:
	return []

## What moprphologies are allowed to connect from this cortical area? return empty if no restriction
func get_allowed_efferent_morphology_names() -> PackedStringArray:
	return []

#endregion

#region Post Synaptic Potential Parameters

## Holds all post synaptic potential paramamters
var post_synaptic_potential_paramamters: CorticalPropertyPostSynapticPotentialParameters = CorticalPropertyPostSynapticPotentialParameters.new(self)
#endregion

# Monitoring settings for this specific cortical area
#region Monitoring Settings
var is_monitoring_membrane_potential: bool
var is_monitoring_synaptic_potential: bool
#endregion

#region Region information

signal parent_region_changed(old_region: BrainRegion, new_region: BrainRegion)
signal input_link_added(link: ConnectionChainLink)
signal output_link_added(link: ConnectionChainLink)
signal input_link_removed(link: ConnectionChainLink)
signal output_link_removed(link: ConnectionChainLink)

var current_region: BrainRegion:
	get: return _current_region
var input_chain_links: Array[ConnectionChainLink]:
	get: return _input_chain_links
var output_chain_links: Array[ConnectionChainLink]:
	get: return _output_chain_links

var _current_region: BrainRegion
var _input_chain_links: Array[ConnectionChainLink]
var _output_chain_links: Array[ConnectionChainLink]

## The parent region of this cortical area was updated
func FEAGI_changed_parent_region(new_region: BrainRegion):
	var old_cache: BrainRegion = _current_region # yes this method uses more memory but avoids potential shenanigans
	_current_region = new_region
	parent_region_changed.emit(old_cache, new_region)

## Called by [ConnectionChainLink] when it instantiates, adds a reference to that link to this region
func input_add_link(link: ConnectionChainLink) -> void:
	if link in _input_chain_links:
		push_error("CORE CACHE: Unable to add input link to region %s when it already exists!" % name)
		return
	_input_chain_links.append(link)
	input_link_added.emit(link)

## Called by [ConnectionChainLink] when it instantiates, adds a reference to that link to this region
func output_add_link(link: ConnectionChainLink) -> void:
	if link in _output_chain_links:
		push_error("CORE CACHE: Unable to add output link to region %s when it already exists!" % name)
		return
	_output_chain_links.append(link)
	output_link_added.emit(link)

## Called by [ConnectionChainLink] when it is about to be free'd, removes the reference to that link to this region
func input_remove_link(link: ConnectionChainLink) -> void:
	var index: int = _input_chain_links.find(link)
	if index == -1:
		push_error("CORE CACHE: Unable to add remove link from region %s as it wasn't found!" % name)
		return
	_input_chain_links.remove_at(index)
	input_link_removed.emit(link)

## Called by [ConnectionChainLink] when it is about to be free'd, removes the reference to that link to this region
func output_remove_link(link: ConnectionChainLink) -> void:
	var index: int = _output_chain_links.find(link)
	if index == -1:
		push_error("CORE CACHE: Unable to add remove link from region %s as it wasn't found!" % name)
		return
	_output_chain_links.remove_at(index)
	output_link_removed.emit(link)


## Returns the path to this cortical area as a path
func get_region_path() -> Array[BrainRegion]:
	return FeagiCore.feagi_local_cache.brain_regions.get_path_to_cortical_area(self)

#endregion