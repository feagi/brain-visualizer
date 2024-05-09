extends RefCounted
class_name RegionMappingSuggestion
## Holds the reccomended mapping for a specific input / output of a region

enum DIRECTION {
	INPUT,
	OUTPUT
}

var name: StringName:
	get: return _name
var mapping_propertys: Array[MappingProperty]:
	get: return _mapping_propertys
var direction: DIRECTION:
	get: return _direction
var target_area_ID: StringName:
	get: return _target_area_ID

var _name: StringName
var _mapping_propertys: Array[MappingProperty] = []
var _direction: DIRECTION
var _target_area_ID: StringName
