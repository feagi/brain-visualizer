extends RefCounted
class_name SchematicTreeBuilder
## Builds a [SchematicModel] from the FEAGI local cache: every region, the cortical areas and
## classifiers Circuit Builder would show, and every established mapping with at least one rule.
## Regions whose interior is hidden (classifier circuits) are added closed, without children.

const TYPE_COLORS: Dictionary = {
	AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU: CBNodeCorticalArea.IPU_BOX_COLOR,
	AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY: CBNodeCorticalArea.MEMORY_BOX_COLOR,
	AbstractCorticalArea.CORTICAL_AREA_TYPE.CUSTOM: CBNodeCorticalArea.CUSTOM_BOX_COLOR,
	AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU: CBNodeCorticalArea.OPU_BOX_COLOR,
	AbstractCorticalArea.CORTICAL_AREA_TYPE.CORE: CBNodeCorticalArea.CORE_BOX_COLOR,
	AbstractCorticalArea.CORTICAL_AREA_TYPE.MODULATOR: CBNodeCorticalArea.CORE_BOX_COLOR,
}
const CLASSIFIER_COLOR: Color = Color(0.36, 0.25, 0.55)
const OTHER_AREA_COLOR: Color = Color(0.3, 0.3, 0.3)


## Returns null when no genome is loaded.
static func build_from_cache() -> SchematicModel:
	if FeagiCore == null or FeagiCore.feagi_local_cache == null or FeagiCore.feagi_local_cache.brain_regions == null:
		return null
	var cache: FEAGILocalCache = FeagiCore.feagi_local_cache
	var root: BrainRegion = cache.brain_regions.get_root_region()
	if root == null:
		return null
	var model: SchematicModel = SchematicModel.new()
	var index_of: Dictionary = {}
	_add_region(model, root, -1, index_of)
	var established: Dictionary = cache.mapping_data.established_mappings
	for source_id in established.keys():
		for destination_id in established[source_id].keys():
			var mapping_set: InterCorticalMappingSet = established[source_id][destination_id] as InterCorticalMappingSet
			if mapping_set == null or mapping_set.number_mappings == 0:
				continue
			var source: AbstractCorticalArea = mapping_set.source_cortical_area
			var destination: AbstractCorticalArea = mapping_set.destination_cortical_area
			if GenomeClassifier.is_internal_only_classifier_mapping(source, destination, cache.classifiers):
				continue
			var from: int = _item_for(source, index_of, cache)
			var to: int = _item_for(destination, index_of, cache)
			if from == -1 or to == -1:
				continue
			model.add_mapping(from, to, _line_kind(mapping_set))
	model.finish()
	return model


## Same order Circuit Builder adds nodes in: areas, then child regions, then classifiers.
static func _add_region(model: SchematicModel, region: BrainRegion, parent: int, index_of: Dictionary) -> void:
	var closed_only: bool = parent != -1 and GenomeClassifier.region_hides_interior(region)
	var index: int = model.add_item(SchematicModel.KIND.REGION, String(region.friendly_name), parent, region,
		{"saved_position": Vector2(region.coordinates_2D), "closed_only": closed_only})
	index_of[region] = index
	if closed_only:
		return
	for area: AbstractCorticalArea in region.contained_cortical_areas:
		if GenomeClassifier.should_hide_area_in_circuit_builder(area):
			continue
		var column: LayeredGraphLayout.COLUMN = CorticalLayoutSide.layout_column(area)
		var priority: int = 0
		if column != LayeredGraphLayout.COLUMN.MIDDLE:
			priority = CorticalLayoutSide.io_priority(area, column == LayeredGraphLayout.COLUMN.INPUT)
		index_of[area] = model.add_item(SchematicModel.KIND.AREA, String(area.friendly_name), index, area,
			{"column": column, "priority": priority, "saved_position": Vector2(area.coordinates_2D),
			"color": TYPE_COLORS.get(area.cortical_type, OTHER_AREA_COLOR)})
	for subregion: BrainRegion in region.contained_regions:
		_add_region(model, subregion, index, index_of)
	for classifier: GenomeClassifier in region.contained_classifiers:
		index_of[classifier] = model.add_item(SchematicModel.KIND.CLASSIFIER, String(classifier.friendly_name), index, classifier,
			{"saved_position": Vector2(classifier.coordinates_2D), "color": CLASSIFIER_COLOR})


## The item that stands for [param object]: itself, the classifier that hides it, or the nearest
## region above it that is in the model (for areas inside a closed classifier circuit).
static func _item_for(object: GenomeObject, index_of: Dictionary, cache: FEAGILocalCache) -> int:
	var resolved: GenomeObject = cache.resolve_visual_connectable(object)
	if resolved != null and index_of.has(resolved):
		return index_of[resolved]
	var region: BrainRegion = object.current_parent_region
	while region != null:
		if index_of.has(region):
			return index_of[region]
		region = region.current_parent_region
	return -1


## Matches Circuit Builder's line colours: episodic first, then any negative weight, else excitatory.
static func _line_kind(mapping_set: InterCorticalMappingSet) -> SchematicModel.LINE_KIND:
	if mapping_set.is_every_mapping_episodic():
		return SchematicModel.LINE_KIND.EPISODIC
	if mapping_set.is_any_PSP_multiplier_negative():
		return SchematicModel.LINE_KIND.INHIBITORY
	return SchematicModel.LINE_KIND.EXCITATORY
