extends Object
class_name CorticalTemplate


enum STRUCTURE {
	ASYMMETRIC,
	SYMMETRIC
}

var ID: StringName:
	get: return _ID
var is_enabled: bool:
	get: return _is_enabled
var cortical_name: StringName:
	get: return _cortical_name
var structure: STRUCTURE:
	get: return _structure
var resolution: Vector3i:
	get: return _resolution
var cortical_type: BaseCorticalArea.CORTICAL_AREA_TYPE:
	get: return _cortical_type

var _ID: StringName
var _is_enabled: bool
var _cortical_name: StringName
var _structure: STRUCTURE
var _resolution: Vector3i
var _cortical_type: BaseCorticalArea.CORTICAL_AREA_TYPE

func _init(template_ID: StringName, template_enabled: bool, template_name: StringName, structure_name: StringName, resolution_array: Array[int], cortical_reference_type: BaseCorticalArea.CORTICAL_AREA_TYPE) -> void:
	_ID = template_ID
	_is_enabled = template_enabled
	_cortical_name = template_name
	structure = STRUCTURE[structure_name.to_upper()]
	_resolution = FEAGIUtils.array_to_vector3i(resolution_array)
	_cortical_type = cortical_reference_type

## calculates what an IPU or OPU cortical area dimension will be given its source cortical area dimension multiplier and channel count
func calculate_IOPU_dimension(channel_count: int) -> Vector3i:
	var dimension_multiplier: Vector3i = _resolution
	dimension_multiplier.x = dimension_multiplier.x * channel_count
	return dimension_multiplier
