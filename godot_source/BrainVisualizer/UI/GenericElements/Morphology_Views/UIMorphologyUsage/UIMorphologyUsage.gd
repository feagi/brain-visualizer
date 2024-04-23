extends TextEdit
class_name UIMorphologyUsage

var _loaded_morphology: BaseMorphology

func load_morphology(morphology: BaseMorphology) -> void:
	if _loaded_morphology != null:
		if _loaded_morphology.retrieved_usage.is_connected(_usage_updated):
			_loaded_morphology.retrieved_usage.disconnect(_usage_updated)
	_loaded_morphology = morphology
	text = _usage_array_to_string(morphology.latest_known_usage_by_cortical_area)
	_loaded_morphology.retrieved_usage.connect(_usage_updated)

func clear_morphology() -> void:
	_loaded_morphology = null
	text = ""
	editable = false

func _usage_updated(usage_mappings: Array[PackedStringArray], is_being_used: bool, _self_reference: BaseMorphology) -> void:
	if !is_being_used:
		text = "Connectivity rule not in use!"
		return
	text = _usage_array_to_string(usage_mappings)


## Given usage array is for relevant morphology, formats out a string to show usage
func _usage_array_to_string(usage: Array[PackedStringArray]) -> StringName:
	var output: String = ""
	for single_mapping in usage:
		output = output + _print_since_usage_mapping(single_mapping) + "\n"
	return output

func _print_since_usage_mapping(mapping: PackedStringArray) -> String:
	# each element is an ID
	var output: String = ""

	if mapping[0] in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.keys():
		output = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas[mapping[0]].name + " -> "
	else:
		push_error("Unable to locate cortical area of ID %s in cache!" % mapping[0])
		output = "UNKNOWN -> "
	
	if mapping[1] in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.keys():
		output = output + FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas[mapping[1]].name
	else:
		push_error("Unable to locate cortical area of ID %s in cache!" % mapping[1])
		output = output + "UNKNOWN"
	return output
