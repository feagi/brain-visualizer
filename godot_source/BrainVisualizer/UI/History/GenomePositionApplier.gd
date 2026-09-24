extends RefCounted
class_name GenomePositionApplier
## Writes a PositionEdit forward or backward through the same FEAGI coordinate calls used by the original gesture.


## Returns {ok, save_failed}. ok means every coordinate write was accepted.
static func apply(edit: PositionEdit, forward: bool) -> Dictionary:
	if edit == null or edit.is_empty():
		return {"ok": false, "save_failed": false}
	if FeagiCore == null or FeagiCore.requests == null or FeagiCore.feagi_local_cache == null:
		return {"ok": false, "save_failed": false}
	var area_moves_2d: Dictionary = {}
	var region_moves_2d: Dictionary = {}
	for index in edit.entry_count():
		var entry: Dictionary = edit.entry_at(index)
		var object_id: StringName = entry["id"]
		var kind: int = int(entry["kind"])
		var space: int = int(entry["space"])
		if space == PositionEdit.SPACE_3D:
			var position_3d: Vector3i = edit.vector_at(index, forward)
			if kind == PositionEdit.KIND_CORTICAL_AREA:
				if not await _apply_cortical_3d(object_id, position_3d):
					return {"ok": false, "save_failed": false}
			elif kind == PositionEdit.KIND_BRAIN_REGION:
				if not await _apply_region_3d(object_id, position_3d):
					return {"ok": false, "save_failed": false}
			else:
				return {"ok": false, "save_failed": false}
			continue
		if space != PositionEdit.SPACE_2D:
			return {"ok": false, "save_failed": false}
		var position_2d: Vector2i = edit.vector_at(index, forward)
		if kind == PositionEdit.KIND_CORTICAL_AREA:
			var area: AbstractCorticalArea = _cortical_area(object_id)
			if area == null:
				return {"ok": false, "save_failed": false}
			area_moves_2d[area] = position_2d
		elif kind == PositionEdit.KIND_BRAIN_REGION:
			var region: BrainRegion = _brain_region(object_id)
			if region == null:
				return {"ok": false, "save_failed": false}
			region_moves_2d[region] = position_2d
		else:
			return {"ok": false, "save_failed": false}
	if not area_moves_2d.is_empty():
		var area_result: FeagiRequestOutput = await FeagiCore.requests.mass_move_genome_objects_2D(area_moves_2d)
		if area_result == null or area_result.has_errored:
			return {"ok": false, "save_failed": false}
		for area in area_moves_2d.keys():
			var moved_area := area as AbstractCorticalArea
			moved_area.FEAGI_change_coordinates_2D(area_moves_2d[area])
			_sync_classifier_stamp(moved_area)
	if not region_moves_2d.is_empty():
		var region_result: FeagiRequestOutput = await FeagiCore.requests.mass_move_genome_objects_2D(region_moves_2d)
		if region_result == null or region_result.has_errored:
			return {"ok": false, "save_failed": false}
		for region in region_moves_2d.keys():
			var moved_region := region as BrainRegion
			moved_region.FEAGI_change_coordinates_2D(region_moves_2d[region])
	var save_result: FeagiRequestOutput = await FeagiCore.requests.save_genome()
	return {"ok": true, "save_failed": save_result == null or save_result.has_errored}


static func _apply_cortical_3d(cortical_id: StringName, position: Vector3i) -> bool:
	var area: AbstractCorticalArea = _cortical_area(cortical_id)
	if area == null:
		return false
	var payload := {"coordinates_3d": FEAGIUtils.vector3i_to_array(position)}
	var result: FeagiRequestOutput = await FeagiCore.requests.update_cortical_area(cortical_id, payload)
	if result == null or result.has_errored:
		return false
	area.FEAGI_change_coordinates_3D(position)
	return true


static func _apply_region_3d(region_id: StringName, position: Vector3i) -> bool:
	var region: BrainRegion = _brain_region(region_id)
	if region == null or region.current_parent_region == null:
		return false
	var result: FeagiRequestOutput = await FeagiCore.requests.edit_region_object(
		region,
		region.current_parent_region,
		region.friendly_name,
		region.description,
		region.coordinates_2D,
		position
	)
	if result == null or result.has_errored:
		return false
	region.FEAGI_change_coordinates_3D(position)
	return true


static func _cortical_area(cortical_id: StringName) -> AbstractCorticalArea:
	var areas: Dictionary = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas
	var found: Variant = areas.get(cortical_id, null)
	if found is AbstractCorticalArea:
		return found as AbstractCorticalArea
	return null


static func _brain_region(region_id: StringName) -> BrainRegion:
	var regions: Dictionary = FeagiCore.feagi_local_cache.brain_regions.available_brain_regions
	var found: Variant = regions.get(region_id, null)
	if found is BrainRegion:
		return found as BrainRegion
	return null


static func _sync_classifier_stamp(area: AbstractCorticalArea) -> void:
	var classifiers: Dictionary = FeagiCore.feagi_local_cache.classifiers
	var owner: GenomeClassifier = GenomeClassifier.find_owner_of_area(area.cortical_ID, classifiers)
	if owner == null or not owner.is_stamp_host_id(area.cortical_ID):
		return
	owner.sync_layout_from_stamp()
