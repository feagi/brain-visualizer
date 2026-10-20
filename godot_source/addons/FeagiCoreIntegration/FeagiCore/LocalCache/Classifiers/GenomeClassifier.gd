extends GenomeObject
class_name GenomeClassifier
## First-class BV object for a genome classifier assembly.
## Not a [BrainRegion] and not a cortical area. Sample memory is the wobbly stamp.
## Class memory stays hidden. Each class input owns a visible class output, and the
## assembly owns one visible error area. Circuit Builder treats this as one
## region-like node and draws inbound mappings as visual aliases onto it.

const SAMPLE_INPUT_MORPHOLOGY: StringName = &"classifier_sample"
const CLASS_INPUT_MORPHOLOGY: StringName = &"classifier_class"
const INTEGRATED_CIRCUIT_INTERNALS_TOOLTIP: String = "this is an integrated circuit and internals are not visible"


## Sample memory is the classifier face on a region input plate.
static func classifier_plate_input_ids(classifier: GenomeClassifier) -> Array[StringName]:
	var ids: Array[StringName] = []
	if classifier == null or classifier.sample_memory_id == &"":
		return ids
	ids.append(classifier.sample_memory_id)
	return ids


## The error area and each class output sit on a region output plate.
static func classifier_plate_output_ids(classifier: GenomeClassifier) -> Array[StringName]:
	var ids: Array[StringName] = []
	if classifier == null:
		return ids
	if classifier.error_area_id != &"":
		ids.append(classifier.error_area_id)
	for output_id in classifier.class_output_ids():
		if output_id != &"" and output_id not in ids:
			ids.append(output_id)
	return ids


static func classifiers_hosted_by_region(region: BrainRegion) -> Array[GenomeClassifier]:
	var found: Array[GenomeClassifier] = []
	if region == null:
		return found
	for classifier in region.contained_classifiers:
		if classifier not in found:
			found.append(classifier)
	var cache: FEAGILocalCache = _local_cache()
	if cache == null:
		return found
	for item in cache.classifiers.values():
		if not item is GenomeClassifier:
			continue
		var classifier: GenomeClassifier = item as GenomeClassifier
		if classifier in found:
			continue
		if classifier.current_parent_region == region:
			found.append(classifier)
			continue
		for area in region.contained_cortical_areas:
			if classifier.owns_area_id(area.cortical_ID):
				found.append(classifier)
				break
	return found


static func _resolve_plate_area(region: BrainRegion, area_id: StringName) -> AbstractCorticalArea:
	if area_id == &"":
		return null
	if region != null:
		for area in region.contained_cortical_areas:
			if area.cortical_ID == area_id:
				return area
	var cache: FEAGILocalCache = _local_cache()
	if cache == null or cache.cortical_areas == null:
		return null
	return cache.cortical_areas.available_cortical_areas.get(area_id, null)


static func classifier_plate_input_areas(region: BrainRegion) -> Array[AbstractCorticalArea]:
	var areas: Array[AbstractCorticalArea] = []
	for classifier in classifiers_hosted_by_region(region):
		for area_id in classifier_plate_input_ids(classifier):
			var area: AbstractCorticalArea = _resolve_plate_area(region, area_id)
			if area != null and area not in areas:
				areas.append(area)
	return areas


static func classifier_plate_output_areas(region: BrainRegion) -> Array[AbstractCorticalArea]:
	var areas: Array[AbstractCorticalArea] = []
	for classifier in classifiers_hosted_by_region(region):
		for area_id in classifier_plate_output_ids(classifier):
			var area: AbstractCorticalArea = _resolve_plate_area(region, area_id)
			if area != null and area not in areas:
				areas.append(area)
	return areas


static func area_is_classifier_plate_face(area: AbstractCorticalArea, region: BrainRegion) -> bool:
	if area == null or region == null:
		return false
	for candidate in classifier_plate_input_areas(region):
		if candidate.cortical_ID == area.cortical_ID:
			return true
	for candidate in classifier_plate_output_areas(region):
		if candidate.cortical_ID == area.cortical_ID:
			return true
	return false


var classifier_id: StringName:
	get: return _genome_ID

var sample_memory_id: StringName:
	get: return _sample_memory_id
var class_memory_id: StringName:
	get: return _class_memory_id
var error_area_id: StringName:
	get: return _error_area_id
var reward_training: bool:
	get: return _reward_training
var answer_feedback_area_id: StringName:
	get: return _answer_feedback_area_id
var answer_latency_bursts: int:
	get: return _answer_latency_bursts
var learn_area_id: StringName:
	get: return _learn_area_id
var confidence_area_id: StringName:
	get: return _confidence_area_id

var _sample_memory_id: StringName = &""
var _class_memory_id: StringName = &""
var _error_area_id: StringName = &""
var _reward_training: bool = false
var _answer_feedback_area_id: StringName = &""
var _answer_latency_bursts: int = 0
var _learn_area_id: StringName = &""
var _confidence_area_id: StringName = &""
## Episodic upstreams of sample memory. Several inputs hash as one joint pattern.
var _sample_area_ids: Array[StringName] = []
## Each binding is {class_area_id, class_output_area_id}.
var _class_bindings: Array[Dictionary] = []


func _init(
	id: StringName,
	classifier_name: StringName,
	coord_2d: Vector2i,
	coord_3d: Vector3i
) -> void:
	_genome_ID = id
	_friendly_name = classifier_name
	_coordinates_2D = coord_2d
	_coordinates_3D = coord_3d


## Builds a cache object from the FEAGI classifier DTO. Does not create a [BrainRegion].
static func from_feagi_dict(data: Dictionary, parent_region: BrainRegion) -> GenomeClassifier:
	var id: StringName = StringName(str(data.get("classifier_id", "")).strip_edges())
	var classifier_name: StringName = StringName(str(data.get("name", id)))
	var coords_3d: Vector3i = _coords_3d_from_feagi(data.get("coordinates_3d", [0, 0, 0]))
	var classifier := GenomeClassifier.new(id, classifier_name, Vector2i.ZERO, coords_3d)
	classifier.apply_feagi_dict(data)
	if parent_region != null:
		classifier._init_self_to_brain_region(parent_region)
	return classifier


func apply_feagi_dict(data: Dictionary) -> void:
	var next_name: StringName = StringName(str(data.get("name", _friendly_name)))
	FEAGI_change_friendly_name(next_name)
	FEAGI_change_coordinates_3D(_coords_3d_from_feagi(data.get("coordinates_3d", [_coordinates_3D.x, _coordinates_3D.y, _coordinates_3D.z])))
	_sample_memory_id = StringName(str(data.get("sample_memory_id", "")).strip_edges())
	_class_memory_id = StringName(str(data.get("class_memory_id", "")).strip_edges())
	_error_area_id = StringName(str(data.get("error_area_id", "")).strip_edges())
	_sample_area_ids = _id_list_from_feagi(data.get("sample_area_ids", []))
	_class_bindings = _class_bindings_from_feagi(data.get("class_bindings", []))
	_reward_training = bool(data.get("reward_training", false))
	_answer_feedback_area_id = _optional_id(data.get("answer_feedback_area_id", null))
	_answer_latency_bursts = int(data.get("answer_latency_bursts", 0))
	_learn_area_id = _optional_id(data.get("learn_area_id", null))
	_confidence_area_id = _optional_id(data.get("confidence_area_id", null))
	sync_layout_from_stamp()


## Copy 2D layout from the wobbly stamp host (sample memory) when it exists in cache.
func sync_layout_from_stamp() -> void:
	var stamp: AbstractCorticalArea = get_stamp_area()
	if stamp == null:
		return
	FEAGI_change_coordinates_2D(stamp.coordinates_2D)
	FEAGI_change_dimensions_3D(stamp.dimensions_3D)


func get_stamp_area() -> AbstractCorticalArea:
	return _cached_area(_sample_memory_id)


## Sample memory then class memory. Empty when either id is missing.
## Class outputs and the error area are not included: reset clears only these two stores.
func memory_area_ids() -> Array[StringName]:
	if _sample_memory_id == &"" or _class_memory_id == &"":
		return []
	var ids: Array[StringName] = []
	ids.append(_sample_memory_id)
	ids.append(_class_memory_id)
	return ids


## Cached sample and class memory areas. Empty when either area is missing from cache.
func get_memory_areas() -> Array[AbstractCorticalArea]:
	var areas: Array[AbstractCorticalArea] = []
	for area_id in memory_area_ids():
		var area: AbstractCorticalArea = _cached_area(area_id)
		if area == null:
			return []
		areas.append(area)
	return areas


func sample_area_ids() -> Array[StringName]:
	return _sample_area_ids.duplicate()


func class_bindings() -> Array[Dictionary]:
	return _class_bindings.duplicate(true)


func class_output_ids() -> Array[StringName]:
	var output_ids: Array[StringName] = []
	for binding in _class_bindings:
		var output_id: StringName = binding.get("class_output_area_id", &"")
		if output_id != &"":
			output_ids.append(output_id)
	return output_ids


func is_class_output_id(area_id: StringName) -> bool:
	return area_id != &"" and area_id in class_output_ids()


func is_error_area_id(area_id: StringName) -> bool:
	return area_id != &"" and area_id == _error_area_id


func has_sample_input(area_id: StringName) -> bool:
	return area_id != &"" and area_id in _sample_area_ids


func has_class_input(area_id: StringName) -> bool:
	return _binding_for_class(area_id) != null


func get_visible_output_areas() -> Array[AbstractCorticalArea]:
	var outputs: Array[AbstractCorticalArea] = []
	for output_id in class_output_ids():
		var output_area: AbstractCorticalArea = _cached_area(output_id)
		if output_area != null:
			outputs.append(output_area)
	var error_area: AbstractCorticalArea = _cached_area(_error_area_id)
	if error_area != null:
		outputs.append(error_area)
	return outputs


static func is_input_rule(morphology_name: StringName) -> bool:
	return morphology_name == SAMPLE_INPUT_MORPHOLOGY or morphology_name == CLASS_INPUT_MORPHOLOGY


static func input_rule_label(morphology_name: StringName) -> String:
	if morphology_name == SAMPLE_INPUT_MORPHOLOGY:
		return "Classifier Sample"
	if morphology_name == CLASS_INPUT_MORPHOLOGY:
		return "Classifier Class"
	return String(morphology_name)


static func input_rule_morphology(morphology_name: StringName) -> BaseMorphology:
	if not is_input_rule(morphology_name):
		return null
	return _named_input_rule(morphology_name)


static func input_morphologies() -> Array[BaseMorphology]:
	var rules: Array[BaseMorphology] = []
	rules.append(_named_input_rule(SAMPLE_INPUT_MORPHOLOGY))
	rules.append(_named_input_rule(CLASS_INPUT_MORPHOLOGY))
	return rules


## Classifier rules are not catalog morphologies. An unset type is PATTERNS, and the
## pattern editor then casts the object to nil and reads editability_changed.
static func _named_input_rule(morphology_name: StringName) -> BaseMorphology:
	var rule := BaseMorphology.new(morphology_name, true, BaseMorphology.MORPHOLOGY_INTERNAL_CLASS.CORE)
	rule.type = BaseMorphology.MORPHOLOGY_TYPE.FUNCTIONS
	return rule


## Classifier, or its sample/class memory, is a mapping destination.
## Class outputs and the error area stay ordinary areas.
static func classifier_for_mapping_destination(genome_object: GenomeObject, classifiers: Dictionary) -> GenomeClassifier:
	if genome_object is GenomeClassifier:
		return genome_object as GenomeClassifier
	if not genome_object is AbstractCorticalArea:
		return null
	return classifier_for_destination_area_id((genome_object as AbstractCorticalArea).cortical_ID, classifiers)


## Sample memory and class memory accept classifier_sample / classifier_class only.
static func classifier_for_destination_area_id(area_id: StringName, classifiers: Dictionary) -> GenomeClassifier:
	var owner: GenomeClassifier = find_owner_of_area(area_id, classifiers)
	if owner == null:
		return null
	if owner.is_stamp_host_id(area_id) or area_id == owner.class_memory_id:
		return owner
	return null


func memory_id_for_input_rule(morphology_name: StringName) -> StringName:
	if morphology_name == SAMPLE_INPUT_MORPHOLOGY:
		return _sample_memory_id
	if morphology_name == CLASS_INPUT_MORPHOLOGY:
		return _class_memory_id
	return &""


func _cached_area(area_id: StringName) -> AbstractCorticalArea:
	if area_id == &"":
		return null
	var cache: FEAGILocalCache = _local_cache()
	if cache == null or cache.cortical_areas == null:
		return null
	return cache.cortical_areas.available_cortical_areas.get(area_id, null)


static func _local_cache() -> FEAGILocalCache:
	var tree := Engine.get_main_loop()
	if tree == null or not tree is SceneTree:
		return null
	var root: Window = (tree as SceneTree).root
	if root == null or not root.is_inside_tree():
		return null
	var core: Node = root.get_node_or_null("FeagiCore")
	if core == null:
		return null
	return core.get("feagi_local_cache") as FEAGILocalCache


## Owned areas deleted with the classifier: both memories, the error area, and class outputs.
func owned_area_ids() -> Array[StringName]:
	var owned: Array[StringName] = []
	if _sample_memory_id != &"":
		owned.append(_sample_memory_id)
	if _class_memory_id != &"":
		owned.append(_class_memory_id)
	if _error_area_id != &"":
		owned.append(_error_area_id)
	for output_id in class_output_ids():
		owned.append(output_id)
	return owned


## Sample memory hosts the stamp. Class memory is the only hidden internal.
func hidden_owned_area_ids() -> Array[StringName]:
	var hidden: Array[StringName] = []
	if _class_memory_id != &"":
		hidden.append(_class_memory_id)
	return hidden


func owns_area_id(area_id: StringName) -> bool:
	if area_id == &"":
		return false
	return area_id == _sample_memory_id or area_id == _class_memory_id or is_error_area_id(area_id) or is_class_output_id(area_id)


func hides_area_id(area_id: StringName) -> bool:
	if area_id == &"":
		return false
	return area_id == _class_memory_id


func is_stamp_host_id(area_id: StringName) -> bool:
	return area_id != &"" and area_id == _sample_memory_id


## Wobbly stamp size: XY from stored memory neurons, Z from sample-memory temporal depth.
static func stamp_visual_dimensions(memory_neuron_count: int, classifier_depth: int) -> Vector3i:
	var count: int = maxi(memory_neuron_count, 1)
	var side: int = int(ceil(sqrt(float(count))))
	return Vector3i(maxi(side, 1), maxi(side, 1), maxi(classifier_depth, 1))


func references_input_id(area_id: StringName) -> bool:
	if area_id == &"":
		return false
	return has_sample_input(area_id) or has_class_input(area_id)


## Sample and class input ids that should draw a visual inbound line to this object.
func inbound_visual_source_ids() -> Array[StringName]:
	var sources: Array[StringName] = []
	for sample_id in _sample_area_ids:
		if sample_id != &"":
			sources.append(sample_id)
	for binding in _class_bindings:
		var class_id: StringName = binding.get("class_area_id", &"")
		if class_id != &"":
			sources.append(class_id)
	return sources


## Inspector rows for the classifier editor. Never cortical-area neuron parameters.
func details_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	rows.append(_details_row("classifier_id", "Classifier ID", String(classifier_id), false))
	rows.append(_details_row("name", "Classifier Name", String(friendly_name), true))
	var parent_name := ""
	if current_parent_region != null:
		parent_name = String(current_parent_region.friendly_name)
	rows.append(_details_row("parent_circuit", "Parent Circuit", parent_name, true))
	rows.append(_details_row("coordinates_3d", "3D Position", str(coordinates_3D), true))
	rows.append(_details_row("sample_inputs", "Sample Inputs", _named_id_list(_sample_area_ids), false))
	rows.append(_details_row("class_outputs", "Class Outputs", _class_output_names_text(), false))
	rows.append(_details_row("error_area", "Error Area", _area_name(_error_area_id), false))
	rows.append(_details_row("hidden_internals", "Hidden Internals", hidden_internals_text(), false))
	return rows


func _details_row(key: String, label: String, value: String, editable: bool) -> Dictionary:
	return {
		"key": key,
		"label": label,
		"value": value,
		"editable": editable,
	}


func _area_name(area_id: StringName) -> String:
	if area_id == &"":
		return ""
	var cache: FEAGILocalCache = _local_cache()
	if cache != null and cache.cortical_areas != null:
		var area: AbstractCorticalArea = cache.cortical_areas.available_cortical_areas.get(area_id, null)
		if area != null:
			return String(area.friendly_name)
	return String(area_id)


func hidden_internals_text() -> String:
	var names: PackedStringArray = PackedStringArray()
	for area_id in hidden_owned_area_ids():
		names.append(_area_name(area_id))
	return ", ".join(names)


func FEAGI_prepare_delete() -> void:
	about_to_be_deleted.emit()
	if _parent_region != null:
		_parent_region.FEAGI_genome_object_deregister_as_child(self)
		_parent_region = null


## The open-interior control stays disabled on a classifier circuit.
static func circuit_interior_button_enabled(is_classifier_circuit: bool) -> bool:
	return not is_classifier_circuit


## A classifier circuit is the region that contains the classifier, even when the region summary omits the flag.
static func region_hides_interior(region: BrainRegion) -> bool:
	if region == null:
		return false
	if region.is_classifier_circuit:
		return true
	if not region.contained_classifiers.is_empty():
		return true
	for area in region.contained_cortical_areas:
		if area.is_classifier_sample_memory() or area.is_classifier_class_memory() or area.is_classifier_error_output() or area.is_classifier_class_output():
			return true
	var cache: FEAGILocalCache = _local_cache()
	if cache == null:
		return false
	for classifier_id in cache.classifiers.keys():
		var classifier: GenomeClassifier = cache.classifiers[classifier_id] as GenomeClassifier
		if classifier != null and classifier.current_parent_region == region:
			return true
	return false


## True when Circuit Builder must not spawn this area as a sibling cortical node.
## Class outputs and the error area stay visible and connectable.
static func should_hide_area_in_circuit_builder(area: AbstractCorticalArea) -> bool:
	if area == null:
		return false
	return area.is_classifier_internal_memory() or area.is_leftover_classifier_auto_twin()


## Quick-connect guide sticks to the classifier stamp center.
## A different cortical volume in front of the stamp keeps the ray hit.
static func quick_connect_should_anchor_on_stamp(is_classifier_stamp: bool, other_cortical_in_front: bool) -> bool:
	return is_classifier_stamp and not other_cortical_in_front


## A stuck destination owns the guide. Other viewports, including the root scene, must not grow a bridge.
static func quick_connect_should_draw_cross_scene_bridge(destination_end_locked: bool) -> bool:
	return not destination_end_locked


## Memory, interconnect, IPU, and OPU can map onto a classifier.
## Classifier internals and areas this classifier owns cannot.
static func cortical_type_can_feed_classifier(
	kind: AbstractCorticalArea.CORTICAL_AREA_TYPE,
	is_classifier_internal: bool,
	owned_by_destination: bool,
) -> bool:
	if is_classifier_internal or owned_by_destination:
		return false
	return kind == AbstractCorticalArea.CORTICAL_AREA_TYPE.CUSTOM \
		or kind == AbstractCorticalArea.CORTICAL_AREA_TYPE.INTERCONNECT \
		or kind == AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY \
		or kind == AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU \
		or kind == AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU


## Destination click while the source area is still highlighted.
## Ctrl keeps multi-select. Otherwise the classifier is the quick-connect destination.
static func destination_classifier_from_selection(objects: Array[GenomeObject], ctrl_held: bool) -> GenomeClassifier:
	if ctrl_held or objects == null or objects.is_empty():
		return null
	var classifiers: Array[GenomeClassifier] = GenomeObject.filter_classifiers(objects)
	if classifiers.is_empty():
		return null
	return classifiers[0]


## True when Brain Monitor must not spawn this area as a sibling volume.
## Sample memory is the wobbly stamp host. Class outputs and the error area are ordinary volumes.
static func should_hide_area_in_brain_monitor(area: AbstractCorticalArea) -> bool:
	if area == null:
		return false
	if area.is_classifier_sample_memory():
		return false
	return area.is_classifier_class_memory() or area.is_leftover_classifier_auto_twin()


## Remap hidden internals onto the classifier. Class outputs and the error area stay themselves.
static func resolve_visual_connectable(genome_object: GenomeObject, classifiers: Dictionary) -> GenomeObject:
	if genome_object == null:
		return null
	if genome_object is GenomeClassifier:
		return genome_object
	if not genome_object is AbstractCorticalArea:
		return genome_object
	var area_id: StringName = (genome_object as AbstractCorticalArea).cortical_ID
	var owner: GenomeClassifier = find_owner_of_area(area_id, classifiers)
	if owner == null:
		return genome_object
	if owner.is_class_output_id(area_id) or owner.is_error_area_id(area_id):
		return genome_object
	return owner


## Hide the associative edge between the two memories. Visible outputs stay drawn.
static func is_internal_only_classifier_mapping(source: GenomeObject, destination: GenomeObject, classifiers: Dictionary) -> bool:
	if not source is AbstractCorticalArea or not destination is AbstractCorticalArea:
		return false
	var src_id: StringName = (source as AbstractCorticalArea).cortical_ID
	var dst_id: StringName = (destination as AbstractCorticalArea).cortical_ID
	var owner: GenomeClassifier = find_owner_of_area(src_id, classifiers)
	if owner == null:
		return false
	if owner.is_class_output_id(src_id) or owner.is_class_output_id(dst_id):
		return false
	if owner.is_error_area_id(src_id) or owner.is_error_area_id(dst_id):
		return false
	return owner.owns_area_id(dst_id)


## True when Circuit Builder / Brain Monitor should draw classifier → class output or error area.
static func is_visual_output_alias(source: GenomeObject, destination: GenomeObject, classifiers: Dictionary) -> bool:
	if destination == null or not destination is AbstractCorticalArea:
		return false
	var dest_id: StringName = (destination as AbstractCorticalArea).cortical_ID
	var owner: GenomeClassifier = find_owner_of_area(dest_id, classifiers)
	if owner == null:
		return false
	if not owner.is_class_output_id(dest_id) and not owner.is_error_area_id(dest_id):
		return false
	if source is GenomeClassifier:
		return (source as GenomeClassifier).classifier_id == owner.classifier_id
	if source is AbstractCorticalArea:
		return owner.is_stamp_host_id((source as AbstractCorticalArea).cortical_ID)
	return false


## True for inbound aliases: sample or class input → classifier-owned memory.
static func is_visual_inbound_alias(source: GenomeObject, destination: GenomeObject, classifiers: Dictionary) -> bool:
	if not source is AbstractCorticalArea or not destination is AbstractCorticalArea:
		return false
	var src_id: StringName = (source as AbstractCorticalArea).cortical_ID
	var dst_id: StringName = (destination as AbstractCorticalArea).cortical_ID
	var owner: GenomeClassifier = find_owner_of_area(dst_id, classifiers)
	if owner == null:
		return false
	return owner.references_input_id(src_id)


static func find_owner_of_area(area_id: StringName, classifiers: Dictionary) -> GenomeClassifier:
	if area_id == &"":
		return null
	for item in classifiers.values():
		if item is GenomeClassifier and (item as GenomeClassifier).owns_area_id(area_id):
			return item as GenomeClassifier
	return null


static func find_by_id(classifier_id: StringName, classifiers: Dictionary) -> GenomeClassifier:
	if classifier_id == &"":
		return null
	var found: Variant = classifiers.get(classifier_id, null)
	if found is GenomeClassifier:
		return found as GenomeClassifier
	return null


func _class_output_names_text() -> String:
	var names: PackedStringArray = PackedStringArray()
	for binding in _class_bindings:
		var class_label: String = _area_name(binding.get("class_area_id", &""))
		var output_name: String = _area_name(binding.get("class_output_area_id", &""))
		if class_label.is_empty() and output_name.is_empty():
			continue
		names.append("%s -> %s" % [class_label, output_name])
	return ", ".join(names)


func _named_id_list(area_ids: Array[StringName]) -> String:
	var names: PackedStringArray = PackedStringArray()
	for area_id in area_ids:
		names.append(_area_name(area_id))
	return ", ".join(names)


func _binding_for_class(area_id: StringName) -> Variant:
	for binding in _class_bindings:
		if binding.get("class_area_id", &"") == area_id:
			return binding
	return null


static func _id_list_from_feagi(raw: Variant) -> Array[StringName]:
	var ids: Array[StringName] = []
	if not raw is Array:
		return ids
	for item in raw:
		var area_id: StringName = _optional_id(item)
		if area_id != &"":
			ids.append(area_id)
	return ids


static func _class_bindings_from_feagi(raw: Variant) -> Array[Dictionary]:
	var bindings: Array[Dictionary] = []
	if not raw is Array:
		return bindings
	for item in raw:
		if not item is Dictionary:
			continue
		var class_id: StringName = _optional_id((item as Dictionary).get("class_area_id", null))
		var output_id: StringName = StringName(str((item as Dictionary).get("class_output_area_id", "")).strip_edges())
		if class_id == &"":
			continue
		bindings.append({"class_area_id": class_id, "class_output_area_id": output_id})
	return bindings


static func _optional_id(value: Variant) -> StringName:
	if value == null:
		return &""
	var text: String = str(value).strip_edges()
	if text.is_empty() or text == "<null>":
		return &""
	return StringName(text)


static func _coords_3d_from_feagi(value: Variant) -> Vector3i:
	if value is Array and (value as Array).size() >= 3:
		var arr: Array = value as Array
		return Vector3i(int(arr[0]), int(arr[1]), int(arr[2]))
	if value is Vector3i:
		return value
	return Vector3i.ZERO


