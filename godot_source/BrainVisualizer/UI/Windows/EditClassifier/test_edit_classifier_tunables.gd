extends SceneTree
## Edit Classifier tunable expander contract.
## Avoids instantiating WindowEditClassifier (BaseDraggableWindow needs BV autoload).
## Run: godot --headless --path godot_source -s res://BrainVisualizer/UI/Windows/EditClassifier/test_edit_classifier_tunables.gd

const Tunables = preload("res://BrainVisualizer/UI/Windows/EditClassifier/EditClassifierTunables.gd")


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var failures: int = 0
	failures += _test_three_section_titles()
	failures += _test_memory_keys_match_cortical_details()
	failures += _test_associative_keys()
	failures += _test_memory_payload_filters_unknown_keys()
	failures += _test_associative_overrides_keep_existing_rule()
	failures += _test_collapsible_prefab_matches_cortical_details()
	failures += _test_toggle_ignores_source_texture_size()
	failures += _test_window_fits_content_inside_available_height()
	failures += _test_memory_count_matches_cortical_details()
	failures += _test_numeric_defaults_are_one()
	if failures == 0:
		print("Edit classifier tunable tests: PASS")
		quit(0)
	else:
		push_error("Edit classifier tunable tests: FAIL (%d)" % failures)
		quit(1)


func _test_three_section_titles() -> int:
	var titles: PackedStringArray = Tunables.section_titles()
	if titles.size() != 3:
		push_error("edit classifier must have exactly three tunable sections")
		return 1
	if titles[0] != "Kernel Memory Area":
		push_error("first section must be Kernel Memory Area")
		return 1
	if titles[1] != "Class Memory Area":
		push_error("second section must be Class Memory Area")
		return 1
	if titles[2] != "Associative Memory Parameters":
		push_error("third section must be Associative Memory Parameters")
		return 1
	return 0


func _test_memory_keys_match_cortical_details() -> int:
	var keys: PackedStringArray = Tunables.memory_feagi_keys()
	for required in ["neuron_init_lifespan", "neuron_lifespan_growth_rate", "neuron_longterm_mem_threshold", "temporal_depth", "mp_learning_enabled"]:
		if not keys.has(required):
			push_error("memory section missing cortical-details key %s" % required)
			return 1
	if keys.has("neuron_fire_threshold") or keys.has("cortical_id"):
		push_error("memory sections must not expose class-input firing keys")
		return 1
	return 0


func _test_associative_keys() -> int:
	var keys: PackedStringArray = Tunables.associative_feagi_keys()
	for required in ["plasticity_window", "plasticity_constant", "ltp_multiplier", "ltd_multiplier"]:
		if not keys.has(required):
			push_error("associative section missing key %s" % required)
			return 1
	if keys.has("morphology_id") or keys.has("morphology_scalar"):
		push_error("associative tunables must not retarget morphology structure")
		return 1
	return 0


func _test_memory_payload_filters_unknown_keys() -> int:
	var payload: Dictionary = Tunables.memory_update_payload({
		"neuron_init_lifespan": 40,
		"temporal_depth": 3,
		"cortical_id": "should-drop",
		"neuron_fire_threshold": 99,
	})
	if payload.get("neuron_init_lifespan", 0) != 40:
		push_error("payload must keep lifespan")
		return 1
	if payload.get("temporal_depth", 0) != 3:
		push_error("payload must keep temporal_depth")
		return 1
	if payload.has("cortical_id") or payload.has("neuron_fire_threshold"):
		push_error("payload must drop non-memory keys")
		return 1
	return 0


func _test_associative_overrides_keep_existing_rule() -> int:
	var existing: Dictionary = {
		"morphology_id": "associative_memory",
		"morphology_scalar": [1, 1, 1],
		"postSynapticCurrent_multiplier": 1.0,
		"plasticity_flag": true,
		"plasticity_constant": 1.0,
		"ltp_multiplier": 1.0,
		"ltd_multiplier": 1.0,
		"plasticity_window": 3,
		"synaptic_delay_bursts": 1,
	}
	var patched: Dictionary = Tunables.apply_associative_overrides(existing, {
		"plasticity_window": 7,
		"plasticity_constant": 0.5,
		"ltp_multiplier": 1.2,
		"ltd_multiplier": 0.8,
	})
	if patched.get("morphology_id", "") != "associative_memory":
		push_error("associative apply must keep morphology_id")
		return 1
	if patched.get("synaptic_delay_bursts", 0) != 1:
		push_error("associative apply must keep structural mapping fields")
		return 1
	if int(patched.get("plasticity_window", 0)) != 7:
		push_error("associative apply must write plasticity_window")
		return 1
	if float(patched.get("plasticity_constant", 0.0)) != 0.5:
		push_error("associative apply must write plasticity_constant")
		return 1
	if not bool(patched.get("plasticity_flag", false)):
		push_error("associative apply must keep plasticity on")
		return 1
	return 0


func _test_collapsible_prefab_matches_cortical_details() -> int:
	var prefab: PackedScene = load("res://BrainVisualizer/UI/GenericElements/Collapsable/VerticalCollapsibleHiding.tscn")
	if prefab == null:
		push_error("VerticalCollapsibleHiding prefab missing")
		return 1
	for title in Tunables.section_titles():
		var section: VerticalCollapsibleHiding = prefab.instantiate()
		section.section_text = StringName(title)
		section.start_open = false
		root.add_child(section)
		var title_label: Label = section.get_node("VerticalCollapsible/HBoxContainer/Section_Title")
		title_label.text = title
		if title_label.text != title:
			push_error("collapsible title was not applied")
			section.queue_free()
			return 1
		if section.is_open:
			push_error("tunable sections must start collapsed")
			section.queue_free()
			return 1
		if section.get_control() == null:
			push_error("collapsible must expose PutThingsHere for tunable fields")
			section.queue_free()
			return 1
		section.queue_free()
	return 0


func _test_toggle_ignores_source_texture_size() -> int:
	var toggle := TextureButton.new()
	Tunables.configure_theme_toggle(toggle)
	if not toggle.ignore_texture_size:
		push_error("memory toggle must ignore the 486x256 source art")
		return 1
	if toggle.stretch_mode != TextureButton.STRETCH_SCALE:
		push_error("memory toggle must scale into the theme rect")
		return 1
	if toggle.custom_minimum_size.x != 60 or toggle.custom_minimum_size.y != 0:
		push_error("memory toggle must use the cortical-details minimum size")
		return 1
	if toggle.theme_type_variation != &"ToggleButton":
		push_error("memory toggle must use the ToggleButton theme variation")
		return 1
	return 0


func _test_window_fits_content_inside_available_height() -> int:
	# viewport 1000, top bar ends at 48, HUD is 44 + 10*2 + 8 = 72. Available = 880.
	var available: int = Tunables.available_window_height(1000, 48, 44, 10)
	if available != 880:
		push_error("available height must sit between the top bar and the bottom HUD")
		return 1
	if Tunables.fitted_window_height(420, available) != 420:
		push_error("collapsed window must stay at content height")
		return 1
	if Tunables.fitted_window_height(1400, available) != 880:
		push_error("expanded window must stop at the usable BV height")
		return 1
	if Tunables.fitted_window_top(200, 420, 48, 928) != 200:
		push_error("a fitting window must keep its current top")
		return 1
	if Tunables.fitted_window_top(700, 420, 48, 928) != 508:
		push_error("a window that would pass the HUD must move up")
		return 1
	return 0


func _test_memory_count_matches_cortical_details() -> int:
	if Tunables.memory_neuron_total(1, 0) != 1:
		push_error("memory total must be short-term plus long-term, never a stale separate count")
		return 1
	if Tunables.memory_count_display(Tunables.memory_neuron_total(1, 0), 1, 0) != "1 (ST: 1 | LT: 0)":
		push_error("one short-term neuron must display as 1 (ST: 1 | LT: 0), not 0")
		return 1
	if Tunables.memory_count_display(12, 4, 8) != "12 (ST: 4 | LT: 8)":
		push_error("memory count must show total with short-term and long-term suffix")
		return 1
	if Tunables.memory_count_display(1500, 1000, 500) != "1.5K (ST: 1K | LT: 500)":
		push_error("memory count must compact thousands the same way as cortical details")
		return 1
	if Tunables.memory_count_tooltip(1200, 200, 1000) != "Total neurons: 1,200\nShort-term neurons: 200\nLong-term neurons: 1,000":
		push_error("memory count tooltip must spell out the three counts")
		return 1
	return 0


func _test_numeric_defaults_are_one() -> int:
	for spec in Tunables.MEMORY_FIELD_SPECS:
		if String(spec.get("kind", "int")) == "bool":
			continue
		if int(spec.get("min", 0)) < 1:
			push_error("%s must not allow 0" % String(spec["key"]))
			return 1
		if int(Tunables.spec_numeric_default(spec)) != 1:
			push_error("%s default must be 1" % String(spec["key"]))
			return 1
		if int(Tunables.numeric_or_default(0, spec)) != 1:
			push_error("%s must treat 0 as the default of 1" % String(spec["key"]))
			return 1
	for spec in Tunables.ASSOCIATIVE_FIELD_SPECS:
		if float(Tunables.spec_numeric_default(spec)) != 1.0:
			push_error("%s default must be 1" % String(spec["key"]))
			return 1
		if float(Tunables.numeric_or_default(0, spec)) != 1.0:
			push_error("%s must treat 0 as the default of 1" % String(spec["key"]))
			return 1
		if String(spec.get("kind", "int")) == "int" and int(spec.get("min", 0)) < 1:
			push_error("%s must not allow 0" % String(spec["key"]))
			return 1
	if float(Tunables.numeric_or_default(0.5, Tunables.ASSOCIATIVE_FIELD_SPECS[1])) != 0.5:
		push_error("associative floats must keep an explicit non-zero value")
		return 1
	if int(Tunables.numeric_or_default(9, Tunables.MEMORY_FIELD_SPECS[0])) != 9:
		push_error("memory ints must keep an explicit non-zero value")
		return 1
	return 0
