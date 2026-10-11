extends SceneTree
## Modulators block in cortical area properties uses the shared collapsible panel.
## Run: godot --headless --path godot_source -s res://BrainVisualizer/UI/Windows/AdvancedCorticalProperties/test_modulations_section_layout.gd

const ModulationsSection = preload("res://BrainVisualizer/UI/Windows/AdvancedCorticalProperties/CorticalModulationsSection.gd")


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var failures: int = _test_modulators_panel_matches_other_sections()
	if failures == 0:
		print("Modulations section layout tests: PASS")
		quit(0)
	else:
		push_error("Modulations section layout tests: FAIL (%d)" % failures)
		quit(1)


func _test_modulators_panel_matches_other_sections() -> int:
	var failures := 0
	var section: VerticalCollapsibleHiding = ModulationsSection.build()
	if section == null:
		push_error("modulators section builder returned nothing")
		return 1
	root.add_child(section)
	if not section is VerticalCollapsibleHiding:
		push_error("modulators section must be a VerticalCollapsibleHiding panel")
		failures += 1
	if section.start_open or section.is_open:
		push_error("modulators section must start collapsed like the other property panels")
		failures += 1
	var title := section.get_node_or_null("VerticalCollapsible/HBoxContainer/Section_Title") as Label
	if title == null or title.text != "Modulators" or title.theme_type_variation != &"Label_Header":
		push_error("modulators header must use the shared section title")
		failures += 1
	var body := section.get_node_or_null("VerticalCollapsible/PanelContainer") as PanelContainer
	if body == null or body.visible:
		push_error("modulator internals must stay hidden until the panel is expanded")
		failures += 1
	var rows := section.get_node_or_null("VerticalCollapsible/PanelContainer/PutThingsHere/CorticalPropertiesModulators") as VBoxContainer
	if rows == null:
		push_error("modulator fields must live inside PutThingsHere")
		failures += 1
		section.queue_free()
		return failures
	for field_name in ["ModulatorIds", "ModulatorType", "ExistingModulator", "NewModulatorId", "NewModulatorMagnitude"]:
		var field := rows.find_child(field_name, true, false)
		if field == null or not (field.get_parent() is HBoxContainer):
			push_error("%s must be tucked into a labeled row" % field_name)
			failures += 1
		elif field.get_parent() == section or field.get_parent() == rows:
			push_error("%s must not sit directly in the section or row stack" % field_name)
			failures += 1
	var apply := rows.get_node_or_null("ApplySubscriptions") as Button
	if apply == null or apply.text != "Apply Update" or apply.get_parent() != rows:
		push_error("modulators apply control must sit in the section body like the other Apply Update buttons")
		failures += 1
	section.is_open = true
	if body != null and not body.visible:
		push_error("expanding the modulators panel must reveal its internals")
		failures += 1
	failures += _test_expand_button_copies_sibling_size(section)
	section.queue_free()
	return failures


func _test_expand_button_copies_sibling_size(section: VerticalCollapsibleHiding) -> int:
	var toggle := section.get_node_or_null("VerticalCollapsible/HBoxContainer/Collapsible_Toggle") as TextureButton
	if toggle == null:
		push_error("modulators panel is missing its expand button")
		return 1
	var scene_size := toggle.custom_minimum_size
	var reference := TextureButton.new()
	reference.custom_minimum_size = scene_size + Vector2(32, 32)
	ModulationsSection.match_expand_button(section, reference)
	reference.free()
	if toggle.custom_minimum_size != scene_size + Vector2(32, 32):
		push_error("modulators expand button must copy the theme-scaled size used by the other panels, got %s" % toggle.custom_minimum_size)
		return 1
	return 0
