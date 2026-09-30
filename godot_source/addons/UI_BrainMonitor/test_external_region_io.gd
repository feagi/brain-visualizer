extends SceneTree
## Foreign-plate membership: outside partners only, with the existing conflict split.
## Run: godot --headless -s res://addons/UI_BrainMonitor/test_external_region_io.gd

const ExternalRegionIOScript = preload("res://addons/UI_BrainMonitor/ExternalRegionIO.gd")


func _initialize() -> void:
	var failures: int = 0
	failures += _test_plate_script_parses()
	failures += _test_anchor()
	failures += _test_outside_partners_are_split()
	failures += _test_inside_partners_are_excluded()
	failures += _test_conflict_is_removed_from_both_sides()
	if failures == 0:
		print("External region IO tests: PASS")
		quit(0)
	else:
		push_error("External region IO tests: FAIL (%d)" % failures)
		quit(1)


func _test_plate_script_parses() -> int:
	var region_script: Script = load("res://addons/UI_BrainMonitor/UI_BrainMonitor_BrainRegion3D.gd")
	if region_script == null:
		push_error("Brain region plate script failed to parse")
		return 1
	var scene_script: Script = load("res://addons/UI_BrainMonitor/UI_BrainMonitor_3DScene.gd")
	if scene_script == null:
		push_error("Brain monitor scene script failed to parse")
		return 1
	return 0


func _test_anchor() -> int:
	if ExternalRegionIOScript.ANCHOR_FEAGI != Vector3i(-100, 50, 0):
		push_error("External plates must stay anchored at FEAGI (-100, 50, 0)")
		return 1
	return 0


func _test_outside_partners_are_split() -> int:
	var partitioned: Dictionary = ExternalRegionIOScript.partition_partner_ids(
		["inside"],
		{"inside": ["feeder"]},
		{"inside": ["receiver"]},
	)
	if partitioned["inputs"] != ["feeder"]:
		push_error("Outside feeder must land on the input plate")
		return 1
	if partitioned["outputs"] != ["receiver"]:
		push_error("Outside receiver must land on the output plate")
		return 1
	if not (partitioned["conflicts"] as Array).is_empty():
		push_error("One-way partners must not be conflicts")
		return 1
	return 0


func _test_inside_partners_are_excluded() -> int:
	var partitioned: Dictionary = ExternalRegionIOScript.partition_partner_ids(
		["inside", "nested"],
		{"inside": ["nested", "feeder"]},
		{"nested": ["inside"]},
	)
	if partitioned["inputs"] != ["feeder"]:
		push_error("Areas already inside the region must not appear on the plates")
		return 1
	if not (partitioned["outputs"] as Array).is_empty():
		push_error("Links that stay inside the region must not create an output plate area")
		return 1
	return 0


func _test_conflict_is_removed_from_both_sides() -> int:
	var partitioned: Dictionary = ExternalRegionIOScript.partition_partner_ids(
		["inside"],
		{"inside": ["both", "feeder"]},
		{"inside": ["both"]},
	)
	if partitioned["conflicts"] != ["both"]:
		push_error("An outside area that feeds and is fed must be a conflict")
		return 1
	if partitioned["inputs"] != ["feeder"]:
		push_error("Conflict areas must leave the input plate")
		return 1
	if not (partitioned["outputs"] as Array).is_empty():
		push_error("Conflict areas must leave the output plate")
		return 1
	return 0
