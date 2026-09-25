extends Node
## Compact Quick Connect advanced mapping form.
## SceneTree -s mode does not register autoloads before this form's dependencies compile.
## Run: godot --headless --path godot_source res://BrainVisualizer/UI/Windows/QuickConnect/test_quick_connect_advanced_mapping.tscn

const PANEL_SCENE: PackedScene = preload("res://BrainVisualizer/UI/Windows/QuickConnect/QuickConnectAdvancedMapping.tscn")


func _ready() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var failures: int = 0
	failures += await _test_advanced_starts_collapsed()
	failures += await _test_inhibitory_negates_psp_and_plasticity_exports_stdp()
	failures += await _test_plasticity_off_omits_learning_fields()
	failures += await _test_associative_memory_stays_plastic()
	failures += await _test_same_rule_keeps_edits()
	failures += await _test_restrictions_disable_fields()
	failures += _test_episodic_memory_and_classifier_hide_advanced()
	failures += _test_quick_menu_two_rows_only_for_cortical_areas()
	if failures == 0:
		print("Quick Connect advanced mapping tests: PASS")
		get_tree().quit(0)
	else:
		push_error("Quick Connect advanced mapping tests: FAIL (%d)" % failures)
		get_tree().quit(1)


func _spawn_panel() -> QuickConnectAdvancedMapping:
	var panel: QuickConnectAdvancedMapping = PANEL_SCENE.instantiate()
	add_child(panel)
	await get_tree().process_frame
	return panel


func _test_advanced_starts_collapsed() -> int:
	var panel: QuickConnectAdvancedMapping = await _spawn_panel()
	if panel.is_advanced_enabled():
		push_error("advanced toggle must start off")
		panel.queue_free()
		return 1
	var section: VerticalCollapsibleHiding = panel.get_node("AdvancedSection")
	if not section is VerticalCollapsibleHiding or section.is_open:
		push_error("Advanced must be a collapsed cortical-details section")
		panel.queue_free()
		return 1
	if section.get_node("VerticalCollapsible/HBoxContainer/Section_Title").text != "Advanced":
		push_error("Advanced section title was not set")
		panel.queue_free()
		return 1
	for toggle_path in ["Primary/Inhibitory", "Primary/Plasticity"]:
		if not panel.get_node("AdvancedSection/VerticalCollapsible/PanelContainer/PutThingsHere/Rows/" + toggle_path) is ToggleButton:
			push_error("expected ToggleButton at %s" % toggle_path)
			panel.queue_free()
			return 1
	if section.get_node("VerticalCollapsible/PanelContainer").visible:
		push_error("field list must stay hidden until Advanced is expanded")
		panel.queue_free()
		return 1
	panel.set_advanced_enabled(true)
	if not section.is_open or not section.get_node("VerticalCollapsible/PanelContainer").visible:
		push_error("expanding Advanced must show the field list")
		panel.queue_free()
		return 1
	if panel.get_node("AdvancedSection/VerticalCollapsible/PanelContainer/PutThingsHere/Rows/PlasticityRows").visible:
		push_error("plasticity details must stay hidden until plasticity is on")
		panel.queue_free()
		return 1
	panel.queue_free()
	return 0


func _test_inhibitory_negates_psp_and_plasticity_exports_stdp() -> int:
	var panel: QuickConnectAdvancedMapping = await _spawn_panel()
	var morphology: BaseMorphology = BaseMorphology.new(&"block_to_block", true, BaseMorphology.MORPHOLOGY_INTERNAL_CLASS.CORE)
	panel.load_for_morphology(morphology)
	panel.get_node("AdvancedSection/VerticalCollapsible/PanelContainer/PutThingsHere/Rows/Primary/PSP").current_float = 2.5
	panel.get_node("AdvancedSection/VerticalCollapsible/PanelContainer/PutThingsHere/Rows/Primary/Inhibitory").button_pressed = true
	panel.get_node("AdvancedSection/VerticalCollapsible/PanelContainer/PutThingsHere/Rows/Primary/SynapticDelay").current_int = 4
	panel.get_node("AdvancedSection/VerticalCollapsible/PanelContainer/PutThingsHere/Rows/Primary/Plasticity").button_pressed = true
	panel.get_node("AdvancedSection/VerticalCollapsible/PanelContainer/PutThingsHere/Rows/PlasticityRows/PlasticityConstant").current_float = 0.25
	panel.get_node("AdvancedSection/VerticalCollapsible/PanelContainer/PutThingsHere/Rows/PlasticityRows/PlasticityWindow").current_int = 6
	panel.get_node("AdvancedSection/VerticalCollapsible/PanelContainer/PutThingsHere/Rows/PlasticityRows/LTP").current_float = 1.5
	panel.get_node("AdvancedSection/VerticalCollapsible/PanelContainer/PutThingsHere/Rows/PlasticityRows/LTD").current_float = 0.5
	var mapping: SingleMappingDefinition = panel.export_mapping(morphology)
	var payload: Dictionary = mapping.to_FEAGI_JSON()
	if payload["postSynapticCurrent_multiplier"] != -2.5:
		push_error("inhibitory must store a negative PSP multiplier, got %s" % str(payload["postSynapticCurrent_multiplier"]))
		panel.queue_free()
		return 1
	if payload["synaptic_delay_bursts"] != 4:
		push_error("synaptic delay was not exported")
		panel.queue_free()
		return 1
	if payload["plasticity_flag"] != true or payload["plasticity_mode"] != "stdp":
		push_error("plasticity checkbox must export STDP")
		panel.queue_free()
		return 1
	if payload["plasticity_constant"] != 0.25 or payload["plasticity_window"] != 6:
		push_error("plasticity constant or window was not exported")
		panel.queue_free()
		return 1
	if payload["ltp_multiplier"] != 1.5 or payload["ltd_multiplier"] != 0.5:
		push_error("LTP or LTD was not exported")
		panel.queue_free()
		return 1
	if payload.has("reward_source_area") or payload.has("morphology_scalar") == false:
		push_error("compact form must keep scalar and omit reward sources")
		panel.queue_free()
		return 1
	panel.queue_free()
	return 0


func _test_plasticity_off_omits_learning_fields() -> int:
	var panel: QuickConnectAdvancedMapping = await _spawn_panel()
	var morphology: BaseMorphology = BaseMorphology.new(&"projector", true, BaseMorphology.MORPHOLOGY_INTERNAL_CLASS.CORE)
	panel.load_for_morphology(morphology)
	var payload: Dictionary = panel.export_mapping(morphology).to_FEAGI_JSON()
	if payload["plasticity_flag"] != false:
		push_error("default plasticity must stay off")
		panel.queue_free()
		return 1
	if payload.has("plasticity_constant") or payload.has("plasticity_mode"):
		push_error("plasticity-off mappings must omit learning fields")
		panel.queue_free()
		return 1
	panel.queue_free()
	return 0


func _test_associative_memory_stays_plastic() -> int:
	var panel: QuickConnectAdvancedMapping = await _spawn_panel()
	var morphology: BaseMorphology = BaseMorphology.new(&"associative_memory", true, BaseMorphology.MORPHOLOGY_INTERNAL_CLASS.CORE)
	panel.load_for_morphology(morphology)
	var plasticity: ToggleButton = panel.get_node("AdvancedSection/VerticalCollapsible/PanelContainer/PutThingsHere/Rows/Primary/Plasticity")
	if not plasticity.button_pressed or not plasticity.disabled:
		push_error("associative memory must lock plasticity on")
		panel.queue_free()
		return 1
	if not panel.get_node("AdvancedSection/VerticalCollapsible/PanelContainer/PutThingsHere/Rows/PlasticityRows").visible:
		push_error("associative memory must show plasticity details")
		panel.queue_free()
		return 1
	plasticity.button_pressed = false
	var payload: Dictionary = panel.export_mapping(morphology).to_FEAGI_JSON()
	if payload["plasticity_flag"] != true:
		push_error("associative memory export must stay plastic")
		panel.queue_free()
		return 1
	panel.queue_free()
	return 0


func _test_same_rule_keeps_edits() -> int:
	var panel: QuickConnectAdvancedMapping = await _spawn_panel()
	var morphology: BaseMorphology = BaseMorphology.new(&"block_to_block", true, BaseMorphology.MORPHOLOGY_INTERNAL_CLASS.CORE)
	panel.load_for_morphology(morphology)
	panel.get_node("AdvancedSection/VerticalCollapsible/PanelContainer/PutThingsHere/Rows/Primary/PSP").current_float = 3.0
	panel.load_for_morphology(morphology)
	if panel.get_node("AdvancedSection/VerticalCollapsible/PanelContainer/PutThingsHere/Rows/Primary/PSP").current_float != 3.0:
		push_error("reloading the same rule must keep the edited PSP multiplier")
		panel.queue_free()
		return 1
	var other: BaseMorphology = BaseMorphology.new(&"projector", true, BaseMorphology.MORPHOLOGY_INTERNAL_CLASS.CORE)
	panel.load_for_morphology(other)
	if panel.get_node("AdvancedSection/VerticalCollapsible/PanelContainer/PutThingsHere/Rows/Primary/PSP").current_float != 1.0:
		push_error("a new rule must restore the default PSP multiplier")
		panel.queue_free()
		return 1
	panel.queue_free()
	return 0


func _test_restrictions_disable_fields() -> int:
	var panel: QuickConnectAdvancedMapping = await _spawn_panel()
	var morphology: BaseMorphology = BaseMorphology.new(&"block_to_block", true, BaseMorphology.MORPHOLOGY_INTERNAL_CLASS.CORE)
	panel.load_for_morphology(morphology)
	var restrictions: MappingRestrictionCorticalMorphology = MappingRestrictionCorticalMorphology.new()
	restrictions.allow_changing_PSP = false
	restrictions.allow_changing_inhibitory = false
	restrictions.allow_changing_plasticity = false
	panel.apply_restrictions(restrictions)
	if panel.get_node("AdvancedSection/VerticalCollapsible/PanelContainer/PutThingsHere/Rows/Primary/PSP").editable:
		push_error("PSP multiplier must honor allow_changing_PSP")
		panel.queue_free()
		return 1
	if panel.get_node("AdvancedSection/VerticalCollapsible/PanelContainer/PutThingsHere/Rows/Primary/SynapticDelay").editable:
		push_error("synaptic delay must follow the PSP edit restriction")
		panel.queue_free()
		return 1
	if not panel.get_node("AdvancedSection/VerticalCollapsible/PanelContainer/PutThingsHere/Rows/Primary/Inhibitory").disabled:
		push_error("inhibitory must honor allow_changing_inhibitory")
		panel.queue_free()
		return 1
	if not panel.get_node("AdvancedSection/VerticalCollapsible/PanelContainer/PutThingsHere/Rows/Primary/Plasticity").disabled:
		push_error("plasticity must honor allow_changing_plasticity")
		panel.queue_free()
		return 1
	panel.queue_free()
	return 0


func _test_episodic_memory_and_classifier_hide_advanced() -> int:
	var block: BaseMorphology = BaseMorphology.new(&"block_to_block", true, BaseMorphology.MORPHOLOGY_INTERNAL_CLASS.CORE)
	var episodic: BaseMorphology = BaseMorphology.new(&"episodic_memory", true, BaseMorphology.MORPHOLOGY_INTERNAL_CLASS.CORE)
	if not WindowQuickConnect.shows_advanced_mapping(block, false):
		push_error("a normal connectivity rule must show Advanced")
		return 1
	if WindowQuickConnect.shows_advanced_mapping(episodic, false):
		push_error("episodic memory must hide Advanced")
		return 1
	if WindowQuickConnect.shows_advanced_mapping(block, true):
		push_error("a classifier destination must hide Advanced")
		return 1
	if WindowQuickConnect.shows_advanced_mapping(null, false):
		push_error("Advanced must stay hidden until a connectivity rule is chosen")
		return 1
	return 0


func _test_quick_menu_two_rows_only_for_cortical_areas() -> int:
	if QuickCorticalMenu.toolbar_column_count(14, true) != 7:
		push_error("single cortical area popup must split its actions across two rows")
		return 1
	if QuickCorticalMenu.toolbar_column_count(14, false) != 14:
		push_error("one-row popups must keep their actions on one row")
		return 1
	if not QuickCorticalMenu.toolbar_wraps_two_rows(GenomeObject.ARRAY_MAKEUP.SINGLE_CORTICAL_AREA):
		push_error("single cortical area popup must wrap onto two rows")
		return 1
	if QuickCorticalMenu.toolbar_wraps_two_rows(GenomeObject.ARRAY_MAKEUP.MULTIPLE_CORTICAL_AREAS):
		push_error("selected multiple areas popup must stay on one row")
		return 1
	if QuickCorticalMenu.toolbar_wraps_two_rows(GenomeObject.ARRAY_MAKEUP.SINGLE_BRAIN_REGION):
		push_error("brain region popup must stay on one row")
		return 1
	if QuickCorticalMenu.toolbar_wraps_two_rows(GenomeObject.ARRAY_MAKEUP.MULTIPLE_BRAIN_REGIONS):
		push_error("multiple circuits popup must stay on one row")
		return 1
	if not QuickCorticalMenu.toolbar_packs_icons_flush(GenomeObject.ARRAY_MAKEUP.MULTIPLE_CORTICAL_AREAS):
		push_error("selected multiple areas popup must pack its icons with no gap")
		return 1
	if QuickCorticalMenu.toolbar_packs_icons_flush(GenomeObject.ARRAY_MAKEUP.SINGLE_CORTICAL_AREA):
		push_error("single cortical area popup must keep its theme spacing")
		return 1
	if QuickCorticalMenu.toolbar_packs_icons_flush(GenomeObject.ARRAY_MAKEUP.SINGLE_BRAIN_REGION):
		push_error("brain region popup must keep its theme spacing")
		return 1
	if not QuickCorticalMenu.toolbar_matches_icon_row(GenomeObject.ARRAY_MAKEUP.MULTIPLE_CORTICAL_AREAS):
		push_error("selected multiple areas popup must size to its icon row")
		return 1
	if QuickCorticalMenu.toolbar_matches_icon_row(GenomeObject.ARRAY_MAKEUP.SINGLE_CORTICAL_AREA):
		push_error("single cortical area popup must keep its title width")
		return 1
	if QuickCorticalMenu.toolbar_matches_icon_row(GenomeObject.ARRAY_MAKEUP.MULTIPLE_BRAIN_REGIONS):
		push_error("multiple circuits popup must keep its title width")
		return 1
	return 0
