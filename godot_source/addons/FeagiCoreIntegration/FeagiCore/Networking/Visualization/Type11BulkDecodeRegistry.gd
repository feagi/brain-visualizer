extends RefCounted
class_name Type11BulkDecodeRegistry
## Cortical IDs whose Type 11 data must be decoded into arrays as well as applied by the MultiMesh
## fast path. Two kinds of entries:
## - area-derived: memory areas and areas drawn by more than one renderer. Rescanned only after
##   [method invalidate_areas] or a DirectPoints renderer (un)registration, never per packet.
## - named sources (firing recorder, live inspector), set by their owners with [method set_source_ids].
## IDs are stored lowercase; the Rust filter compares case-insensitively.

const SOURCE_RECORDER: StringName = &"recorder"
const SOURCE_LIVE_INSPECTOR: StringName = &"live_inspector"

var _source_ids: Dictionary = {} # StringName source -> {lowercase cortical id: true}
var _area_ids: Dictionary = {} # lowercase cortical id -> true
var _areas_dirty: bool = true
var _renderer_generation_seen: int = -1
var _merged: PackedStringArray = []
var _merged_dirty: bool = true


## Replace the IDs registered under [param source]. An empty list removes the source.
func set_source_ids(source: StringName, cortical_ids: Array) -> void:
	var ids: Dictionary = {}
	for cortical_id in cortical_ids:
		var clean := String(cortical_id).strip_edges().to_lower()
		if not clean.is_empty():
			ids[clean] = true
	if ids.is_empty():
		_source_ids.erase(source)
	else:
		_source_ids[source] = ids
	_merged_dirty = true


func clear_source(source: StringName) -> void:
	set_source_ids(source, [])


func source_has(source: StringName, cortical_id: String) -> bool:
	var ids: Dictionary = _source_ids.get(source, {})
	return ids.has(cortical_id.to_lower())


## Call when cortical areas are added, removed or reloaded.
func invalidate_areas() -> void:
	_areas_dirty = true


## Every cortical ID that needs decoded arrays this packet. Empty means skip the decode.
func get_ids() -> PackedStringArray:
	_refresh_area_ids()
	if _merged_dirty:
		var merged: Dictionary = _area_ids.duplicate()
		for ids in _source_ids.values():
			merged.merge(ids)
		_merged = PackedStringArray(merged.keys())
		_merged_dirty = false
	return _merged


func _refresh_area_ids() -> void:
	if not _areas_dirty and _renderer_generation_seen == AbstractCorticalArea.bv_directpoints_registration_generation:
		return
	_area_ids.clear()
	if FeagiCore.feagi_local_cache != null:
		var areas: Dictionary = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas
		for cortical_id in areas.keys():
			var area: AbstractCorticalArea = areas[cortical_id]
			if area == null:
				continue
			if area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY or area.BV_requires_bulk_directpoints_updates():
				_area_ids[String(cortical_id).to_lower()] = true
	# Read after the scan: BV_requires_bulk_directpoints_updates() may prune freed renderers and bump it.
	_renderer_generation_seen = AbstractCorticalArea.bv_directpoints_registration_generation
	_areas_dirty = false
	_merged_dirty = true
