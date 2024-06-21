extends RefCounted
class_name PartialMappingPrecursor
## While loading a new region, does some of the work to make a [PartialMapping] object, however we make this intermediate object as we are waiting for region internals (particuarly cortical areas) to be added

var mappings: Array[SingleMappingDefinition]:
	get: return _mappings

var is_region_input: bool:
	get: return _is_region_input

var internal_target_cortical_area_ID: StringName:
	get: return _internal_target_cortical_area_ID

var external_target_cortical_area_ID: StringName:
	get: return _external_target_cortical_area_ID

var custom_label: StringName:
	get: return _custom_label

var _mappings:  Array[SingleMappingDefinition]
var _is_region_input: bool
var _internal_target_cortical_area_ID: StringName
var _internal_target_cortical_area_Name: StringName
var _external_target_cortical_area_ID: StringName
var _custom_label: StringName

func _init(is_input_of_region: bool, mappings_suggested: Array[SingleMappingDefinition], internal_target_ID: StringName, external_target_ID: StringName) -> void:
	_is_region_input = is_input_of_region
	_mappings = mappings_suggested
	_internal_target_cortical_area_ID = internal_target_ID
	_external_target_cortical_area_ID = external_target_ID

static func from_FEAGI_JSON_array(hints: Array[Dictionary], is_input: bool) -> Array[PartialMappingPrecursor]:
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
	
	var output: Array[PartialMappingPrecursor] = []
	for internal_ID in mappings_collection:
		for external_ID in mappings_collection[internal_ID]:
			output.append(PartialMappingPrecursor.new(is_input, mappings_collection[internal_ID][external_ID], internal_ID, external_ID ))
	
	return output
		
