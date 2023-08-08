extends Object
class_name CorticalArea
## Holds details pertaining to a specific cortical area
## Signals up if properties here are changed

signal dimensions_updated(ID: CorticalID, dim: Vector3i)
signal coordinates_3D_updated(ID: CorticalID, coords: Vector3i)
signal coordinates_2D_updated(ID: CorticalID, coords: Vector2i)
signal details_updated(ID: CorticalID, data: Dictionary) # Beware of CorticalMappingProperties


enum CORTICAL_AREA_TYPE {
    IPU,
    CORE,
    MEMORY,
    CUSTOM,
    OPU
}

var cortical_ID: CorticalID:
    get:
        return _cortical_ID
var name: StringName:
    get:
        return _name
var group: CORTICAL_AREA_TYPE:
    get:
        return _group
var details: CorticalAreaDetails
var dimensions: Vector3i:
    get:
        return _dimensions
    set(v):
        dimensions_updated.emit(cortical_ID, v)
        _dimensions = v
var coordinates_2D: Vector2i:
    get:
        return _coordinates_2D
    set(v):
        coordinates_2D_updated.emit(cortical_ID, v)
        _coordinates_2D = v
        _coordinates_2D_available = true
var coordinates_3D: Vector3i:
    get:
        return _coordinates_3D
    set(v):
        coordinates_3D_updated.emit(cortical_ID, v)
        _coordinates_3D = v
        _coordinates_3D_available = true

var _cortical_ID: CorticalID
var _name: StringName
var _group: CORTICAL_AREA_TYPE
var _dimensions: Vector3i = Vector3i(0,0,0)
var _coordinates_2D: Vector2i = Vector2i(0,0)
var _coordinates_3D: Vector3i = Vector3i(0,0,0)
var _coordinates_2D_available: bool = false  # if coordinates_2D are avilable from FEAGI
var _coordinates_3D_available: bool = false  # if coordinates_3D are avilable from FEAGI


func _init(ID: CorticalID, cortical_name: StringName, group_type: CORTICAL_AREA_TYPE, cortical_dimensions: Vector3i = Vector3i(1,1,1),  cortical_details_raw: Dictionary = {}):
    _cortical_ID = ID
    _name = cortical_name
    _group = group_type
    _dimensions = cortical_dimensions
    details = CorticalAreaDetails.new()
    details.apply_dictionary(cortical_details_raw)
    details.property_changed.connect(_details_updated)

## Proxy for when the cortical area details changes
func _details_updated(changed_property: Dictionary) -> void:
    details_updated.emit(cortical_ID, changed_property)