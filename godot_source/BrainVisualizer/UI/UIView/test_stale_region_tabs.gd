extends SceneTree
## After a same-session genome load, region tabs from the previous genome must close.
## Run: godot --headless --path /path/to/godot_source -s res://BrainVisualizer/UI/UIView/test_stale_region_tabs.gd
##
## SceneTree scripts cannot instantiate UITabContainer (autoload BV / FeagiCore).
## These tests cover the genome-ID filter and the split-close decision used by that path.


func _initialize() -> void:
	var failures: int = 0
	failures += _test_keeps_ids_still_in_new_genome()
	failures += _test_drops_ids_from_previous_genome()
	failures += _test_empty_region_id_is_stale()
	failures += _test_lists_missing_open_tab_ids()
	failures += _test_closes_split_when_secondary_tabs_gone()
	failures += _test_keeps_split_when_a_region_tab_remains()
	failures += _test_genome_replace_pipeline_closes_old_tabs_and_split()
	if failures == 0:
		print("Stale region tab tests: PASS")
		quit(0)
	else:
		push_error("Stale region tab tests: FAIL (%d)" % failures)
		quit(1)


func _test_keeps_ids_still_in_new_genome() -> int:
	var available: Dictionary = {&"root": true, &"visual": true}
	if not FEAGIUtils.region_tab_matches_loaded_genome(&"visual", available):
		push_error("A region still in the new genome must keep its tab")
		return 1
	return 0


func _test_drops_ids_from_previous_genome() -> int:
	var available: Dictionary = {&"root": true}
	if FEAGIUtils.region_tab_matches_loaded_genome(&"old_circuit", available):
		push_error("A region from the previous genome must not keep its tab")
		return 1
	return 0


func _test_empty_region_id_is_stale() -> int:
	var available: Dictionary = {&"root": true}
	if FEAGIUtils.region_tab_matches_loaded_genome(&"", available):
		push_error("A tab with no region ID is leftover and must close")
		return 1
	return 0


func _test_lists_missing_open_tab_ids() -> int:
	var open_ids: Array[StringName] = [&"root", &"old_a", &"kept", &"old_b"]
	var available: Dictionary = {&"root": true, &"kept": true}
	var missing: Array[StringName] = FEAGIUtils.region_ids_missing_from_genome(open_ids, available)
	if missing.size() != 2 or missing[0] != &"old_a" or missing[1] != &"old_b":
		push_error("Must list only the open tab IDs that are absent from the new genome")
		return 1
	return 0


func _test_closes_split_when_secondary_tabs_gone() -> int:
	if not FEAGIUtils.should_close_split_after_stale_region_tabs(0):
		push_error("An empty Brain Monitor pane must close the region split")
		return 1
	return 0


func _test_keeps_split_when_a_region_tab_remains() -> int:
	if FEAGIUtils.should_close_split_after_stale_region_tabs(1):
		push_error("A remaining Brain Monitor tab must keep the region split open")
		return 1
	return 0


## Same-session load: leftover region tabs close; the empty Brain Monitor pane closes the split.
func _test_genome_replace_pipeline_closes_old_tabs_and_split() -> int:
	var open_primary: Array[StringName] = [&"root", &"old_circuit"]
	var open_secondary: Array[StringName] = [&"old_circuit"]
	var new_genome: Dictionary = {&"root": true, &"new_circuit": true}
	var stale_primary: Array[StringName] = FEAGIUtils.region_ids_missing_from_genome(open_primary, new_genome)
	var stale_secondary: Array[StringName] = FEAGIUtils.region_ids_missing_from_genome(open_secondary, new_genome)
	if stale_primary.size() != 1 or stale_primary[0] != &"old_circuit":
		push_error("Primary pane must drop only the previous-genome circuit tab")
		return 1
	if stale_secondary.size() != 1 or stale_secondary[0] != &"old_circuit":
		push_error("Secondary pane must drop the previous-genome Brain Monitor tab")
		return 1
	var remaining_secondary: int = open_secondary.size() - stale_secondary.size()
	if not FEAGIUtils.should_close_split_after_stale_region_tabs(remaining_secondary):
		push_error("After the leftover Brain Monitor tab closes, the region split must close")
		return 1
	return 0
