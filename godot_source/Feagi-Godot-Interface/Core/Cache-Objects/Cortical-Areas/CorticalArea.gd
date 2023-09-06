extends Object
class_name CorticalArea
## Holds details pertaining to a specific cortical area
## Signals up if properties here are changed


enum CORTICAL_AREA_TYPE {
	IPU,
	CORE,
	MEMORY,
	CUSTOM,
	OPU
}


signal name_updated(cortical_name: StringName, this_cortical_area: CorticalArea)
signal dimensions_updated(dim: Vector3i, this_cortical_area: CorticalArea)
signal coordinates_3D_updated(coords: Vector3i, this_cortical_area: CorticalArea)
signal coordinates_2D_updated(coords: Vector2i, this_cortical_area: CorticalArea)
signal cortical_visibility_updated(visibility: bool, this_cortical_area: CorticalArea)
signal specific_detail_updated(data: Dictionary, this_cortical_area: CorticalArea)
signal many_details_set(this_cortical_area: CorticalArea)

signal efferent_area_added(efferent_area: CorticalArea)

signal efferent_area_removed(efferent_area: CorticalArea)

signal efferent_area_count_updated(efferent_area: CorticalArea, mapping_count: int)

signal efferent_mapping_updated(efferent_area: CorticalArea, mapping_properties: MappingProperties)

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

var dimensions: Vector3i:
	get:
		return _dimensions
	set(v):
		if v == _dimensions: return
		dimensions_updated.emit(v, self)
		_dimensions = v
var coordinates_2D: Vector2i:
	get:
		return _coordinates_2D
	set(v):
		_coordinates_2D = v
		_coordinates_2D_available = true
		_coordinates_2D_available = true
		if v == _coordinates_2D: return
		coordinates_2D_updated.emit(v, self)
		_coordinates_2D = v
var coordinates_3D: Vector3i:
	get:
		return _coordinates_3D
	set(v):
		_coordinates_3D = v
		_coordinates_3D_available = true
		_coordinates_3D_available = true
		if v == _coordinates_3D: return
		coordinates_3D_updated.emit(v, self)
		_coordinates_3D = v
var is_coordinates_2D_available: bool:
	get: return _coordinates_2D_available
var is_coordinates_3D_available: bool:
	get: return _coordinates_3D_available
## All INCOMING connections
var afferent_connections: Array[StringName]:
	get: return _afferent_connections
## All OUTGOING connections (with number of mappings)
var efferent_connections_with_count: Dictionary:
	get: return _efferent_connections_with_count
## All OUTGOING connections (with mapping data per connection)
var efferent_mappings: Dictionary:
	get: return _efferent_mappings

var _cortical_ID: StringName
var _name: StringName
var _group: CORTICAL_AREA_TYPE
var _dimensions: Vector3i = Vector3i(-1,-1,-1) # invalid default that will be surely changed on init
var _coordinates_2D: Vector2i = Vector2i(0,0)
var _coordinates_3D: Vector3i = Vector3i(0,0,0)
var _coordinates_2D_available: bool = false  # if coordinates_2D are avilable from FEAGI
var _coordinates_3D_available: bool = false  # if coordinates_3D are avilable from FEAGI
var _cortical_visiblity: bool = true
## All afferent cortical areas refrences by cortical ID
var _afferent_connections: Array[StringName]
## Add efferent cortical areas refrenced by cortical ID as keys with values being mapping count
var _efferent_connections_with_count: Dictionary
var _efferent_mappings: Dictionary = {}

func _init(ID: StringName, cortical_name: StringName, group_type: CORTICAL_AREA_TYPE, visibility: bool, cortical_dimensions: Vector3i, cortical_details_raw: Dictionary = {}):
	_cortical_ID = ID
	_name = cortical_name
	_group = group_type
	details = CorticalAreaDetails.new()
	details.apply_dictionary(cortical_details_raw)
	details.property_changed.connect(_specific_detail_updated)
	details.many_properties_set.connect(_many_details_set)
	_dimensions = cortical_dimensions
	_cortical_visiblity = visibility

## Applies cortical area properties dict from feagi on other details
func apply_details_dict(updated_details: Dictionary) -> void:
	details.apply_dictionary(updated_details)
	#_mappingsewf

# remember, efferent: e for exit

## way for incoming cortical areas to declare themselves as such. DOES NOT TAKE CARE OF REVERSE DEFINITION, ONLY CALL IF YOU UNDERSTAND WHAT THIS MEANS
func set_afferent_connection(incoming_cortical_area: CorticalArea) -> void:
	if incoming_cortical_area.cortical_ID in _afferent_connections:
		push_warning("attempted to add cortical area %s to afferent to %s when it is already defined as such. Skipping!"% [incoming_cortical_area.cortical_ID, _cortical_ID])
		return
	_afferent_connections.append(incoming_cortical_area.cortical_ID)
	efferent_area_added.emit(incoming_cortical_area)

## way for incoming cortical areas to remove themselves as such. DOES NOT TAKE CARE OF REVERSE DEFINITION, ONLY CALL IF YOU UNDERSTAND WHAT THIS MEANS
func remove_afferent_connection(incoming_cortical_area: CorticalArea) -> void:
	var index: int =  _afferent_connections.find(incoming_cortical_area.cortical_ID)
	if index == -1:
		push_warning("attempted to remove cortical area %s to afferent to %s when it is already not there. Skipping!"% [incoming_cortical_area.cortical_ID, _cortical_ID])
		return
	_afferent_connections.remove_at(index)
	efferent_area_removed.emit(incoming_cortical_area)

## add / update target cortex as connection
func set_efferent_connection(target_cortical_area: CorticalArea, mapping_count: int) -> void:
	if target_cortical_area.cortical_ID not in _efferent_connections_with_count.keys():
		afferent_area_added.emit(target_cortical_area)
	_efferent_connections_with_count[target_cortical_area.cortical_ID] = mapping_count
	efferent_area_count_updated.emit(target_cortical_area)
	# handle afferent call on the other cortical area
	target_cortical_area.set_afferent_connection(self)

## remove target cortex as connection
func remove_efferent_connection(target_cortical_area: CorticalArea) -> void:
	if target_cortical_area.cortical_ID not in _efferent_connections_with_count.keys():
		push_warning("attempted to remove cortical area %s to efferent to %s when it is already not there. Skipping!"% [target_cortical_area.cortical_ID, _cortical_ID])
		return
	_efferent_connections_with_count.erase(target_cortical_area.cortical_ID)
	afferent_area_removed.emit(target_cortical_area)
	# handle afferent call on the other cortical area
	target_cortical_area.remove_afferent_connection(self)

## removes all efferent and afferent connections, typically called right before deletion
func remove_all_connections() -> void:
	# remove incoming
	for afferent in _afferent_connections:
		remove_afferent_connection(FeagiCache.cortical_areas_cache[afferent])
	
	# remove outgoing
	for efferent in _efferent_connections_with_count.keys():
		remove_efferent_connection(FeagiCache.cortical_areas_cache[efferent])

## replaced cortical mapping properties to a efferent cortical location from here
func set_efferent_mapping_properties_from_FEAGI(properties: MappingProperties, target_cortical_area: CorticalArea) -> void:
	_efferent_mappings[target_cortical_area.cortical_ID] = properties
	if properties.number_of_mappings == 0 and target_cortical_area.cortical_ID in _efferent_connections_with_count.keys():
		# A mapping with zero elements means theres no connection. Delete any connection if it exists!
		remove_efferent_connection(target_cortical_area)
	if properties.number_of_mappings != 0 and target_cortical_area.cortical_ID not in _efferent_connections_with_count.keys():
		# A mapping with a number of mappings is a connection. Create a connection if one doesnt exist!
		set_efferent_connection(target_cortical_area, properties.number_of_mappings)

	efferent_mapping_updated.emit(target_cortical_area, properties)
	

## Proxy for when the cortical area details changes
func _specific_detail_updated(changed_property: Dictionary) -> void:
	specific_detail_updated.emit(changed_property, self)

## proxy for when many cortical area details change (usually from FEAGI)
func _many_details_set() -> void:
	many_details_set.emit(self)
