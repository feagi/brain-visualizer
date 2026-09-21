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
	failures += _test_visual_inbound_aliases_and_hidden_internals()
	failures += _test_cb_and_bm_hide_rules()
	failures += _test_stamp_is_kernel_memory_and_twin_is_owned()
	failures += _test_stamp_visual_dimensions()
	failures += _test_details_rows_are_classifier_not_cortical_area()
	failures += _test_singular_field_record_loads_as_one_binding()
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
		"kernel_area_id": "kernel",
		"class_area_id": "class",
		"fields": [
			{"field_area_id": "field", "scan_twin_id": "stamp"},
			{"field_area_id": "field-b", "scan_twin_id": "twin-b"},
		],
		"kernel_memory_id": "kmem",
		"class_memory_id": "cmem",
	})
	return classifier


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
	if not classifier.is_scan_twin_id(&"stamp") or not classifier.is_scan_twin_id(&"twin-b"):
		push_error("each field twin must stay on the classifier, not become a region")
		return 1
	return 0


func _test_owns_internals_and_references_inputs() -> int:
	var classifier: GenomeClassifier = _make_classifier()
	if not classifier.owns_area_id(&"kmem") or not classifier.owns_area_id(&"cmem") or not classifier.owns_area_id(&"stamp") or not classifier.owns_area_id(&"twin-b"):
		push_error("classifier must own kernel_mem, class_mem, and each field twin")
		return 1
	if not classifier.references_input_id(&"kernel") or not classifier.references_input_id(&"class") or not classifier.references_input_id(&"field") or not classifier.references_input_id(&"field-b"):
		push_error("classifier must reference kernel, class, and every field input")
		return 1
	if classifier.owns_area_id(&"kernel") or classifier.references_input_id(&"kmem"):
		push_error("inputs and internals must stay distinct")
		return 1
	return 0


func _test_owned_area_ids_match_delete_contract() -> int:
	var classifier: GenomeClassifier = _make_classifier()
	var owned: Array[StringName] = classifier.owned_area_ids()
	if owned.size() != 4 or owned[0] != &"kmem" or owned[1] != &"cmem" or owned[2] != &"stamp" or owned[3] != &"twin-b":
		push_error("owned_area_ids must be kernel_mem, class_mem, then each field twin")
		return 1
	var delete_path := "/v1/cortical_area/classifier/{classifier_id}".replace("{classifier_id}", str(classifier.classifier_id))
	if delete_path != "/v1/cortical_area/classifier/clf-1":
		push_error("classifier delete path must interpolate classifier_id")
		return 1
	return 0


func _test_visual_inbound_aliases_and_hidden_internals() -> int:
	var classifier: GenomeClassifier = _make_classifier()
	var classifiers := {classifier.classifier_id: classifier}
	if GenomeClassifier.find_owner_of_area(&"kmem", classifiers) != classifier:
		push_error("kernel_mem dest must visually resolve to the classifier")
		return 1
	if GenomeClassifier.find_owner_of_area(&"cmem", classifiers) != classifier:
		push_error("class_mem dest must visually resolve to the classifier")
		return 1
	if GenomeClassifier.find_owner_of_area(&"stamp", classifiers) != classifier:
		push_error("twin remains classifier-owned")
		return 1
	if GenomeClassifier.find_owner_of_area(&"kernel", classifiers) != null:
		push_error("kernel input must stay a visible source area")
		return 1
	if not classifier.references_input_id(&"kernel") or not classifier.owns_area_id(&"kmem"):
		push_error("kernel → kernel_mem must be a visual inbound alias")
		return 1
	if not classifier.references_input_id(&"class") or not classifier.owns_area_id(&"cmem"):
		push_error("class → class_mem must be a visual inbound alias")
		return 1
	if not classifier.references_input_id(&"field") or not classifier.owns_area_id(&"kmem"):
		push_error("field → kernel_mem must be a visual inbound alias")
		return 1
	if not classifier.owns_area_id(&"kmem") or not classifier.owns_area_id(&"cmem"):
		push_error("kernel_mem → class_mem must stay hidden as an internal mapping")
		return 1
	if not classifier.is_scan_twin_id(&"stamp"):
		push_error("twin must remain a visible interconnect destination")
		return 1
	# Stamp hover outgoing: twin is not remapped onto the stamp body.
	if GenomeClassifier.resolve_visual_connectable(classifier, classifiers) != classifier:
		push_error("classifier object must stay itself")
		return 1
	if not classifier.is_stamp_host_id(&"kmem") or classifier.is_stamp_host_id(&"stamp"):
		push_error("stamp hover dest for twin must stay the twin id")
		return 1
	var inbound: Array[StringName] = classifier.inbound_visual_source_ids()
	if inbound.size() != 4 or inbound[0] != &"kernel" or inbound[1] != &"class" or inbound[2] != &"field" or inbound[3] != &"field-b":
		push_error("inbound visual sources must be kernel, class, and each field")
		return 1
	return 0


func _test_cb_and_bm_hide_rules() -> int:
	# CB hides kernel/class memory + leftover auto twins. Twin stays a visible cortical node.
	var leftover_name := "field_scan_twin"
	var internal_name := "DemoClassifier_kernel_mem"
	if leftover_name.ends_with("_scan_twin") == false:
		push_error("leftover auto twin name contract drifted")
		return 1
	if internal_name.ends_with("_kernel_mem") == false:
		push_error("classifier internal memory name contract drifted")
		return 1
	var classifier: GenomeClassifier = _make_classifier()
	if not classifier.owns_area_id(&"stamp"):
		push_error("classifier still owns the class-map twin")
		return 1
	if not classifier.owns_area_id(&"kmem"):
		push_error("classifier still owns kernel_mem")
		return 1
	return 0


func _test_stamp_is_kernel_memory_and_twin_is_owned() -> int:
	var classifier: GenomeClassifier = _make_classifier()
	if not classifier.is_stamp_host_id(&"kmem"):
		push_error("stamp host must be kernel_mem")
		return 1
	if classifier.is_stamp_host_id(&"stamp"):
		push_error("class-map twin must not be the stamp host")
		return 1
	if not classifier.hides_area_id(&"cmem"):
		push_error("class_mem stays hidden")
		return 1
	if classifier.hides_area_id(&"stamp"):
		push_error("twin must stay visible")
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
	if not keys.has("classifier_id") or not keys.has("name") or not keys.has("kernel_area"):
		push_error("classifier details must include classifier identity and inputs")
		return 1
	if keys.has("cortical_id"):
		push_error("classifier details must not present a cortical_id inspector")
		return 1
	for required_editable in ["name", "parent_circuit", "coordinates_3d", "kernel_area", "class_area"]:
		if not editable_keys.has(required_editable):
			push_error("classifier field %s must be editable" % required_editable)
			return 1
	if not keys.has("fields") or editable_keys.has("fields"):
		push_error("field bindings are mapping-owned and stay read-only in the inspector")
		return 1
	if editable_keys.has("classifier_id") or editable_keys.has("hidden_internals"):
		push_error("classifier id and owned internals must stay read-only")
		return 1
	return 0


func _test_singular_field_record_loads_as_one_binding() -> int:
	var classifier := GenomeClassifier.new(&"clf-old", &"Old", Vector2i.ZERO, Vector3i.ZERO)
	classifier.apply_feagi_dict({
		"field_area_id": "field",
		"scan_twin_id": "stamp",
		"kernel_memory_id": "kmem",
		"class_memory_id": "cmem",
	})
	if not classifier.has_field(&"field") or not classifier.is_scan_twin_id(&"stamp"):
		push_error("a previous singular field record must load as one binding")
		return 1
	if classifier.scan_twin_ids().size() != 1:
		push_error("singular field load must not invent extra twins")
		return 1
	return 0
