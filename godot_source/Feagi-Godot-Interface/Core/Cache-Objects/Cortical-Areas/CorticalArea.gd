extends Object
class_name CorticalArea
## Holds details pertaining to a specific cortical area
## Signals up if properties here are changed

signal name_updated(cortical_name: StringName, this_cortical_area: CorticalArea)
signal dimensions_updated(dim: Vector3i, this_cortical_area: CorticalArea)
signal coordinates_3D_updated(coords: Vector3i, this_cortical_area: CorticalArea)
signal coordinates_2D_updated(coords: Vector2i, this_cortical_area: CorticalArea)
signal cortical_visibility_updated(visibility: bool, this_cortical_area: CorticalArea)
signal details_updated(data: Dictionary, this_cortical_area: CorticalArea)
signal mappings_updated(mappings: Dictionary)


enum CORTICAL_AREA_TYPE {
	IPU,
	CORE,
	MEMORY,
	CUSTOM,
	OPU
}

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
		dimensions_updated.emit(cortical_ID, v)
		if v == _dimensions: return
		dimensions_updated.emit(v, self)
		_dimensions = v
var coordinates_2D: Vector2i:
	get:
		return _coordinates_2D
	set(v):
		coordinates_2D_updated.emit(cortical_ID, v)
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
		coordinates_3D_updated.emit(cortical_ID, v)
		_coordinates_3D = v
		_coordinates_3D_available = true
		_coordinates_3D_available = true
		if v == _coordinates_3D: return
		coordinates_3D_updated.emit(v, self)
		_coordinates_3D = v
var detailed_mappings: Dictionary

var is_coordinates_2D_available: bool:
	get: return _coordinates_2D_available
var is_coordinates_3D_available: bool:
	get: return _coordinates_3D_available

var _cortical_ID: StringName
var _name: StringName
var _group: CORTICAL_AREA_TYPE
var _dimensions: Vector3i = Vector3i(-1,-1,-1) # invalid default that will be surely changed on init
var _coordinates_2D: Vector2i = Vector2i(0,0)
var _coordinates_3D: Vector3i = Vector3i(0,0,0)
var _coordinates_2D_available: bool = false  # if coordinates_2D are avilable from FEAGI
var _coordinates_3D_available: bool = false  # if coordinates_3D are avilable from FEAGI
var _cortical_visiblity: bool = true
var _mappings: Dictionary = {}

func _init(ID: StringName, cortical_name: StringName, group_type: CORTICAL_AREA_TYPE, visibility: bool, cortical_dimensions: Vector3i, cortical_details_raw: Dictionary = {}):
	_cortical_ID = ID
	_name = cortical_name
	_group = group_type
	details = CorticalAreaDetails.new()
	details.apply_dictionary(cortical_details_raw)
	details.property_changed.connect(_details_updated)
	_dimensions = cortical_dimensions
	_cortical_visiblity = visibility

## Applies cortical area properties dict from feagi on other details
func apply_details_dict(updated_details: Dictionary) -> void:
	details.apply_dictionary(updated_details)
	#_mappingsewf

## Proxy for when the cortical area details changes
func _details_updated(changed_property: Dictionary) -> void:
	details_updated.emit(changed_property, self)


#func _set_mappings()
#