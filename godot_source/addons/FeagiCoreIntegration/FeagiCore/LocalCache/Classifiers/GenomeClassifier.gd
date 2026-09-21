extends GenomeObject
class_name GenomeClassifier
## First-class BV object for a genome classifier assembly.
## Not a [BrainRegion] and not a cortical area. Class memory stays hidden; kernel
## memory is the wobbly stamp. The class-map twin stays a connectable cortical
## area. Inputs stay in [member parent_region_id]. Circuit Builder treats this as
## one region-like node and draws inbound mappings as visual aliases onto it.

var classifier_id: StringName:
	get: return _genome_ID

var kernel_area_id: StringName:
	get: return _kernel_area_id
var class_area_id: StringName:
	get: return _class_area_id
var field_area_id: StringName:
	get: return _field_area_id
var kernel_memory_id: StringName:
	get: return _kernel_memory_id
var class_memory_id: StringName:
	get: return _class_memory_id
var scan_twin_id: StringName:
	get: return _scan_twin_id

var _kernel_area_id: StringName = &""
var _class_area_id: StringName = &""
var _field_area_id: StringName = &""
var _kernel_memory_id: StringName = &""
var _class_memory_id: StringName = &""
var _scan_twin_id: StringName = &""


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
	_kernel_area_id = _optional_id(data.get("kernel_area_id", null))
	_class_area_id = _optional_id(data.get("class_area_id", null))
	_field_area_id = _optional_id(data.get("field_area_id", null))
	_kernel_memory_id = StringName(str(data.get("kernel_memory_id", "")))
	_class_memory_id = StringName(str(data.get("class_memory_id", "")))
	_scan_twin_id = StringName(str(data.get("scan_twin_id", "")))
	sync_layout_from_stamp()


## Copy 2D layout from the wobbly stamp host (kernel memory) when it exists in cache.
func sync_layout_from_stamp() -> void:
	var stamp: AbstractCorticalArea = get_stamp_area()
	if stamp == null:
		return
	FEAGI_change_coordinates_2D(stamp.coordinates_2D)
	FEAGI_change_dimensions_3D(stamp.dimensions_3D)


func get_stamp_area() -> AbstractCorticalArea:
	return _cached_area(_kernel_memory_id)


func get_twin_area() -> AbstractCorticalArea:
	return _cached_area(_scan_twin_id)


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


## Owned internals deleted with the classifier (kernel_mem, class_mem, class-map twin).
func owned_area_ids() -> Array[StringName]:
	var owned: Array[StringName] = []
	if _kernel_memory_id != &"":
		owned.append(_kernel_memory_id)
	if _class_memory_id != &"":
		owned.append(_class_memory_id)
	if _scan_twin_id != &"":
		owned.append(_scan_twin_id)
	return owned


## Hidden internals only. The class-map twin stays a visible, connectable cortical area.
func hidden_owned_area_ids() -> Array[StringName]:
	var hidden: Array[StringName] = []
	if _kernel_memory_id != &"":
		hidden.append(_kernel_memory_id)
	if _class_memory_id != &"":
		hidden.append(_class_memory_id)
	return hidden


func owns_area_id(area_id: StringName) -> bool:
	if area_id == &"":
		return false
	return area_id == _kernel_memory_id or area_id == _class_memory_id or area_id == _scan_twin_id


func hides_area_id(area_id: StringName) -> bool:
	if area_id == &"":
		return false
	return area_id == _class_memory_id


func is_stamp_host_id(area_id: StringName) -> bool:
	return area_id != &"" and area_id == _kernel_memory_id


## Wobbly stamp size: XY from stored memory neurons, Z from classifier temporal depth.
static func stamp_visual_dimensions(memory_neuron_count: int, classifier_depth: int) -> Vector3i:
	var count: int = maxi(memory_neuron_count, 1)
	var side: int = int(ceil(sqrt(float(count))))
	return Vector3i(maxi(side, 1), maxi(side, 1), maxi(classifier_depth, 1))


func references_input_id(area_id: StringName) -> bool:
	if area_id == &"":
		return false
	return area_id == _kernel_area_id or area_id == _class_area_id or area_id == _field_area_id


## Kernel / class / field area IDs that should draw a visual inbound line to this object.
func inbound_visual_source_ids() -> Array[StringName]:
	var sources: Array[StringName] = []
	if _kernel_area_id != &"":
		sources.append(_kernel_area_id)
	if _class_area_id != &"":
		sources.append(_class_area_id)
	if _field_area_id != &"":
		sources.append(_field_area_id)
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
	rows.append(_details_row("kernel_area", "Kernel Area", _area_name(_kernel_area_id), true))
	rows.append(_details_row("class_area", "Class Area", _area_name(_class_area_id), true))
	rows.append(_details_row("field_area", "Field Area", _area_name(_field_area_id), true))
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


## True when Circuit Builder must not spawn this area as a sibling cortical node.
## The class-map twin stays visible and connectable.
static func should_hide_area_in_circuit_builder(area: AbstractCorticalArea) -> bool:
	if area == null:
		return false
	return area.is_classifier_internal_memory() or area.is_leftover_classifier_auto_twin()


## True when Brain Monitor must not spawn this area as a sibling volume.
## Kernel memory is the wobbly stamp host. The twin is a classical cortical volume.
static func should_hide_area_in_brain_monitor(area: AbstractCorticalArea) -> bool:
	if area == null:
		return false
	if area.is_classifier_kernel_memory():
		return false
	return area.is_classifier_class_memory() or area.is_leftover_classifier_auto_twin()


## Remap hidden internals onto the classifier. The class-map twin stays itself.
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
	if owner.scan_twin_id == area_id:
		return genome_object
	return owner


## Hide mem-to-mem internals (both ends owned by the same classifier).
## The class-map twin is a visible interconnect; mappings to/from it stay drawn.
static func is_internal_only_classifier_mapping(source: GenomeObject, destination: GenomeObject, classifiers: Dictionary) -> bool:
	if not source is AbstractCorticalArea or not destination is AbstractCorticalArea:
		return false
	var src_id: StringName = (source as AbstractCorticalArea).cortical_ID
	var dst_id: StringName = (destination as AbstractCorticalArea).cortical_ID
	var owner: GenomeClassifier = find_owner_of_area(src_id, classifiers)
	if owner == null:
		return false
	if owner.scan_twin_id == src_id or owner.scan_twin_id == dst_id:
		return false
	return owner.owns_area_id(dst_id)


## True when Circuit Builder / Brain Monitor should draw classifier → twin.
static func is_visual_twin_alias(source: GenomeObject, destination: GenomeObject, classifiers: Dictionary) -> bool:
	if destination == null or not destination is AbstractCorticalArea:
		return false
	var dest_id: StringName = (destination as AbstractCorticalArea).cortical_ID
	var owner: GenomeClassifier = find_owner_of_area(dest_id, classifiers)
	if owner == null or owner.scan_twin_id != dest_id:
		return false
	if source is GenomeClassifier:
		return (source as GenomeClassifier).classifier_id == owner.classifier_id
	if source is AbstractCorticalArea:
		return owner.is_stamp_host_id((source as AbstractCorticalArea).cortical_ID)
	return false


## True for the three inbound aliases: kernel/class/field → classifier-owned dest.
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
