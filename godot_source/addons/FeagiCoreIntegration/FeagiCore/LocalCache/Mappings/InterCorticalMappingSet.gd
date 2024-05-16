extends RefCounted
class_name InterCorticalMappingSet
## A set of properties decribing the mapping connection between 2 cortical areas
## NOTE: Is essentially relegated to be created in the cache, not elsewhere

enum SIGNAL_TYPE{
	EXCITATORY,
	INHIBITORY,
	MIXED
}

signal mappings_changed(self_mappings: InterCorticalMappingSet)
signal mappings_about_to_be_deleted()

var source_cortical_area: BaseCorticalArea:
	get: return _src_cortical
var destination_cortical_area: BaseCorticalArea:
	get: return _dst_cortical
var mappings: Array[SingleMappingDefinition]:
	get: return _mappings
var number_mappings: int:
	get: return len(_mappings)
var max_number_mappings_supported: int:
	get: return _max_number_mappings_supported
var morphologies_restricted_to: Array[BaseMorphology]:
	get: return _morphologies_restricted_to
var is_limit_on_mapping_count: bool:
	get: return _max_number_mappings_supported != -1
var is_restriction_on_morphologies_used: bool:
	get: return len(_morphologies_restricted_to) != 0

var _src_cortical: BaseCorticalArea
var _dst_cortical: BaseCorticalArea
var _mappings: Array[SingleMappingDefinition]
var _max_number_mappings_supported: int = -1
var _morphologies_restricted_to: Array[BaseMorphology] = []

## Create Object
func _init(source_area: BaseCorticalArea, destination_area: BaseCorticalArea, mappings_between_them: Array[SingleMappingDefinition]) -> void:
	_src_cortical = source_area
	_dst_cortical = destination_area
	_mappings = mappings_between_them
	_max_number_mappings_supported = MappingHints.get_allowed_mapping_count(source_area, destination_area)
	_morphologies_restricted_to = MappingHints.get_allowed_morphologies_to_map_toward(source_area, destination_area)
	#source_area.parent_region_changed.connect(_proxy_region_change)
	#destination_area.parent_region_changed.connect(_proxy_region_change)

## Create object from FEAGI JSON data
static func from_FEAGI_JSON(mapping_properties_from_FEAGI: Array[Dictionary], source_area: BaseCorticalArea, destination_area: BaseCorticalArea) -> InterCorticalMappingSet:
	var new_mappings: Array[SingleMappingDefinition] = SingleMappingDefinition.from_FEAGI_JSON_array(mapping_properties_from_FEAGI)
	return InterCorticalMappingSet.new(source_area, destination_area, new_mappings)

## FEAGI responded with updated mappings
func FEAGI_updated_mappings(FEAGI_mappings_JSON: Array[Dictionary]) -> void:
	_mappings = SingleMappingDefinition.from_FEAGI_JSON_array(FEAGI_mappings_JSON)
	mappings_changed.emit(self)

## Returns true if any other internal mappings are plastic
func is_any_mapping_plastic() -> bool:
	for mapping: SingleMappingDefinition in _mappings:
		if mapping.is_plastic:
			return true
	return false

## Returns true if any mapping's PSP multiplier is positive
func is_any_PSP_multiplier_positive() -> bool:
	for mapping: SingleMappingDefinition in _mappings:
		if mapping.post_synaptic_current_multiplier > 0.0:
			return true
	return false
 
## Returns true if any mapping's PSP multiplier is negative
func is_any_PSP_multiplier_negative() -> bool:
	for mapping: SingleMappingDefinition in _mappings:
		if mapping.post_synaptic_current_multiplier < 0.0:
			return true
	return false

func is_PSP_multiplers_mixed_sign() -> bool:
	return is_any_PSP_multiplier_negative() and is_any_PSP_multiplier_positive()

func get_PSP_signal_type() -> SIGNAL_TYPE:
	if is_any_PSP_multiplier_negative():
		if is_any_PSP_multiplier_positive():
			return SIGNAL_TYPE.MIXED
		else:
			return SIGNAL_TYPE.INHIBITORY
	return SIGNAL_TYPE.EXCITATORY

## Returns true if the connection maps a cortical area toward itself
func is_recursive() -> bool:
	return source_cortical_area.cortical_ID == destination_cortical_area.cortical_ID

## Returns true if there are no mappings (disconnected), about to be deleted
func is_empty() -> bool:
	return len(_mappings) == 0

## Does mapping follow mapping count and morphology restrictions from cortical areas?
func is_mapping_valid() -> bool:
	return MappingHints.is_mapping_property_array_invalid_for_cortical_areas(_src_cortical, _dst_cortical, _mappings)

## Get Ascending then descending Brain Region Path, ends inclusive of start / stop locations
func get_paths_through_regions() -> Array[Array]:
	return FeagiCore.feagi_local_cache.brain_regions.get_directional_path_between_regions(_src_cortical.current_region, _dst_cortical.current_region)

