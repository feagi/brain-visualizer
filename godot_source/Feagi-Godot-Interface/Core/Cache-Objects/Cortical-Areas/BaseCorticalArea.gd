extends Object
class_name BaseCorticalArea
## Holds details pertaining to a specific cortical area
## Should not be instantiated directly

# Main functionality for cortical area, and base details such as ID, name, and positions
#region Base Functionality
enum CORTICAL_AREA_TYPE {
	IPU,
	CORE,
	MEMORY,
	CUSTOM,
	OPU,
	INVALID
}

signal about_to_be_deleted(this_cortical_area: BaseCorticalArea)
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
var group: CORTICAL_AREA_TYPE:
	get: 
		return _get_group()

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
		return CORTICAL_AREA_TYPE.INVALID

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
			return CORTICAL_AREA_TYPE.INVALID


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
	about_to_be_deleted.emit(self)
	# [CorticalAreasCache] then deletes this object


# NOTE: This function applies all details, and may be expanded in other cortical types
## Updates all cortical details in here from a dict from FEAGI
func FEAGI_apply_detail_dictionary(data: Dictionary) -> void:
	
	if data == {}:
		return
	are_details_placeholder_data = false # Assuming if ANY data is updated here, that all data here is not placeholders
	# Cortical Parameters
	if "cortical_neuron_per_vox_count" in data.keys(): 
		cortical_neuron_per_vox_count = data["cortical_neuron_per_vox_count"]
	if "cortical_synaptic_attractivity" in data.keys(): 
		cortical_synaptic_attractivity = data["cortical_synaptic_attractivity"]
	
	# Post Synaptic Potential Parameters
	if "neuron_post_synaptic_potential" in data.keys(): 
		neuron_post_synaptic_potential = data["neuron_post_synaptic_potential"]
	if "neuron_post_synaptic_potential_max" in data.keys(): 
		neuron_post_synaptic_potential_max = data["neuron_post_synaptic_potential_max"]
	if "neuron_degeneracy_coefficient" in data.keys(): 
		neuron_degeneracy_coefficient = data["neuron_degeneracy_coefficient"]
	if "neuron_psp_uniform_distribution" in data.keys(): 
		neuron_psp_uniform_distribution = data["neuron_psp_uniform_distribution"]
	if "neuron_mp_driven_psp" in data.keys():
		neuron_mp_driven_psp = data["neuron_mp_driven_psp"]
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
	return CORTICAL_AREA_TYPE.INVALID

func _user_can_edit_dimensions() -> bool:
	return true

func _user_can_edit_name() -> bool:
	return true

func _user_can_delete_area() -> bool:
	return true
#endregion

func _user_can_edit_cortical_neuron_per_vox_count() -> bool:
	return true

func _user_can_edit_cortical_synaptic_attractivity() -> bool:
	return true

func _has_neuron_firing_parameters() -> bool:
	return false

func _has_memory_parameters() -> bool:
	return false

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

signal efferent_mapping_added(mapping_properties: MappingProperties)
signal efferent_mapping_edited(mapping_properties: MappingProperties)
signal efferent_mapping_removed(mapping_properties: MappingProperties)
signal afferent_mapping_added(mapping_properties: MappingProperties)
signal afferent_mapping_edited(mapping_properties: MappingProperties)
signal afferent_mapping_removed(mapping_properties: MappingProperties)

var _afferent_connections: Array[BaseCorticalArea]
var _efferent_mappings: Dictionary = {} ## Key'd by cortical ID

# Mapping Related
## SHOULD ONLY BE CALLED FROM FEAGI! Set (create / overwrite / clear) the mappings to a destination area
func set_mappings_to_efferent_area(destination_area: BaseCorticalArea, mappings: Array[MappingProperty]) -> void:
	
	if !(destination_area.cortical_ID in _efferent_mappings.keys()):
		# we dont have the mappings in the system
		if len(mappings) == 0:
			# A nonexistant mapping was just set to be empty. ignore this
			return
		## Add the mapping
		_efferent_mappings[destination_area.cortical_ID] = MappingProperties.new(self, destination_area, mappings)
		destination_area.add_afferent_area_from_efferent(_efferent_mappings[destination_area.cortical_ID])
		efferent_mapping_added.emit(_efferent_mappings[destination_area.cortical_ID])
		print("CORE: Adding mapping from %s to %s" % [cortical_ID, destination_area.cortical_ID]) 
		return
	
	if len(mappings) == 0:
		# A previously existing mapping was now emptied. Treat as a deletion
		_efferent_mappings[destination_area.cortical_ID].clear()
		destination_area.remove_afferent_area_from_efferent(_efferent_mappings[destination_area.cortical_ID])
		efferent_mapping_removed.emit(_efferent_mappings[destination_area.cortical_ID])
		_efferent_mappings.erase(destination_area.cortical_ID)
		print("CORE: Removing mapping from %s to %s" % [cortical_ID, destination_area.cortical_ID]) 
		return
	
	# A previously existing mapping now has new data, treat as an edit
	_efferent_mappings[destination_area.cortical_ID].update_mappings(mappings)
	destination_area.set_afferent_area_from_efferent(_efferent_mappings[destination_area.cortical_ID])
	efferent_mapping_edited.emit(_efferent_mappings[destination_area.cortical_ID])
	print("CORE: CORTICAL_AREA: Set Connection from %s to %s with %d mappings" % [cortical_ID, destination_area.cortical_ID, len(mappings)])

## ONLY TO BE CALLED FROM THE SOURCE AREA. A source area is connecting towards this area
func add_afferent_area_from_efferent(mapping_properties: MappingProperties) -> void:
	_afferent_connections.append(mapping_properties.source_cortical_area)
	afferent_mapping_added.emit(mapping_properties)

## ONLY TO BE CALLED FROM THE SOURCE AREA. A source area is disconnected towards this area
func remove_afferent_area_from_efferent(mapping_properties: MappingProperties) -> void:
	var index: int = _afferent_connections.find(mapping_properties.source_cortical_area)
	if index == -1:
		# Unable to find source area
		push_warning("CORE: CORTICAL_AREA: Attempted to disconnect afferent cortical area %s from %s when it is already nonexistant in afferent cache!" % 
		[mapping_properties.source_cortical_area.cortical_ID, cortical_ID])
		return
	afferent_mapping_removed.emit(mapping_properties)
	_afferent_connections.remove_at(index)
	
func set_afferent_area_from_efferent(mapping_properties: MappingProperties) -> void:
	var index: int = _afferent_connections.find(mapping_properties.source_cortical_area)
	if index == -1:
		# Unable to find source area
		push_warning("CORE: CORTICAL_AREA: Attempted to edit afferent cortical area %s from %s when is nonexistant in afferent cache!" % 
		[mapping_properties.source_cortical_area.cortical_ID, cortical_ID])
		return
	afferent_mapping_edited.emit(mapping_properties)

## removes all efferent and afferent connections, typically called right before deletion. SHOULD ONLY BE CALLED BY CACHE
func remove_all_connections() -> void:
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
		output.append(FeagiCache.cortical_areas_cache.cortical_areas[efferent_ID])
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

signal neuron_psp_uniform_distribution_updated(new_val: bool, this_cortical_area: BaseCorticalArea)
signal neuron_neuron_mp_driven_psp_updated(new_val: bool, this_cortical_area: BaseCorticalArea)
signal neuron_post_synaptic_potential_updated(new_val: float, this_cortical_area: BaseCorticalArea)
signal neuron_post_synaptic_potential_max_updated(new_val: float, this_cortical_area: BaseCorticalArea)
signal neuron_degeneracy_coefficient_updated(new_val: int, this_cortical_area: BaseCorticalArea)

var neuron_psp_uniform_distribution: bool:
	get:
		return _neuron_psp_uniform_distribution
	set(v):
		_set_neuron_psp_uniform_distribution(v)

var neuron_mp_driven_psp: bool:
	get:
		return _neuron_mp_driven_psp
	set(v):
		_set_neuron_mp_driven_psp(v)

var neuron_post_synaptic_potential: float:
	get:
		return _neuron_post_synaptic_potential
	set(v):
		_set_neuron_post_synaptic_potential(v)

var neuron_post_synaptic_potential_max: float:
	get:
		return _neuron_post_synaptic_potential_max
	set(v):
		_set_neuron_post_synaptic_potential_max(v)

var neuron_degeneracy_coefficient: int:
	get:
		return _neuron_degeneracy_coefficient
	set(v):
		_set_neuron_degeneracy_coefficient(v)

var _neuron_psp_uniform_distribution: bool = false
var _neuron_mp_driven_psp: bool = false
var _neuron_post_synaptic_potential: float = 0.0
var _neuron_post_synaptic_potential_max: float = 0.0
var _neuron_degeneracy_coefficient: int = 0

func _set_neuron_psp_uniform_distribution(new_val: bool) -> void:
	if new_val == _neuron_psp_uniform_distribution: 
		return
	_neuron_psp_uniform_distribution = new_val
	neuron_psp_uniform_distribution_updated.emit(new_val, self)

func _set_neuron_mp_driven_psp(new_val: bool) -> void:
	if new_val == _neuron_mp_driven_psp: 
		return
	neuron_mp_driven_psp = new_val
	neuron_neuron_mp_driven_psp_updated.emit(new_val, self)

func _set_neuron_post_synaptic_potential(new_val: float) -> void:
	if new_val == _neuron_post_synaptic_potential: 
		return
	_neuron_post_synaptic_potential = new_val
	neuron_post_synaptic_potential_updated.emit(new_val, self)

func _set_neuron_post_synaptic_potential_max(new_val: float) -> void:
	if new_val == _neuron_post_synaptic_potential_max: 
		return
	_neuron_post_synaptic_potential_max = new_val
	neuron_post_synaptic_potential_max_updated.emit(new_val, self)

func _set_neuron_degeneracy_coefficient(new_val: int) -> void:
	if new_val == _neuron_degeneracy_coefficient: 
		return
	_neuron_degeneracy_coefficient = new_val
	neuron_degeneracy_coefficient_updated.emit(new_val, self)

#endregion

# Monitoring settings for this specific cortical area
#region Monitoring Settings
var is_monitoring_membrane_potential: bool
var is_monitoring_synaptic_potential: bool
#endregion