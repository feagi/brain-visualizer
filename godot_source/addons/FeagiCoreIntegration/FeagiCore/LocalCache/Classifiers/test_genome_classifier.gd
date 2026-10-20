extends SceneTree
## Unit tests for the BV classifier object model.
## Avoids instantiating BrainRegion / AbstractCorticalArea (those scripts need the
## FeagiCore autoload and do not compile under `godot -s`).
## Run: godot --headless --path godot_source -s res://addons/FeagiCoreIntegration/FeagiCore/LocalCache/Classifiers/test_genome_classifier.gd


func _initialize() -> void:
	var failures: int = 0
	failures += _test_classifier_is_not_a_brain_region()
	failures += _test_classifier_is_not_exportable_circuit()
	failures += _test_owns_internals_and_references_inputs()
	failures += _test_owned_area_ids_match_delete_contract()
	failures += _test_memory_reset_targets_kernel_and_class_only()
	failures += _test_visual_inbound_aliases_and_hidden_internals()
	failures += _test_cb_and_bm_hide_rules()
	failures += _test_stamp_is_sample_memory_and_outputs_are_owned()
	failures += _test_stamp_visual_dimensions()
	failures += _test_details_rows_are_classifier_not_cortical_area()
	failures += _test_class_binding_loads_output()
	failures += _test_old_scanner_record_is_not_a_classifier_input()
	failures += _test_quick_connect_anchors_on_classifier_stamp()
	failures += _test_quick_connect_bridge_stops_when_destination_is_stuck()
	failures += _test_filter_classifiers_from_selection()
	failures += _test_classifier_click_is_quick_connect_destination()
	failures += _test_mapping_to_classifier_offers_only_sample_and_class()
	failures += _test_classifier_circuit_interior_stays_closed()
	failures += _test_classifier_plate_faces()
	failures += _test_ipu_and_opu_can_feed_classifier()
	if failures == 0:
		print("GenomeClassifier object-model tests: PASS")
		quit(0)
	else:
		push_error("GenomeClassifier object-model tests: FAIL (%d)" % failures)
		quit(1)


func _make_classifier() -> GenomeClassifier:
	var classifier := GenomeClassifier.new(&"clf-1", &"DemoClassifier", Vector2i.ZERO, Vector3i(4, 5, 6))
	classifier.apply_feagi_dict({
		"classifier_id": "clf-1",
		"name": "DemoClassifier",
		"parent_region_id": "parent-region",
		"coordinates_3d": [4, 5, 6],
		"sample_area_ids": ["sample", "sample-b"],
		"class_bindings": [
			{"class_area_id": "class", "class_output_area_id": "out"},
			{"class_area_id": "class-b", "class_output_area_id": "out-b"},
		],
		"sample_memory_id": "smem",
		"class_memory_id": "cmem",
		"error_area_id": "err",
	})
	return classifier


func _test_ipu_and_opu_can_feed_classifier() -> int:
	if not GenomeClassifier.cortical_type_can_feed_classifier(AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU, false, false):
		push_error("IPU must be allowed as a classifier input")
		return 1
	if not GenomeClassifier.cortical_type_can_feed_classifier(AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU, false, false):
		push_error("OPU must be allowed as a classifier input")
		return 1
	if not GenomeClassifier.cortical_type_can_feed_classifier(AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY, false, false):
		push_error("memory must stay a classifier input")
		return 1
	if GenomeClassifier.cortical_type_can_feed_classifier(AbstractCorticalArea.CORTICAL_AREA_TYPE.CORE, false, false):
		push_error("core areas stay off classifier inputs")
		return 1
	if GenomeClassifier.cortical_type_can_feed_classifier(AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU, true, false):
		push_error("classifier internals cannot feed a classifier")
		return 1
	if GenomeClassifier.cortical_type_can_feed_classifier(AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU, false, true):
		push_error("an area owned by the destination classifier cannot feed it")
		return 1
	return 0


func _test_classifier_is_not_a_brain_region() -> int:
	var classifier: GenomeObject = _make_classifier()
	if classifier is BrainRegion:
		push_error("GenomeClassifier must not be a BrainRegion")
		return 1
	if classifier is AbstractCorticalArea:
		push_error("GenomeClassifier must not be a cortical area")
		return 1
	if not classifier is GenomeClassifier:
		push_error("object must be a GenomeClassifier")
		return 1
	if GenomeObject.get_makeup_of_single_object(classifier) != GenomeObject.SINGLE_MAKEUP.SINGLE_CLASSIFIER:
		push_error("classifier makeup must be SINGLE_CLASSIFIER")
		return 1
	return 0


func _test_classifier_is_not_exportable_circuit() -> int:
	var classifier: GenomeClassifier = _make_classifier()
	if classifier.genome_ID != &"clf-1":
		push_error("classifier_id must stay the genome key")
		return 1
	if classifier.coordinates_3D != Vector3i(4, 5, 6):
		push_error("classifier must keep genome coordinates_3d")
		return 1
	if not classifier.is_class_output_id(&"out") or not classifier.is_class_output_id(&"out-b"):
		push_error("each class output must stay on the classifier, not become a region")
		return 1
	return 0


func _test_owns_internals_and_references_inputs() -> int:
	var classifier: GenomeClassifier = _make_classifier()
	if not classifier.owns_area_id(&"smem") or not classifier.owns_area_id(&"cmem") or not classifier.owns_area_id(&"err") or not classifier.owns_area_id(&"out") or not classifier.owns_area_id(&"out-b"):
		push_error("classifier must own sample memory, class memory, the error area, and each class output")
		return 1
	if not classifier.references_input_id(&"sample") or not classifier.references_input_id(&"sample-b") or not classifier.references_input_id(&"class") or not classifier.references_input_id(&"class-b"):
		push_error("classifier must reference every sample and class input")
		return 1
	if classifier.owns_area_id(&"sample") or classifier.references_input_id(&"smem"):
		push_error("inputs and internals must stay distinct")
		return 1
	return 0


func _test_owned_area_ids_match_delete_contract() -> int:
	var classifier: GenomeClassifier = _make_classifier()
	var owned: Array[StringName] = classifier.owned_area_ids()
	if owned.size() != 5 or owned[0] != &"smem" or owned[1] != &"cmem" or owned[2] != &"err" or owned[3] != &"out" or owned[4] != &"out-b":
		push_error("owned_area_ids must be sample memory, class memory, error, then each class output")
		return 1
	var delete_path := "/v1/cortical_area/classifier/{classifier_id}".replace("{classifier_id}", str(classifier.classifier_id))
	if delete_path != "/v1/cortical_area/classifier/clf-1":
		push_error("classifier delete path must interpolate classifier_id")
		return 1
	return 0


func _test_memory_reset_targets_kernel_and_class_only() -> int:
	var classifier: GenomeClassifier = _make_classifier()
	var ids: Array[StringName] = classifier.memory_area_ids()
	if ids.size() != 2 or ids[0] != &"smem" or ids[1] != &"cmem":
		push_error("classifier memory reset must target sample memory then class memory")
		return 1
	if &"out" in ids or &"err" in ids:
		push_error("classifier memory reset must not include class outputs or the error area")
		return 1
	var menu_source: String = FileAccess.get_file_as_string("res://BrainVisualizer/UI/Windows/QuickMenu/WindowQuickMenu.gd")
	var block_start: int = menu_source.find("SINGLE_CLASSIFIER:")
	var block_end: int = menu_source.find("MULTIPLE_CORTICAL_AREAS:", block_start)
	if block_start < 0 or block_end < 0:
		push_error("classifier quick menu block missing")
		return 1
	var block: String = menu_source.substr(block_start, block_end - block_start)
	if block.find("reset_button.visible = true") < 0:
		push_error("classifier quick menu must show Reset")
		return 1
	if menu_source.find("get_memory_areas()") < 0:
		push_error("classifier reset must call get_memory_areas")
		return 1
	if menu_source.find("reload_live_memory_counts()") < 0:
		push_error("classifier reset must reload the open long-term memory count")
		return 1
	return 0


func _test_visual_inbound_aliases_and_hidden_internals() -> int:
	var classifier: GenomeClassifier = _make_classifier()
	var classifiers := {classifier.classifier_id: classifier}
	if GenomeClassifier.find_owner_of_area(&"smem", classifiers) != classifier:
		push_error("sample memory dest must visually resolve to the classifier")
		return 1
	if GenomeClassifier.find_owner_of_area(&"cmem", classifiers) != classifier:
		push_error("class memory dest must visually resolve to the classifier")
		return 1
	if GenomeClassifier.find_owner_of_area(&"out", classifiers) != classifier:
		push_error("class output remains classifier-owned")
		return 1
	if GenomeClassifier.find_owner_of_area(&"sample", classifiers) != null:
		push_error("sample input must stay a visible source area")
		return 1
	if not classifier.references_input_id(&"sample") or not classifier.owns_area_id(&"smem"):
		push_error("sample input → sample memory must be a visual inbound alias")
		return 1
	if not classifier.references_input_id(&"class") or not classifier.owns_area_id(&"cmem"):
		push_error("class input → class memory must be a visual inbound alias")
		return 1
	if not classifier.owns_area_id(&"smem") or not classifier.owns_area_id(&"cmem"):
		push_error("sample memory → class memory must stay hidden as an internal mapping")
		return 1
	if not classifier.is_class_output_id(&"out") or not classifier.is_error_area_id(&"err"):
		push_error("class output and error area must stay visible destinations")
		return 1
	if GenomeClassifier.resolve_visual_connectable(classifier, classifiers) != classifier:
		push_error("classifier object must stay itself")
		return 1
	if not classifier.is_stamp_host_id(&"smem") or classifier.is_stamp_host_id(&"out"):
		push_error("stamp host is sample memory, not a class output")
		return 1
	var inbound: Array[StringName] = classifier.inbound_visual_source_ids()
	if inbound.size() != 4 or inbound[0] != &"sample" or inbound[1] != &"sample-b" or inbound[2] != &"class" or inbound[3] != &"class-b":
		push_error("inbound visual sources must be the sample inputs then the class inputs")
		return 1
	return 0


func _test_cb_and_bm_hide_rules() -> int:
	var leftover_name := "field_scan_twin"
	var internal_name := "DemoClassifier_sample_mem"
	if leftover_name.ends_with("_scan_twin") == false:
		push_error("leftover auto twin name contract drifted")
		return 1
	if internal_name.ends_with("_sample_mem") == false:
		push_error("classifier sample memory name contract drifted")
		return 1
	var classifier: GenomeClassifier = _make_classifier()
	if not classifier.owns_area_id(&"out"):
		push_error("classifier still owns the class output")
		return 1
	if not classifier.owns_area_id(&"smem"):
		push_error("classifier still owns sample memory")
		return 1
	return 0


func _test_stamp_is_sample_memory_and_outputs_are_owned() -> int:
	var classifier: GenomeClassifier = _make_classifier()
	if not classifier.is_stamp_host_id(&"smem"):
		push_error("stamp host must be sample memory")
		return 1
	if classifier.is_stamp_host_id(&"out"):
		push_error("class output must not be the stamp host")
		return 1
	if not classifier.hides_area_id(&"cmem"):
		push_error("class memory stays hidden")
		return 1
	if classifier.hides_area_id(&"out") or classifier.hides_area_id(&"err"):
		push_error("class output and error area must stay visible")
		return 1
	return 0


func _test_stamp_visual_dimensions() -> int:
	if GenomeClassifier.stamp_visual_dimensions(9, 4) != Vector3i(3, 3, 4):
		push_error("stamp XY must be sqrt of stored neurons and Z classifier depth")
		return 1
	if GenomeClassifier.stamp_visual_dimensions(1, 10) != Vector3i(1, 1, 10):
		push_error("empty assembly must stay 1x1 x classifier depth")
		return 1
	if GenomeClassifier.stamp_visual_dimensions(10, 2) != Vector3i(4, 4, 2):
		push_error("non-square neuron counts must ceil to the next side")
		return 1
	return 0


func _test_details_rows_are_classifier_not_cortical_area() -> int:
	var classifier: GenomeClassifier = _make_classifier()
	var rows: Array[Dictionary] = classifier.details_rows()
	var keys: PackedStringArray = PackedStringArray()
	var editable_keys: PackedStringArray = PackedStringArray()
	for row in rows:
		var key := str(row.get("key", ""))
		keys.append(key)
		if bool(row.get("editable", false)):
			editable_keys.append(key)
		if key == "firing_threshold" or key == "cortical_type" or key == "neuron_density":
			push_error("classifier details must not include cortical-area neuron fields")
			return 1
	if not keys.has("classifier_id") or not keys.has("name") or not keys.has("sample_inputs") or not keys.has("class_outputs") or not keys.has("error_area"):
		push_error("classifier details must include identity, sample inputs, class outputs, and the error area")
		return 1
	if keys.has("cortical_id") or keys.has("training_mode") or keys.has("kernel_area"):
		push_error("classifier details must not present scanner or cortical-area fields")
		return 1
	for required_editable in ["name", "parent_circuit", "coordinates_3d"]:
		if not editable_keys.has(required_editable):
			push_error("classifier field %s must be editable" % required_editable)
			return 1
	if editable_keys.has("sample_inputs") or editable_keys.has("class_outputs") or editable_keys.has("error_area"):
		push_error("inputs, outputs, and the error area are mapping-owned and stay read-only")
		return 1
	if editable_keys.has("classifier_id") or editable_keys.has("hidden_internals"):
		push_error("classifier id and owned internals must stay read-only")
		return 1
	return 0


func _test_class_binding_loads_output() -> int:
	var classifier := GenomeClassifier.new(&"clf-bind", &"Bind", Vector2i.ZERO, Vector3i.ZERO)
	classifier.apply_feagi_dict({
		"sample_memory_id": "smem",
		"class_memory_id": "cmem",
		"error_area_id": "err",
		"class_bindings": [
			{"class_area_id": "class", "class_output_area_id": "out"},
		],
	})
	if not classifier.has_class_input(&"class") or not classifier.is_class_output_id(&"out"):
		push_error("a class binding must keep the class input and its output")
		return 1
	if classifier.class_output_ids().size() != 1:
		push_error("one class binding must not invent extra outputs")
		return 1
	return 0


func _test_old_scanner_record_is_not_a_classifier_input() -> int:
	var classifier := GenomeClassifier.new(&"clf-scan", &"Scan", Vector2i.ZERO, Vector3i.ZERO)
	classifier.apply_feagi_dict({
		"name": "Scan",
		"training_mode": "scanner",
		"mask_area_id": "mask",
		"kernel_size": [8, 8, 3],
		"class_count": 19,
		"kernel_memory_id": "kmem",
		"class_memory_id": "cmem",
	})
	if classifier.sample_memory_id != &"" or classifier.error_area_id != &"":
		push_error("kernel_memory_id and scanner fields must not populate sample memory or the error area")
		return 1
	if classifier.class_memory_id != &"cmem":
		push_error("class_memory_id is still the class memory id")
		return 1
	if classifier.references_input_id(&"mask") or not classifier.class_bindings().is_empty():
		push_error("a scanner record must not become sample or class inputs")
		return 1
	return 0


func _test_quick_connect_anchors_on_classifier_stamp() -> int:
	if not GenomeClassifier.quick_connect_should_anchor_on_stamp(true, false):
		push_error("quick connect must anchor on the classifier stamp")
		return 1
	if GenomeClassifier.quick_connect_should_anchor_on_stamp(true, true):
		push_error("a cortical volume in front of the stamp must keep the ray hit")
		return 1
	if GenomeClassifier.quick_connect_should_anchor_on_stamp(false, false):
		push_error("a normal cortical area must keep the ray hit")
		return 1
	return 0


func _test_quick_connect_bridge_stops_when_destination_is_stuck() -> int:
	if not GenomeClassifier.quick_connect_should_draw_cross_scene_bridge(false):
		push_error("an unstuck destination may bridge into the hovered viewport")
		return 1
	if GenomeClassifier.quick_connect_should_draw_cross_scene_bridge(true):
		push_error("a stuck destination must not bridge into the root scene")
		return 1
	return 0


func _test_filter_classifiers_from_selection() -> int:
	var classifier: GenomeClassifier = _make_classifier()
	var objects: Array[GenomeObject] = [classifier]
	var found: Array[GenomeClassifier] = GenomeObject.filter_classifiers(objects)
	if found.size() != 1 or found[0] != classifier:
		push_error("selection filter must keep the clicked classifier")
		return 1
	if not GenomeObject.filter_classifiers([]).is_empty():
		push_error("an empty selection must not invent a classifier")
		return 1
	return 0


func _test_classifier_click_is_quick_connect_destination() -> int:
	var classifier: GenomeClassifier = _make_classifier()
	var objects: Array[GenomeObject] = [classifier]
	if GenomeClassifier.destination_classifier_from_selection(objects, false) != classifier:
		push_error("a classifier click must be the quick-connect destination")
		return 1
	if GenomeClassifier.destination_classifier_from_selection(objects, true) != null:
		push_error("ctrl multi-select must not force a classifier destination")
		return 1
	if GenomeClassifier.destination_classifier_from_selection([], false) != null:
		push_error("an empty click must not pick a classifier destination")
		return 1
	return 0


func _test_mapping_to_classifier_offers_only_sample_and_class() -> int:
	var classifier: GenomeClassifier = _make_classifier()
	var rules: Array[BaseMorphology] = GenomeClassifier.input_morphologies()
	if rules.size() != 2:
		push_error("classifier mapping must offer exactly two connectivity rules")
		return 1
	if rules[0].name != GenomeClassifier.SAMPLE_INPUT_MORPHOLOGY or GenomeClassifier.input_rule_label(rules[0].name) != "Classifier Sample":
		push_error("first classifier rule must be Classifier Sample")
		return 1
	if rules[1].name != GenomeClassifier.CLASS_INPUT_MORPHOLOGY or GenomeClassifier.input_rule_label(rules[1].name) != "Classifier Class":
		push_error("second classifier rule must be Classifier Class")
		return 1
	if rules[0].type == BaseMorphology.MORPHOLOGY_TYPE.PATTERNS or rules[1].type == BaseMorphology.MORPHOLOGY_TYPE.PATTERNS:
		push_error("classifier rules must not be pattern morphologies")
		return 1
	if not GenomeClassifier.is_input_rule(GenomeClassifier.SAMPLE_INPUT_MORPHOLOGY):
		push_error("classifier sample must be recognized as an input rule")
		return 1
	var sample_rule: BaseMorphology = GenomeClassifier.input_rule_morphology(GenomeClassifier.SAMPLE_INPUT_MORPHOLOGY)
	if sample_rule == null or sample_rule.name != GenomeClassifier.SAMPLE_INPUT_MORPHOLOGY:
		push_error("classifier sample must export as its own mapping rule")
		return 1
	var classifiers: Dictionary = {classifier.classifier_id: classifier}
	if GenomeClassifier.classifier_for_destination_area_id(classifier.sample_memory_id, classifiers) != classifier:
		push_error("sample memory must map as the classifier")
		return 1
	if GenomeClassifier.classifier_for_destination_area_id(classifier.class_memory_id, classifiers) != classifier:
		push_error("class memory must map as the classifier")
		return 1
	if GenomeClassifier.classifier_for_destination_area_id(&"out", classifiers) != null:
		push_error("a class output must not open the classifier input rules")
		return 1
	if GenomeClassifier.classifier_for_destination_area_id(classifier.error_area_id, classifiers) != null:
		push_error("the error area must not open the classifier input rules")
		return 1
	if GenomeClassifier.classifier_for_mapping_destination(classifier, classifiers) != classifier:
		push_error("the classifier node must open the classifier input rules")
		return 1
	return 0


func _test_classifier_circuit_interior_stays_closed() -> int:
	if GenomeClassifier.circuit_interior_button_enabled(true):
		push_error("a classifier circuit must not enable the open-interior button")
		return 1
	if not GenomeClassifier.circuit_interior_button_enabled(false):
		push_error("other circuits must keep the open-interior button enabled")
		return 1
	if GenomeClassifier.INTEGRATED_CIRCUIT_INTERNALS_TOOLTIP != "this is an integrated circuit and internals are not visible":
		push_error("classifier circuit tooltip must say the interior is not visible")
		return 1
	if GenomeClassifier.region_hides_interior(null):
		push_error("a missing region must not hide an interior")
		return 1
	return 0


func _test_classifier_plate_faces() -> int:
	var classifier: GenomeClassifier = _make_classifier()
	var inputs: Array[StringName] = GenomeClassifier.classifier_plate_input_ids(classifier)
	if inputs.size() != 1 or inputs[0] != classifier.sample_memory_id:
		push_error("the classifier plate input must be the classifier stamp")
		return 1
	var outputs: Array[StringName] = GenomeClassifier.classifier_plate_output_ids(classifier)
	if classifier.error_area_id not in outputs:
		push_error("the error area must sit on the output plate")
		return 1
	if &"out" not in outputs or &"out-b" not in outputs:
		push_error("each class output must sit on the output plate")
		return 1
	if classifier.class_memory_id in inputs or classifier.class_memory_id in outputs:
		push_error("class memory must stay off the plates")
		return 1
	if classifier.sample_memory_id in outputs:
		push_error("the classifier stamp must not also be an output")
		return 1
	if not GenomeClassifier.classifier_plate_input_ids(null).is_empty():
		push_error("a missing classifier has no plate input")
		return 1
	return 0
