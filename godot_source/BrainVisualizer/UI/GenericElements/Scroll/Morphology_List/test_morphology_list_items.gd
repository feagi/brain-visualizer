extends SceneTree
## Connectivity rule hover list uses the manager's left-list rows.
## Does not reference MorphologyScroll at parse time (BV autoload is not ready yet).
## Run: godot --headless -s res://BrainVisualizer/UI/GenericElements/Scroll/Morphology_List/test_morphology_list_items.gd

const SCROLL_SCRIPT_PATH := "res://BrainVisualizer/UI/GenericElements/Scroll/Morphology_List/MorphologyScroll.gd"


func _initialize() -> void:
	var failures: int = 0
	failures += _test_items_match_manager_order()
	failures += _test_top_bar_reuses_category_hover_list()
	if failures == 0:
		print("Morphology list item tests: PASS")
		quit(0)
		return
	push_error("Morphology list item tests: FAIL (%d)" % failures)
	quit(1)


func _test_items_match_manager_order() -> int:
	var scroll_script: Script = load(SCROLL_SCRIPT_PATH)
	if scroll_script == null:
		push_error("MorphologyScroll failed to compile")
		return 1
	var zebra := BaseMorphology.new(&"Zebra", true, BaseMorphology.MORPHOLOGY_INTERNAL_CLASS.CORE)
	var alpha := BaseMorphology.new(&"alpha", true, BaseMorphology.MORPHOLOGY_INTERNAL_CLASS.CUSTOM)
	var cache: Dictionary = {
		&"Zebra": zebra,
		&"alpha": alpha,
		&"missing": null,
	}
	var items: Array = scroll_script.call("items_from_morphology_map", cache)
	if items.size() != 2:
		push_error("Connectivity rule list must skip missing entries")
		return 1
	if String(items[0].get("label", "")) != "alpha" or items[0].get("payload") != alpha:
		push_error("Connectivity rule list must sort names the same way as the manager")
		return 1
	if String(items[1].get("label", "")) != "Zebra" or items[1].get("payload") != zebra:
		push_error("Connectivity rule list must keep the morphology object as the row payload")
		return 1
	var source := FileAccess.get_file_as_string(SCROLL_SCRIPT_PATH)
	if source.find("items_from_morphology_map(FeagiCore") < 0:
		push_error("The manager list must build rows from items_from_morphology_map")
		return 1
	return 0


func _test_top_bar_reuses_category_hover_list() -> int:
	var top_bar := FileAccess.get_file_as_string("res://BrainVisualizer/UI/Top_Bar/TopBar.gd")
	if top_bar.find("attach_category_list_hover") < 0 or top_bar.find("open_category_list") < 0:
		push_error("Connectivity Rules must open through the shared category hover list")
		return 1
	if top_bar.find("items_from_morphology_map") < 0 or top_bar.find("spawn_manager_morphology(morphology)") < 0:
		push_error("Selecting a connectivity rule must open the manager on that rule")
		return 1
	var scene := FileAccess.get_file_as_string("res://BrainVisualizer/UI/Top_Bar/TopBar.tscn")
	if scene.find("_open_neuron_morphologies") >= 0:
		push_error("Connectivity Rules title must not open the manager before a rule is chosen")
		return 1
	return 0
