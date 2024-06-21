extends RefCounted
class_name PartialMappingSet
## When a region is imported from an old genome, external connections are severed. This object stores the memory state of that connection and can serve as a template to make new established mappings.
## Since it is a hint, it cannot be edited, only consumed / destroyed

signal mappings_about_to_be_deleted()

var mappings: Array[SingleMappingDefinition]:
	get: return _mappings

var is_region_input: bool:
	get: return _is_region_input

var internal_target_cortical_area: AbstractCorticalArea:
	get: return _internal_target_cortical_area

var external_target_cortical_area: AbstractCorticalArea:
	get: return _external_target_cortical_area

var custom_label: StringName:
	get: return _custom_label

var number_mappings: int:
	get: return len(_mappings)

var _mappings:  Array[SingleMappingDefinition]
var _is_region_input: bool
var _internal_target_cortical_area: AbstractCorticalArea
var _external_target_cortical_area: AbstractCorticalArea
var _custom_label: StringName

func _init(is_input_of_region: bool, mappings_suggested: Array[SingleMappingDefinition], internal_target: AbstractCorticalArea, external_target: AbstractCorticalArea) -> void:
	_is_region_input = is_input_of_region
	_mappings = mappings_suggested
	_internal_target_cortical_area = internal_target
	_external_target_cortical_area = external_target

static func from_FEAGI_JSON_array(hints: Array[Dictionary], is_input: bool) -> Array[PartialMappingSet]:
	var mappings_collection: Dictionary = {} # Key'd by internal ID -> target ID -> Array[SingleMappingDefinition]
	var internal_key: StringName
	var external_key: StringName
	if is_input:
		internal_key = "dst_cortical_area_id"
		external_key = "src_cortical_area_id"
	else:
		internal_key = "src_cortical_area_id"
		external_key = "dst_cortical_area_id"
	
	for hint in hints:
		var mapping: SingleMappingDefinition = SingleMappingDefinition.from_FEAGI_JSON(hint)
		if !hint[internal_key] in mappings_collection:
			mappings_collection[hint[internal_key]] = {}
		if !hint[external_key] in mappings_collection[hint[internal_key]]:
			var mapping_array: Array[SingleMappingDefinition] = [mapping]
			mappings_collection[hint[internal_key]][hint[external_key]] = mapping_array
		else:
			mappings_collection[hint[internal_key]][hint[external_key]].append(mapping)
	
	var output: Array[PartialMappingSet] = []
	for internal_ID in mappings_collection:
		for external_ID in mappings_collection[internal_ID]:
			var internal: AbstractCorticalArea = FeagiCore.feagi_local_cache.cortical_areas.try_to_get_cortical_area_by_ID(internal_ID)
			var external: AbstractCorticalArea = FeagiCore.feagi_local_cache.cortical_areas.try_to_get_cortical_area_by_ID(external_ID)
			if internal == null or external == null:
				push_error("CORE: Unable to find cortical IDs of %s and %s to generate PartialMappingSet!" % [internal_ID, external_ID])
				continue
			output.append(PartialMappingSet.new(is_input, mappings_collection[internal_ID][external_ID], internal, external ))
	
	return output


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

func get_PSP_signal_type() -> MappingsCache.SIGNAL_TYPE:
	if is_any_PSP_multiplier_negative():
		if is_any_PSP_multiplier_positive():
			return MappingsCache.SIGNAL_TYPE.MIXED
		else:
			return MappingsCache.SIGNAL_TYPE.INHIBITORY
	return MappingsCache.SIGNAL_TYPE.EXCITATORY

