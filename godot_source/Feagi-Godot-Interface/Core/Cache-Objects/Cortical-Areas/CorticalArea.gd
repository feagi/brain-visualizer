extends Object
class_name CorticalArea
## Holds details pertaining to a specific cortical area
## Signals up if properties here are changed

enum CORTICAL_AREA_TYPE {
	IPU,
	CORE,
	MEMORY,
	CUSTOM,
	OPU,
	INVALID
}

enum SUPPORTS_INTERFACE {
	NONE,
	IPU,
	OPU
}

const CORTICAL_TYPES_WITH_STATIC_DIMENSIONS: Array[CORTICAL_AREA_TYPE] = [CORTICAL_AREA_TYPE.CORE]

signal name_updated(cortical_name: StringName, this_cortical_area: CorticalArea)
signal dimensions_updated(dim: Vector3i, this_cortical_area: CorticalArea)
signal coordinates_3D_updated(coords: Vector3i, this_cortical_area: CorticalArea)
signal coordinates_2D_updated(coords: Vector2i, this_cortical_area: CorticalArea)
signal cortical_visibility_updated(visibility: bool, this_cortical_area: CorticalArea)
signal details_updated(details: CorticalAreaDetails, this_cortical_area: CorticalArea)
signal changed_monitoring_membrane_potential(is_monitoring: bool)
signal changed_monitoring_synaptic_potential(is_monitoring: bool)

signal efferent_mapping_added(mapping_properties: MappingProperties)
signal efferent_mapping_edited(mapping_properties: MappingProperties)
signal efferent_mapping_removed(mapping_properties: MappingProperties)
signal afferent_mapping_added(mapping_properties: MappingProperties)
signal afferent_mapping_edited(mapping_properties: MappingProperties)
signal afferent_mapping_removed(mapping_properties: MappingProperties)

############# ############# ############# ############# ############# ############# 
############# These values should only be modified by FEAGI directly! ############# 
############# ############# ############# ############# ############# ############# 

var details: CorticalAreaDetails
var cortical_ID: StringName:
	get:
		return _cortical_ID
var name: StringName:
	get:
		return _name
	set(v):
		if v == _name: return
		_name = v
		name_updated.emit(v, self)

var group: CORTICAL_AREA_TYPE:
	get:
		return _group
var cortical_visibility: bool:
	get:
		return _cortical_visiblity
	set(v):
		if v == _cortical_visiblity: return
		_cortical_visiblity = v
		cortical_visibility_updated.emit(v)

var dimensions: Vector3i:
	get:
		return _dimensions
	set(v):
		if v == _dimensions: return
		if is_dimension_not_editable:
			push_error("Unable to update cortical area %s dimensions since it is not editable!" % _cortical_ID)
			return
		dimensions_updated.emit(v, self)
		_dimensions = v
var coordinates_2D: Vector2i:
	get:
		return _coordinates_2D
	set(v):
		_coordinates_2D_available = true
		if v == _coordinates_2D: return
		_coordinates_2D = v
		coordinates_2D_updated.emit(v, self)
var coordinates_3D: Vector3i:
	get:
		return _coordinates_3D
	set(v):
		_coordinates_3D_available = true
		if v == _coordinates_3D: return
		_coordinates_3D = v
		coordinates_3D_updated.emit(v, self)
var is_coordinates_2D_available: bool:
	get: return _coordinates_2D_available
var is_coordinates_3D_available: bool:
	get: return _coordinates_3D_available
var is_monitoring_membrane_potential: bool:
	get: return _is_monitoring_membrane_potential
	set(v):
		_is_monitoring_membrane_potential = v
		changed_monitoring_membrane_potential.emit(v)
var is_monitoring_synaptic_potential: bool:
	get: return _is_monitoring_synaptic_potential
	set(v):
		_is_monitoring_synaptic_potential = v
		changed_monitoring_synaptic_potential.emit(v)
var channel_count: int:
	get: return _channel_count


## All INCOMING connections
var afferent_connections: Array[CorticalArea]:
	get: return _afferent_connections
## All OUTGOING connections
var efferent_connections: Array[CorticalArea]:
	get: return _get_efferents()
var num_afferent_connections: int:
	get: return len(_afferent_connections)
var num_efferent_connections: int:
	get: return len(_get_efferents())

## True if the dimensionality of the cortical area should not be edited by the user
var is_dimension_not_editable: bool:
	get: return _group in CORTICAL_TYPES_WITH_STATIC_DIMENSIONS

var _cortical_ID: StringName
var _name: StringName
var _group: CORTICAL_AREA_TYPE
var _dimensions: Vector3i = Vector3i(-1,-1,-1) # invalid default that will be surely changed on init
var _coordinates_2D: Vector2i = Vector2i(0,0)
var _coordinates_3D: Vector3i = Vector3i(0,0,0)
var _coordinates_2D_available: bool = false  # if coordinates_2D are avilable from FEAGI
var _coordinates_3D_available: bool = false  # if coordinates_3D are avilable from FEAGI
var _cortical_visiblity: bool = true
var _afferent_connections: Array[CorticalArea]
var _efferent_mappings: Dictionary = {} ## Key'd by cortical ID
var _is_monitoring_membrane_potential: bool
var _is_monitoring_synaptic_potential: bool
var _channel_count: int

func _init(ID: StringName, cortical_name: StringName, group_type: CORTICAL_AREA_TYPE, visibility: bool, cortical_dimensions: Vector3i, cortical_details_raw: Dictionary = {}, set_channel_count: int = 0, repress_invalid_warning: bool = false):
	_cortical_ID = ID
	_name = cortical_name
	_group = group_type
	details = CorticalAreaDetails.new()
	details.many_properties_set.connect(_details_updated)
	details.apply_dictionary(cortical_details_raw)
	_dimensions = cortical_dimensions
	_cortical_visiblity = visibility
	_channel_count = set_channel_count
	if repress_invalid_warning:
		return
	if group_type == CORTICAL_AREA_TYPE.INVALID:
		push_error("Generated Cortical Area of ID " + ID + " in is of type Invalid. This may cause issues!")

## Generate a IPU/OPU cortical area when you are using a template
static func create_from_IOPU_template(template: CorticalTemplate, this_cortical_area_ID: StringName, new_channel_count: int, visibility: bool, cortical_details_raw: Dictionary = {}) -> CorticalArea:
	var new_dimensions: Vector3i = template.calculate_IOPU_dimension(new_channel_count)
	return CorticalArea.new(this_cortical_area_ID, template.cortical_name, template.cortical_type, visibility, new_dimensions, cortical_details_raw, new_channel_count)

## Generate a core cortical area when you are using a template
static func create_from_core_template(template: CorticalTemplate, this_cortical_area_ID: StringName, visibility: bool, cortical_details_raw: Dictionary = {}) -> CorticalArea:
	return CorticalArea.new(this_cortical_area_ID, template.cortical_name, template.cortical_type, visibility, template.resolution , cortical_details_raw)

static func cortical_type_str_to_type(cortical_type_raw: String) -> CORTICAL_AREA_TYPE:
	cortical_type_raw = cortical_type_raw.to_upper()
	if cortical_type_raw in CORTICAL_AREA_TYPE.keys():
		return CORTICAL_AREA_TYPE[cortical_type_raw]
	else:
		push_error("Unknown Cortical Type " + cortical_type_raw +". Marking as INVALID!")
		return CORTICAL_AREA_TYPE.INVALID

static func cortical_type_to_str(cortical_type: CORTICAL_AREA_TYPE) -> StringName:
	return CORTICAL_AREA_TYPE.keys()[cortical_type]

## BV uses an alternate space for its coordinates currently, this acts as a translation
static func true_position_to_BV_position(true_position: Vector3, scale: Vector3) -> Vector3:
	return Vector3(
		(int(scale.x / 2.0) + true_position.x),
		(int(scale.y / 2.0) + true_position.y),
		-(int(scale.z / 2.0) + true_position.z))

## Array of Cortical Areas to Array of Cortical IDs
static func CorticalAreaArray2CorticalIDArray(arr: Array[CorticalArea]) -> Array[StringName]:
	var output: Array[StringName] = []
	for area: CorticalArea in arr:
		output.append(area.cortical_ID)
	return output

## Get 3D coordinates that BV uses currently
func BV_position() -> Vector3:
	return CorticalArea.true_position_to_BV_position(coordinates_3D, dimensions)

## Applies cortical area properties dict from feagi on other details
func apply_details_dict(updated_details: Dictionary) -> void:
	details.apply_dictionary(updated_details)

# remember, efferent: e for exit

## SHOULD ONLY BE CALLED FROM FEAGI! Set (create / overwrite / clear) the mappings to a destination area
func set_mappings_to_efferent_area(destination_area: CorticalArea, mappings: Array[MappingProperty]) -> void:

	if !(destination_area.cortical_ID in _efferent_mappings.keys()):
		# we dont have the mappings in the system
		if len(mappings) == 0:
			# A nonexistant mapping was just set to be empty. ignore this
			return
		## Add the mapping
		_efferent_mappings[destination_area.cortical_ID] = MappingProperties.new(self, destination_area, mappings)
		destination_area.add_afferent_area_from_efferent(_efferent_mappings[destination_area.cortical_ID])
		efferent_mapping_added.emit(_efferent_mappings[destination_area.cortical_ID])
		return
	
	if len(mappings) == 0:
		# A previously existing mapping was now emptied. Treat as a deletion
		_efferent_mappings[destination_area.cortical_ID].clear()
		destination_area.remove_afferent_area_from_efferent(_efferent_mappings[destination_area.cortical_ID])
		efferent_mapping_removed.emit(_efferent_mappings[destination_area.cortical_ID])
		_efferent_mappings.erase(destination_area.cortical_ID)
		return
	
	# A previously existing mapping now has new data, treat as an edit
	_efferent_mappings[destination_area.cortical_ID].update_mappings(mappings)
	destination_area.set_afferent_area_from_efferent(_efferent_mappings[destination_area.cortical_ID])
	efferent_mapping_edited.emit(_efferent_mappings[destination_area.cortical_ID])
	print("CORE: CORTICAL_AREA: Set Connection from %s to %s with %d mappings" % [cortical_ID, destination_area.cortical_ID, len(mappings)])

	if _efferent_mappings[destination_area.cortical_ID].is_empty():
		# Delete empty mappings as to not fill dictionary 
		_efferent_mappings.erase(destination_area.cortical_ID)

## ONLY TO BE CALLED FROM THE SOURCE AREA. A source area is connecting towards this area
func add_afferent_area_from_efferent(mapping_properties: MappingProperties) -> void:
	_afferent_connections.append(mapping_properties.source_cortical_area)
	afferent_mapping_edited.emit(mapping_properties)

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
	for efferent_area in _efferent_mappings.values():
		set_mappings_to_efferent_area(efferent_area, empty_mappings)
	


## Retrieves the [MappingProperties] to a cortical area from this one. Returns an empty [MappingProperties] if no connecitons are defined
func get_mappings_to(destination_cortical_area: CorticalArea) -> MappingProperties:
	if destination_cortical_area.cortical_ID not in _efferent_mappings.keys():
		return MappingProperties.create_empty_mapping(self, destination_cortical_area)
	else:
		return _efferent_mappings[destination_cortical_area.cortical_ID]

func get_efferent_connections_with_count() -> Dictionary:
	var output: Dictionary = {}
	for mapping: MappingProperties in _efferent_mappings.values():
		output[mapping.destination_cortical_area.cortical_ID] = mapping.number_mappings
	return output

func _get_efferents() -> Array[CorticalArea]:
	var output: Array[CorticalArea] = []
	for efferent_ID: StringName in _efferent_mappings.keys():
		output.append(FeagiCache.cortical_areas_cache.cortical_areas[efferent_ID])
	return output

func _details_updated() -> void:
	details_updated.emit(details, self)
