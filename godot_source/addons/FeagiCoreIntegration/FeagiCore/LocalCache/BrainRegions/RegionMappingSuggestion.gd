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

func _init(name_: StringName, suggested_mappings: Array[MappingProperty], 
	inner_target_cortical_area_ID: StringName, mapping_direction: DIRECTION):
	
	_name = name_
	_mapping_propertys = suggested_mappings
	_target_area_ID = inner_target_cortical_area_ID
	if !(_target_area_ID in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.keys()):
		push_error("CORE CACHE: Region Mapping Suggestion %s is targetting non-cached cortical area %s!" % [_name, _target_area_ID ])
	_direction = mapping_direction

static func from_FEAGI_JSON(dict: Dictionary, target_cortical_area_ID: StringName, direction: DIRECTION) -> RegionMappingSuggestion:
	var mappings: Array[MappingProperty] = MappingProperty.from_array_of_dict(dict["mappings"])
	return RegionMappingSuggestion.new(
		dict["name"],
		mappings,
		target_cortical_area_ID,
		direction
	)
	
