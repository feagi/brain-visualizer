extends SceneTree
## Classifier plate refresh hookup and Move (3D) monitor lookup exist and parse.
## Run: godot --headless -s res://addons/UI_BrainMonitor/test_classifier_plate_and_move.gd


func _initialize() -> void:
	var failures: int = 0
	failures += _has_method("res://addons/UI_BrainMonitor/UI_BrainMonitor_BrainRegion3D.gd", "_on_region_classifiers_changed")
	failures += _has_method("res://BrainVisualizer/UI/Windows/QuickMenu/WindowQuickMenu.gd", "_find_brain_monitor_up_from")
	if failures == 0:
		print("Classifier plate and move tests: PASS")
		quit(0)
	else:
		push_error("Classifier plate and move tests: FAIL (%d)" % failures)
		quit(1)


func _has_method(path: String, method: String) -> int:
	var script: Script = load(path)
	if script == null or not script.can_instantiate():
		push_error("%s failed to parse" % path)
		return 1
	for m in script.get_script_method_list():
		if m["name"] == method:
			return 0
	push_error("%s lacks %s" % [path, method])
	return 1
