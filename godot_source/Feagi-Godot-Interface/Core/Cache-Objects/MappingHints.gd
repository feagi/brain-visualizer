extends Object
class_name MappingHints
## Stores any hints or restrictions that may occur when mapping 2 cortical areas to each other

enum MAPPING_SPECIAL_CASES {
	ANY_TO_MEMORY,
	MEMORY_TO_ANY,
	MEMORY_TO_MEMORY,
}

## What is allowed to be mapped to what with what morphology names (source -> destination). empty array means anything
## Prioritizes non-UNKNOWN types first, UNKNOWN is used in lieu of "all (others)"
const MORPHOLOGY_RESTRICTIONS: Dictionary = {
	BaseCorticalArea.CORTICAL_AREA_TYPE.UNKNOWN: {
		BaseCorticalArea.CORTICAL_AREA_TYPE.MEMORY: [&"memory"]
		},
	BaseCorticalArea.CORTICAL_AREA_TYPE.MEMORY: {
		BaseCorticalArea.CORTICAL_AREA_TYPE.MEMORY:[&"memory"],
		BaseCorticalArea.CORTICAL_AREA_TYPE.UNKNOWN: [&"projector"]
	}
}

## The default morphology to use when starting a mapping between 2 cortical areas, given cortical area type
## Prioritizes non-UNKNOWN types first, UNKNOWN is used in lieu of "all (others)"
const MORPHOLOGY_DEFAULTS: Dictionary = {
	BaseCorticalArea.CORTICAL_AREA_TYPE.UNKNOWN: {
		BaseCorticalArea.CORTICAL_AREA_TYPE.MEMORY: &"memory",
		BaseCorticalArea.CORTICAL_AREA_TYPE.UNKNOWN: &"projector"
		},
	BaseCorticalArea.CORTICAL_AREA_TYPE.MEMORY: {
		BaseCorticalArea.CORTICAL_AREA_TYPE.MEMORY:&"memory",
		BaseCorticalArea.CORTICAL_AREA_TYPE.UNKNOWN: &"projector"
	}
}

## How many mappings are allowed per connection toa  location (source -> destination). If no reference is made, assume no limitations. -1 means no limit as well
## Prioritizes non-UNKNOWN types first, UNKNOWN is used in lieu of "all (others)".
const MAPPING_COUNT_LIMITS: Dictionary = {
	BaseCorticalArea.CORTICAL_AREA_TYPE.UNKNOWN: {
		BaseCorticalArea.CORTICAL_AREA_TYPE.MEMORY: 1
		},
	BaseCorticalArea.CORTICAL_AREA_TYPE.MEMORY: {
		BaseCorticalArea.CORTICAL_AREA_TYPE.MEMORY: 1,
		BaseCorticalArea.CORTICAL_AREA_TYPE.UNKNOWN: 1
	}
}

## Matches Special Cases to the mapping combination (source -> destination). If no reference is made, assume []
## Prioritizes non-UNKNOWN types first, UNKNOWN is used in lieu of "all (others)".
const MAPPING_CORTICAL_TYPE_SPECIAL_CASES: Dictionary = {
	BaseCorticalArea.CORTICAL_AREA_TYPE.UNKNOWN: {
		BaseCorticalArea.CORTICAL_AREA_TYPE.MEMORY: [MAPPING_SPECIAL_CASES.ANY_TO_MEMORY]
		},
	BaseCorticalArea.CORTICAL_AREA_TYPE.MEMORY: {
		BaseCorticalArea.CORTICAL_AREA_TYPE.MEMORY: [MAPPING_SPECIAL_CASES.ANY_TO_MEMORY, 
			MAPPING_SPECIAL_CASES.MEMORY_TO_ANY, 
			MAPPING_SPECIAL_CASES.MEMORY_TO_MEMORY],
		BaseCorticalArea.CORTICAL_AREA_TYPE.UNKNOWN: [MAPPING_SPECIAL_CASES.MEMORY_TO_ANY]
	}
}
## The default suggested [Morphology] to append when creating a mapping
var default_morphology: Morphology:
	get:
		return _default_morphology
## The [Morphology]s restricted to when mapping 2 cortical areas. If empty then none exist
var restricted_morphologies: Array[Morphology]:
	get:
		return _restricted_morphologies
## The maximum number of mappings to allow between 2 cortical areas. -1 means no limit
var max_number_mappings: int:
	get:
		return _max_number_mappings
## An array of special cases
var special_cases: Array[MAPPING_SPECIAL_CASES]:
	get:
		return _special_cases
## If there are restrictions on morphologies that can be used
var is_morphologies_restricted: bool:
	get:
		return len(_restricted_morphologies) != 0
## If there are restrictions on the number of mappings
var is_number_mappings_restricted: bool:
	get:
		return _max_number_mappings != -1


var _default_morphology: Morphology
var _restricted_morphologies: Array[Morphology]
var _max_number_mappings: int
var _special_cases: Array[MAPPING_SPECIAL_CASES]

## Returns an array of morphologies allowed to be used toward a specific destination cortical area.
## An empty array means there are no restrictions
static func get_allowed_morphologies_to_map_toward(source_cortical_area: BaseCorticalArea, destination_cortical_area: BaseCorticalArea) -> Array[Morphology]:
	var source_type: BaseCorticalArea.CORTICAL_AREA_TYPE = source_cortical_area.group
	var destination_type: BaseCorticalArea.CORTICAL_AREA_TYPE = destination_cortical_area.group
	var acceptable_morphologies_str: Array[StringName] = []
	
	if source_type in MORPHOLOGY_RESTRICTIONS.keys():
		# Source type has specific mapping
		if destination_type in MORPHOLOGY_RESTRICTIONS[source_type]:
			# restriction mapping for specific source found for specific destination
			acceptable_morphologies_str.assign(MORPHOLOGY_RESTRICTIONS[source_type][destination_type])
			return FeagiCache.morphology_cache.attempt_to_get_morphology_arr_from_string_name_arr(acceptable_morphologies_str)
		else:
			acceptable_morphologies_str.assign(MORPHOLOGY_RESTRICTIONS[source_type][BaseCorticalArea.CORTICAL_AREA_TYPE.UNKNOWN])
			return FeagiCache.morphology_cache.attempt_to_get_morphology_arr_from_string_name_arr(acceptable_morphologies_str)
	else:
		# Source type has no specific mapping
		if destination_type in MORPHOLOGY_RESTRICTIONS[BaseCorticalArea.CORTICAL_AREA_TYPE.UNKNOWN]:
			# Destination does have a restriction
			acceptable_morphologies_str.assign(MORPHOLOGY_RESTRICTIONS[BaseCorticalArea.CORTICAL_AREA_TYPE.UNKNOWN][destination_type])
			return FeagiCache.morphology_cache.attempt_to_get_morphology_arr_from_string_name_arr(acceptable_morphologies_str)
		else:
			# No mapping restriction found at all
			var acceptable_morphologies: Array[Morphology] = []
			return acceptable_morphologies

## Returns an array of morphologies allowed to be used toward a specific destination cortical area.
## An empty array means there are no restrictions
static func get_default_morphology_to_map_with(source_cortical_area: BaseCorticalArea, destination_cortical_area: BaseCorticalArea) -> Morphology:
	var source_type: BaseCorticalArea.CORTICAL_AREA_TYPE = source_cortical_area.group
	var destination_type: BaseCorticalArea.CORTICAL_AREA_TYPE = destination_cortical_area.group
	
	if source_type in MORPHOLOGY_DEFAULTS.keys():
		# Source type has specific mapping
		if destination_type in MORPHOLOGY_DEFAULTS[source_type]:
			return FeagiCache.morphology_cache.morphologies[MORPHOLOGY_DEFAULTS[source_type][destination_type]]
		else:
			return FeagiCache.morphology_cache.morphologies[MORPHOLOGY_DEFAULTS[source_type][[BaseCorticalArea.CORTICAL_AREA_TYPE.UNKNOWN]]]
	else:
		# Source type has no specific mapping
		if destination_type in MORPHOLOGY_RESTRICTIONS[BaseCorticalArea.CORTICAL_AREA_TYPE.UNKNOWN]:
			# Destination does have a restriction
			return FeagiCache.morphology_cache.morphologies[MORPHOLOGY_DEFAULTS[BaseCorticalArea.CORTICAL_AREA_TYPE.UNKNOWN][[destination_type]]]
		else:
			# No mapping restriction found at all
			return FeagiCache.morphology_cache.morphologies[MORPHOLOGY_DEFAULTS[BaseCorticalArea.CORTICAL_AREA_TYPE.UNKNOWN][[BaseCorticalArea.CORTICAL_AREA_TYPE.UNKNOWN]]]

## Returns the number of mappings allowed to the destination cortical area
## Returns -1 is there is no limit
static func get_allowed_mapping_count(source_cortical_area: BaseCorticalArea, destination_cortical_area: BaseCorticalArea) -> int:
	var source_type: BaseCorticalArea.CORTICAL_AREA_TYPE = source_cortical_area.group
	var destination_type: BaseCorticalArea.CORTICAL_AREA_TYPE = destination_cortical_area.group

	if source_type in MAPPING_COUNT_LIMITS.keys():
		# Source type has specific mapping
		if destination_type in MAPPING_COUNT_LIMITS[source_type]:
			# restriction mapping for specific source found for specific destination
			return  MAPPING_COUNT_LIMITS[source_type][destination_type]
		else:
			return MAPPING_COUNT_LIMITS[source_type][BaseCorticalArea.CORTICAL_AREA_TYPE.UNKNOWN]
	else:
		# Source type has no specific mapping
		if destination_type in MAPPING_COUNT_LIMITS[BaseCorticalArea.CORTICAL_AREA_TYPE.UNKNOWN]:
			# Destination does have a restriction
			return  MAPPING_COUNT_LIMITS[BaseCorticalArea.CORTICAL_AREA_TYPE.UNKNOWN][destination_type]
		else:
			# No mapping restriction found at all
			return -1

## Returns the special case flag (as ana array since there may be multiple) to the destination cortical area
## Returns [] if none is found
static func get_special_cases_for_mapping_to_destination(source_cortical_area: BaseCorticalArea, destination_cortical_area: BaseCorticalArea) -> Array[MAPPING_SPECIAL_CASES]:
	var source_type: BaseCorticalArea.CORTICAL_AREA_TYPE = source_cortical_area.group
	var destination_type: BaseCorticalArea.CORTICAL_AREA_TYPE = destination_cortical_area.group
	var output: Array[MAPPING_SPECIAL_CASES] = []

	if source_type in MAPPING_CORTICAL_TYPE_SPECIAL_CASES.keys():
		# Source type has specific mapping
		if destination_type in MAPPING_CORTICAL_TYPE_SPECIAL_CASES[source_type]:
			# special case for specific source found for specific destination
			output.assign(MAPPING_CORTICAL_TYPE_SPECIAL_CASES[source_type][destination_type])  
			return output
		else:
			output.assign(MAPPING_CORTICAL_TYPE_SPECIAL_CASES[source_type][BaseCorticalArea.CORTICAL_AREA_TYPE.UNKNOWN])
			return output
	else:
		# Source type has no specific mapping
		if destination_type in MAPPING_CORTICAL_TYPE_SPECIAL_CASES[BaseCorticalArea.CORTICAL_AREA_TYPE.UNKNOWN]:
			# Destination does have a restriction
			output.assign(MAPPING_CORTICAL_TYPE_SPECIAL_CASES[BaseCorticalArea.CORTICAL_AREA_TYPE.UNKNOWN][destination_type])
			return  output
		else:
			# No mapping restriction found at all
			return output

## Is an array of [MappingProperty] valid given a destination area from this source area?
static func is_mapping_property_array_invalid_for_cortical_areas(source_cortical_area: BaseCorticalArea, destination_cortical_area: BaseCorticalArea, mapping_propertys: Array[MappingProperty]) -> bool:
	var limit_on_mapping_count: int = get_allowed_mapping_count(source_cortical_area, destination_cortical_area)
	if limit_on_mapping_count != -1:
		if len(mapping_propertys) > limit_on_mapping_count:
			return true
	
	var restriction_of_morphologies: Array[Morphology] = get_allowed_morphologies_to_map_toward(source_cortical_area, destination_cortical_area)
	if len(restriction_of_morphologies) > 0:
		for mapping: MappingProperty in mapping_propertys:
			if mapping.morphology_used not in restriction_of_morphologies:
				return true
	return false

func _init(source_cortical_area: BaseCorticalArea, destination_cortical_area: BaseCorticalArea) -> void:
	_default_morphology = MappingHints.get_default_morphology_to_map_with(source_cortical_area, destination_cortical_area)
	_restricted_morphologies = MappingHints.get_allowed_morphologies_to_map_toward(source_cortical_area, destination_cortical_area)
	_max_number_mappings = MappingHints.get_allowed_mapping_count(source_cortical_area, destination_cortical_area)
	_special_cases = MappingHints.get_special_cases_for_mapping_to_destination(source_cortical_area, destination_cortical_area)

## Given a set of special cases to be aware of, do any match? If so return an array of matching cases, else return an empty array
func match_any_special_cases(searching_special_cases: Array[MAPPING_SPECIAL_CASES]) -> Array[MAPPING_SPECIAL_CASES]:
	var output: Array[MAPPING_SPECIAL_CASES] = []
	for searching: MAPPING_SPECIAL_CASES in searching_special_cases:
		for known: MAPPING_SPECIAL_CASES in _special_cases:
			if searching == known:
				output.append(known)
	return output

## Given a set of special cases to be aware of, do any match?
func exist_any_matching_special_cases(searching_special_cases: Array[MAPPING_SPECIAL_CASES]) -> bool:
	for searching: MAPPING_SPECIAL_CASES in searching_special_cases:
		for known: MAPPING_SPECIAL_CASES in _special_cases:
			if searching == known:
				return true
	return false


