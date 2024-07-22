extends RefCounted
class_name RegionMappingSuggestion
## Holds the reccomended mapping for a specific input / output of a region

enum DIRECTION {
	INPUT,
	OUTPUT
}

enum TARGET_TYPE {
	CORTICAL_AREA,
	SUBREGION
}

var name: StringName:
	get: return _name
var mapping_propertys: Array[MappingProperty]:
	get: return _mapping_propertys
var direction: DIRECTION:
	get: return _direction
var target_ID: StringName:
	get: return _target_ID
var target_type: TARGET_TYPE:
	get: return _target_type

var _name: StringName
var _mapping_propertys: Array[MappingProperty] = []
var _direction: DIRECTION
var _target_ID: StringName
var _target_type: TARGET_TYPE

func _init(name_: StringName, suggested_mappings: Array[MappingProperty], 
	target_ID_str: StringName, target_object_type: TARGET_TYPE,  mapping_direction: DIRECTION):
	
	_name = name_
	_mapping_propertys = suggested_mappings
	_target_ID = target_ID_str
	_target_type = target_object_type
	_direction = mapping_direction
	
	## Make sure ID makes sense
	match(_target_type):
		TARGET_TYPE.CORTICAL_AREA:
			if !(_target_ID in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.keys()):
				push_error("CORE CACHE: Region Mapping Suggestion %s is targetting non-cached cortical area %s!" % [_name, _target_ID ])
		TARGET_TYPE.SUBREGION:
			pass # During init, we dont have all the regions yet, so its possible that the ID doesn't exist (yet)

static func from_FEAGI_JSON(dict: Dictionary, target_cortical_area_ID: StringName, target_type: TARGET_TYPE, direction: DIRECTION) -> RegionMappingSuggestion:
	var mappings: Array[MappingProperty] = MappingProperty.from_array_of_dict(dict["mappings"])
	return RegionMappingSuggestion.new(
		dict["name"],
		mappings,
		target_cortical_area_ID,
		target_type,
		direction,
	)
	
