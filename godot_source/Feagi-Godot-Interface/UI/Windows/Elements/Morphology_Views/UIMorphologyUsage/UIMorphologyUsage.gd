extends TextEdit
class_name UIMorphologyUsage

var _loaded_morphology: Morphology

func load_morphology(morphology: Morphology, request_update_usage_from_feagi: bool = true) -> void:
	if _loaded_morphology != null:
		if _loaded_morphology.retrieved_usage.is_connected(_usage_updated):
			_loaded_morphology.retrieved_usage.disconnect(_usage_updated)
	_loaded_morphology = morphology
	text = _usage_array_to_string(morphology.latest_known_usage_by_cortical_area)
	if request_update_usage_from_feagi:
		FeagiRequests.get_morphology_usage(morphology.name)
	

func clear_morphology() -> void:
	_loaded_morphology = null
	text = ""
	editable = false

func _usage_updated(new_description: StringName, _self_reference: Morphology) -> void:
	text = new_description

## Given usage array is for relevant morphology, formats out a string to show usage
func _usage_array_to_string(usage: Array[PackedStringArray]) -> StringName:
	var output: String = ""
	for single_mapping in usage:
		output = output + _print_since_usage_mapping(single_mapping) + "\n"
	return output

func _print_since_usage_mapping(mapping: PackedStringArray) -> String:
	# each element is an ID
	var output: String = ""

	if mapping[0] in FeagiCache.cortical_areas_cache.cortical_areas.keys():
		output = FeagiCache.cortical_areas_cache.cortical_areas[mapping[0]].name + " -> "
	else:
		push_error("Unable to locate cortical area of ID %s in cache!" % mapping[0])
		output = "UNKNOWN -> "
	
	if mapping[1] in FeagiCache.cortical_areas_cache.cortical_areas.keys():
		output = output + FeagiCache.cortical_areas_cache.cortical_areas[mapping[1]].name
	else:
		push_error("Unable to locate cortical area of ID %s in cache!" % mapping[1])
		output = output + "UNKNOWN"
	return output
