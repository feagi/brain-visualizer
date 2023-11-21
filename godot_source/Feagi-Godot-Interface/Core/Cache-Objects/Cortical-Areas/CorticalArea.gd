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

signal efferent_mapping_edited(efferent_area: CorticalArea, mapping_properties: MappingProperties, mapping_count: int)
signal efferent_area_removed(efferent_area: CorticalArea)
signal afferent_area_added(afferent_area: CorticalArea)
signal afferent_area_removed(afferent_area: CorticalArea)


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

## SHOULD ONLY BE CALLED FROM FEAGI! Set (create / overwrite) the mappings to a destination area
func set_mappings_to_efferent_area(destination_area: CorticalArea, mappings: Array[MappingProperty]) -> void:
	if len(mappings) == 0:
		remove_mappings_to_efferent_area(destination_area)
		return
	
	if !(destination_area.cortical_ID in _efferent_mappings.keys()):
		_efferent_mappings[destination_area.cortical_ID] = MappingProperties.create_empty_mapping(self, destination_area)
	
	_efferent_mappings[destination_area.cortical_ID].update_mappings(mappings)
	destination_area.afferent_mapping_added(self)

## SHOULD ONLY BE CALLED FROM FEAGI! Remove target cortical area as connection
func remove_mappings_to_efferent_area(destination_area: CorticalArea) -> void:
	if !(destination_area.cortical_ID in _efferent_mappings.keys()):
		push_warning("CORE: CORTICAL_AREA: Attempted to remove cortical area %s to efferent to %s when it is already not there. Skipping!"% [destination_area.cortical_ID, _cortical_ID])
		return
	_efferent_mappings.erase(destination_area.cortical_ID)
	destination_area.afferent_mapping_removed(self)
	efferent_area_removed.emit(destination_area)

## ONLY TO BE CALLED FROM THE EFFERENT AREA. A source area is connected to this cortical area
func afferent_mapping_added(afferent_area: CorticalArea) -> void:
	if afferent_area in _afferent_connections:
		push_warning("CORE: CORTICAL_AREA: Attempted to add cortical area %s to afferent to %s when it is already defined as such. Skipping!"% [afferent_area.cortical_ID, _cortical_ID])
		return
	_afferent_connections.append(afferent_area)
	afferent_area_added.emit(self)

## ONLY TO BE CALLED FROM THE EFFERENT AREA. A source area is disconnected to this cortical area
func afferent_mapping_removed(afferent_area: CorticalArea) -> void:
	var search_index: int = _afferent_connections.find(afferent_area)
	if search_index == -1:
		push_warning("CORE: CORTICAL_AREA: Attempted to remove cortical area %s to afferent to %s when it is already defined as such. Skipping!"% [afferent_area.cortical_ID, _cortical_ID])
		return
	_afferent_connections.remove_at(search_index)
	afferent_area_removed.emit(self)

## removes all efferent and afferent connections, typically called right before deletion. SHOULD ONLY BE CALLED BY CACHE
func remove_all_connections() -> void:
	# remove incoming / afferent
	while len(_afferent_connections) > 0: # Doing a While loop here since the loop below modifies the size of the array
		_afferent_connections[0].remove_mappings_to_efferent_area(self)

	# remove outgoing / efferent
	while len(_efferent_mappings.keys()) != 0:
		var efferent_area: CorticalArea = FeagiCache.cortical_areas_cache.cortical_areas[_efferent_mappings.keys()[0]]
		remove_mappings_to_efferent_area(efferent_area)

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
