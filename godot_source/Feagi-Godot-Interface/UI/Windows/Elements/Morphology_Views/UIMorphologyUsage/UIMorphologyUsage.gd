extends TextEdit
class_name UIMorphologyUsage

var _loaded_morphology: Morphology
var _default_font_size: int
var _default_min_size: Vector2

#signal retrieved_usage(usage_mappings: Array[PackedStringArray], is_being_used: bool, self_reference: Morphology)

func _ready() -> void:
	_default_font_size = get_theme_font_size(&"font_size")
	_default_min_size = custom_minimum_size
	_update_size(VisConfig.UI_manager.UI_scale)
	VisConfig.UI_manager.UI_scale_changed.connect(_update_size)

func load_morphology(morphology: Morphology, request_update_usage_from_feagi: bool = true) -> void:
	if _loaded_morphology != null:
		if _loaded_morphology.retrieved_usage.is_connected(_usage_updated):
			_loaded_morphology.retrieved_usage.disconnect(_usage_updated)
	_loaded_morphology = morphology
	text = _usage_array_to_string(morphology.latest_known_usage_by_cortical_area)
	_loaded_morphology.retrieved_usage.connect(_usage_updated)
	if request_update_usage_from_feagi:
		FeagiRequests.get_morphology_usage(morphology.name)

func clear_morphology() -> void:
	_loaded_morphology = null
	text = ""
	editable = false

func _usage_updated(usage_mappings: Array[PackedStringArray], is_being_used: bool, _self_reference: Morphology) -> void:
	if !is_being_used:
		text = "Morphology not in use!"
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

func _update_size(multiplier: float) -> void:
	add_theme_font_size_override(&"font_size", int(float(_default_font_size) * multiplier))
	custom_minimum_size = _default_min_size * multiplier
	size = Vector2(0,0)
