extends RefCounted
class_name DeleteAreaApplier
## Snapshots cortical areas before delete, then recreates them and their mappings on undo.


## Reads each area from FEAGI before it is deleted. Returns null when a read fails.
## Areas whose group cannot be created again are omitted.
static func capture(areas: Array[AbstractCorticalArea]) -> DeleteAreaEdit:
	var edit := DeleteAreaEdit.new()
	for area in areas:
		if not DeleteAreaEdit.can_recreate(String(AbstractCorticalArea.cortical_type_to_str(area.cortical_type))):
			continue
		var properties_result: FeagiRequestOutput = await FeagiCore.requests.get_cortical_area(area.cortical_ID)
		if not _accepted(properties_result):
			return null
		var properties: Dictionary = properties_result.decode_response_as_dict().duplicate(true)
		var group := String(properties.get("cortical_group", ""))
		if not DeleteAreaEdit.can_recreate(group):
			continue
		var template_id := ""
		if _is_io_group(group):
			var template: CorticalTemplate = _template_for_area(area, group)
			if template == null:
				continue
			template_id = String(template.ID)
		var parent_id := ""
		if area.current_parent_region != null:
			parent_id = String(area.current_parent_region.region_ID)
		elif properties.has("parent_region_id"):
			parent_id = String(properties["parent_region_id"])
		edit.add_area({
			"original_id": String(area.cortical_ID),
			"restored_id": "",
			"parent_region_id": parent_id,
			"coordinates_2d": area.coordinates_2D,
			"coordinates_2d_defined": area.is_coordinates_2D_available,
			"unit_id": area.unit_id,
			"template_id": template_id,
			"properties": properties,
			"incoming": _incoming_mappings(area),
		})
	return edit


## forward deletes the restored areas again. Backward creates them and writes mappings.
static func apply(edit: DeleteAreaEdit, forward: bool) -> Dictionary:
	if edit == null or edit.is_empty():
		return {"ok": false, "save_failed": false}
	if FeagiCore == null or FeagiCore.requests == null or FeagiCore.feagi_local_cache == null:
		return {"ok": false, "save_failed": false}
	if forward:
		if not await _delete_restored(edit):
			return {"ok": false, "save_failed": false}
		edit.clear_restored_ids()
	else:
		if not await _recreate(edit):
			return {"ok": false, "save_failed": false}
	var save_result: FeagiRequestOutput = await FeagiCore.requests.save_genome()
	return {"ok": true, "save_failed": save_result == null or save_result.has_errored}


static func _recreate(edit: DeleteAreaEdit) -> bool:
	for index in edit.area_count():
		if not await _ensure_created(edit, index):
			return false
	for index in edit.area_count():
		if not await _restore_properties(edit, index):
			return false
	for write in edit.mapping_writes():
		var rules: Array = write["rules"]
		if rules.is_empty():
			continue
		var mapping_result: FeagiRequestOutput = await FeagiCore.requests.restore_mapping_rules(
			StringName(String(write["source_id"])),
			StringName(String(write["destination_id"])),
			rules
		)
		if not _accepted(mapping_result):
			return false
	return true


static func _ensure_created(edit: DeleteAreaEdit, index: int) -> bool:
	var restored := edit.restored_id_at(index)
	if restored != "" and _cortical_area(StringName(restored)) != null:
		return true
	var snapshot: Dictionary = edit.snapshot_at(index)
	var properties: Dictionary = snapshot["properties"]
	var parsed_position: Dictionary = PositionEdit.parse_vector3i(properties.get("coordinates_3d", null))
	var parsed_dimensions: Dictionary = PositionEdit.parse_vector3i(properties.get("cortical_dimensions", null))
	if not bool(parsed_position.get("ok", false)) or not bool(parsed_dimensions.get("ok", false)):
		push_error("Delete undo: cortical area %s is missing coordinates or dimensions" % edit.original_id_at(index))
		return false
	if not properties.has("cortical_name"):
		push_error("Delete undo: cortical area %s is missing its name" % edit.original_id_at(index))
		return false
	var parent: BrainRegion = _brain_region(StringName(String(snapshot["parent_region_id"])))
	if parent == null:
		push_error("Delete undo: parent circuit %s is not loaded" % snapshot["parent_region_id"])
		return false
	var group := String(properties.get("cortical_group", "")).to_upper()
	var created: FeagiRequestOutput = await _create_area(snapshot, properties, parent, group, parsed_position["value"], parsed_dimensions["value"])
	if not _accepted(created):
		return false
	var response: Dictionary = created.decode_response_as_dict()
	var new_id := String(response.get("cortical_id", ""))
	if new_id == "":
		push_error("Delete undo: FEAGI created %s without returning an id" % properties["cortical_name"])
		return false
	edit.set_restored_id(index, new_id)
	return true


static func _create_area(snapshot: Dictionary, properties: Dictionary, parent: BrainRegion, group: String, position: Vector3i, dimensions: Vector3i) -> FeagiRequestOutput:
	var cortical_name := StringName(String(properties["cortical_name"]))
	var coordinates_2d: Vector2i = snapshot["coordinates_2d"]
	var coordinates_2d_defined: bool = bool(snapshot["coordinates_2d_defined"])
	if group == "MEMORY":
		return await FeagiCore.requests.add_custom_memory_cortical_area(cortical_name, position, dimensions, parent, coordinates_2d_defined, coordinates_2d)
	if group == "IPU" or group == "OPU":
		var template: CorticalTemplate = _template_by_id(StringName(String(snapshot.get("template_id", ""))), group)
		if template == null:
			push_error("Delete undo: no I/O template for %s" % snapshot["original_id"])
			return null
		var device_count_field: Dictionary = _find_property(properties, "dev_count")
		if not bool(device_count_field.get("ok", false)):
			device_count_field = _find_property(properties, "device_count")
		var neurons_field: Dictionary = _find_property(properties, "neurons_per_voxel")
		if not bool(device_count_field.get("ok", false)) or not bool(neurons_field.get("ok", false)):
			push_error("Delete undo: I/O area %s is missing its channel count or neurons per voxel" % snapshot["original_id"])
			return null
		var unit_id := int(snapshot["unit_id"])
		if unit_id < 0:
			push_error("Delete undo: I/O area %s is missing its unit index" % snapshot["original_id"])
			return null
		var data_types: Dictionary = {}
		var data_type_field: Dictionary = _find_property(properties, "data_type_configs_by_subunit")
		if bool(data_type_field.get("ok", false)):
			if not (data_type_field["value"] is Dictionary):
				push_error("Delete undo: I/O area %s has an unreadable subunit data type config" % snapshot["original_id"])
				return null
			data_types = data_type_field["value"]
		return await FeagiCore.requests.add_IOPU_cortical_area(template, int(device_count_field["value"]), position, coordinates_2d_defined, coordinates_2d, unit_id, int(neurons_field["value"]), data_types)
	return await FeagiCore.requests.add_custom_cortical_area(cortical_name, position, dimensions, parent, coordinates_2d_defined, coordinates_2d)


static func _restore_properties(edit: DeleteAreaEdit, index: int) -> bool:
	var payload: Dictionary = DeleteAreaEdit.update_payload(edit.snapshot_at(index)["properties"])
	payload = DeleteAreaEdit.remap_value(payload, edit.id_map())
	if payload.is_empty():
		return true
	var restored_id := StringName(edit.restored_id_at(index))
	var result: FeagiRequestOutput = await FeagiCore.requests.update_cortical_area(restored_id, payload.duplicate(true))
	if not _accepted(result):
		return false
	var response: Dictionary = result.decode_response_as_dict()
	var updated_id := String(response.get("cortical_id", restored_id))
	if updated_id != "" and updated_id != String(restored_id):
		edit.set_restored_id(index, updated_id)
	return true


static func _delete_restored(edit: DeleteAreaEdit) -> bool:
	var areas: Array[AbstractCorticalArea] = []
	for index in edit.area_count():
		var restored := edit.restored_id_at(index)
		if restored == "":
			push_error("Delete redo: area %s has not been restored" % edit.original_id_at(index))
			return false
		var area: AbstractCorticalArea = _cortical_area(StringName(restored))
		if area == null:
			push_error("Delete redo: restored area %s is not loaded" % restored)
			return false
		areas.append(area)
	var result: FeagiRequestOutput
	if areas.size() == 1:
		result = await FeagiCore.requests.delete_cortical_area(areas[0])
	else:
		result = await FeagiCore.requests.mass_delete_cortical_areas(areas)
	return _accepted(result)


static func _incoming_mappings(area: AbstractCorticalArea) -> Array:
	var incoming: Array = []
	for source in area.afferent_mappings.keys():
		if not (source is AbstractCorticalArea):
			continue
		var source_area := source as AbstractCorticalArea
		if source_area.cortical_ID == area.cortical_ID:
			continue
		var mapping_set: InterCorticalMappingSet = area.afferent_mappings[source]
		incoming.append({
			"source_id": String(source_area.cortical_ID),
			"rules": SingleMappingDefinition.to_FEAGI_JSON_array(mapping_set.mappings),
		})
	return incoming


static func _is_io_group(group: String) -> bool:
	var normalized := group.to_upper()
	return normalized == "IPU" or normalized == "OPU"


static func _template_for_area(area: AbstractCorticalArea, group: String) -> CorticalTemplate:
	var by_id: CorticalTemplate = _template_by_id(area.cortical_ID, group)
	if by_id != null:
		return by_id
	if area.cortical_subtype == "":
		return null
	return _template_by_id(StringName(area.cortical_subtype), group)


static func _template_by_id(template_id: StringName, group: String) -> CorticalTemplate:
	if template_id == &"":
		return null
	var templates: Dictionary = FeagiCore.feagi_local_cache.OPU_templates if group.to_upper() == "OPU" else FeagiCore.feagi_local_cache.IPU_templates
	var found: Variant = templates.get(template_id, null)
	if found is CorticalTemplate:
		return found as CorticalTemplate
	return null


static func _find_property(properties: Dictionary, key: String) -> Dictionary:
	if properties.has(key):
		return {"ok": true, "value": properties[key]}
	var bag: Variant = properties.get("properties", {})
	if bag is Dictionary and (bag as Dictionary).has(key):
		return {"ok": true, "value": (bag as Dictionary)[key]}
	return {"ok": false}


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


static func _accepted(result: FeagiRequestOutput) -> bool:
	return result != null and not result.has_errored and result.success and not result.failed_requirement
