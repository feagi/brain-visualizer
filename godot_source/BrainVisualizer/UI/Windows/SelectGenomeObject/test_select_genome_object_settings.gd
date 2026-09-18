extends SceneTree
## Contract tests for Quick Connect destination explorer settings.
## Mirrors [method SelectGenomeObjectSettings.config_for_multiple_cortical_area_selection]
## without loading FeagiCore autoloads (those are unavailable under `godot -s`).

enum ARRAY_MAKEUP {
	UNKNOWN,
	SINGLE_CORTICAL_AREA,
	SINGLE_BRAIN_REGION,
	MULTIPLE_CORTICAL_AREAS,
	MULTIPLE_BRAIN_REGIONS,
	VARIOUS_GENOME_OBJECTS
}


func _initialize() -> void:
	var failures: int = 0
	failures += _test_multiple_cortical_area_preset_enables_multiselect()
	failures += _test_multiple_cortical_area_preset_keeps_regions_unselectable()
	failures += _test_multiple_cortical_area_preset_keeps_areas_selectable()
	failures += _test_multiple_cortical_area_preset_ignores_null_preselected()
	if failures == 0:
		print("SelectGenomeObjectSettings tests: PASS")
		quit(0)
	else:
		push_error("SelectGenomeObjectSettings tests: FAIL (%d)" % failures)
		quit(1)


func _is_multiselect_allowed(target_type: int) -> bool:
	return target_type in [
		ARRAY_MAKEUP.MULTIPLE_CORTICAL_AREAS,
		ARRAY_MAKEUP.MULTIPLE_BRAIN_REGIONS,
		ARRAY_MAKEUP.VARIOUS_GENOME_OBJECTS,
	]


func _build_multiple_cortical_preset(preselected_including_nulls: Array) -> Dictionary:
	var preselected: Array = []
	for area in preselected_including_nulls:
		if area != null:
			preselected.append(area)
	return {
		"target_type": ARRAY_MAKEUP.MULTIPLE_CORTICAL_AREAS,
		"disable_all_regions": true,
		"disable_all_cortical_areas": false,
		"preselected": preselected,
		"instructions": "Please select one or more destination Cortical Areas:",
	}


func _test_multiple_cortical_area_preset_enables_multiselect() -> int:
	var settings: Dictionary = _build_multiple_cortical_preset([])
	if settings["target_type"] != ARRAY_MAKEUP.MULTIPLE_CORTICAL_AREAS:
		push_error("expected MULTIPLE_CORTICAL_AREAS target type")
		return 1
	if not _is_multiselect_allowed(settings["target_type"]):
		push_error("multi-destination explorer preset must allow multiselect")
		return 1
	if settings["instructions"] == "":
		push_error("explorer preset must include pick instructions")
		return 1
	return 0


func _test_multiple_cortical_area_preset_keeps_regions_unselectable() -> int:
	var settings: Dictionary = _build_multiple_cortical_preset([])
	if settings["disable_all_regions"] != true:
		push_error("circuits must remain expandable but unselectable")
		return 1
	return 0


func _test_multiple_cortical_area_preset_keeps_areas_selectable() -> int:
	var settings: Dictionary = _build_multiple_cortical_preset([])
	if settings["disable_all_cortical_areas"] != false:
		push_error("explorer preset must keep cortical areas selectable")
		return 1
	return 0


func _test_multiple_cortical_area_preset_ignores_null_preselected() -> int:
	var settings: Dictionary = _build_multiple_cortical_preset([null])
	if settings["preselected"].size() != 0:
		push_error("null preselected destinations must be omitted")
		return 1
	return 0
