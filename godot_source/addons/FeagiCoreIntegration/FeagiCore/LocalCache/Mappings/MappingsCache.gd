extends RefCounted
class_name MappingsCache

signal mapping_created(mapping: InterCorticalMappingSet)
signal mapping_updated(mapping: InterCorticalMappingSet)

## Ways to describe the set of [MappingProperty]s
enum SIGNAL_TYPE{
	EXCITATORY,
	INHIBITORY,
	MIXED
}

var established_mappings: Dictionary: # Mappings Established in the FEAGI Connectom, key'd by source_cortical_ID -> destination_cortical_ID -> [MappingProperties]
	get: return _established_mappings

var _established_mappings: Dictionary


## Match a cortical id from HTTP JSON (often [String]) to a key in [CorticalAreasCache.available_cortical_areas] ([StringName]).
func _resolve_cortical_cache_key(ambiguous_id: Variant) -> Variant:
	if FeagiCore == null or FeagiCore.feagi_local_cache == null:
		return null
	var areas: Dictionary = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas
	if areas.has(ambiguous_id):
		return ambiguous_id
	var token: String = String(ambiguous_id).strip_edges()
	if token.is_empty():
		return null
	for k in areas.keys():
		if String(k) == token:
			return k
	return null


## cortical_mapping_dst may store one rule as a JSON object or as an array of rules.
## Returns [null] on parse failure, or an [Array] (possibly empty) of rules.
func _normalize_mapping_rules_to_array(raw: Variant) -> Variant:
	if raw is Array:
		var out: Array = []
		out.assign(raw)
		return out
	if raw is Dictionary:
		var d: Dictionary = raw as Dictionary
		if d.has("morphology_id") or d.has("morphology_scalar"):
			return [d]
		push_warning(
			"FEAGI CACHE: Mapping rules dict missing morphology fields; keys=%s — skipping edge"
			% str(d.keys())
		)
		return null
	push_warning(
		"FEAGI CACHE: Unsupported mapping rules type %s — skipping edge"
		% type_string(typeof(raw))
	)
	return null


## Retrieved the mapping data between 2 cortical areas from FEAGI, use this to update the cache
func FEAGI_set_mapping_JSON(source: AbstractCorticalArea, destination: AbstractCorticalArea, mappings_JSON: Array) -> void:
	# IMPORTANT: An empty mapping list from FEAGI means the mapping does not exist.
	# If we currently have a mapping-set cached, treat this as a deletion so that
	# cortical areas emit their *_removed signals and UI stays in sync.
	if len(mappings_JSON) == 0:
		if source.cortical_ID in _established_mappings.keys() and destination.cortical_ID in _established_mappings[source.cortical_ID].keys():
			FEAGI_delete_mappings(source, destination)
		return
	
	if not _established_mappings.has(source.cortical_ID):
		_established_mappings[source.cortical_ID] = {}
	
	if destination.cortical_ID in _established_mappings[source.cortical_ID].keys():
		## Mapping exists, update it!
		(_established_mappings[source.cortical_ID][destination.cortical_ID] as InterCorticalMappingSet).FEAGI_updated_mappings_JSON(mappings_JSON)
		mapping_updated.emit(_established_mappings[source.cortical_ID][destination.cortical_ID])
		return
	
	## Mapping doesn't exist, create it!
	var mapping_set := InterCorticalMappingSet.from_FEAGI_JSON(mappings_JSON, source, destination)
	if mapping_set == null:
		return
	_established_mappings[source.cortical_ID][destination.cortical_ID] = mapping_set
	mapping_created.emit(mapping_set)

## Retrieved the mapping data between 2 cortical areas from FEAGI, use this to update the cache
func FEAGI_set_mapping(source: AbstractCorticalArea, destination: AbstractCorticalArea, new_mappings: Array[SingleMappingDefinition]):
	if len(new_mappings) == 0:
		# No mappings between cortical areas, likely a deletion action
		FEAGI_delete_mappings(source, destination)
		return
	if not _established_mappings.has(source.cortical_ID):
		_established_mappings[source.cortical_ID] = {}
	if destination.cortical_ID in _established_mappings[source.cortical_ID].keys():
		## Mapping exists, update it!
		(_established_mappings[source.cortical_ID][destination.cortical_ID] as InterCorticalMappingSet).FEAGI_updated_mappings(new_mappings)
		mapping_updated.emit(_established_mappings[source.cortical_ID][destination.cortical_ID])
	else:
		## Mapping doesn't exist, create it!	
		_established_mappings[source.cortical_ID][destination.cortical_ID] = InterCorticalMappingSet.new(source, destination, new_mappings)
		mapping_created.emit(_established_mappings[source.cortical_ID][destination.cortical_ID])

## Load in all mappings from summary data. Called from [FEAGILocalCache] when loading genome
func FEAGI_load_all_mappings(mapping_summary: Dictionary)-> void:
	for raw_source in mapping_summary.keys():
		var source_cortical_ID: Variant = _resolve_cortical_cache_key(raw_source)
		if source_cortical_ID == null:
			push_error("FEAGI CACHE: Mapping refers to nonexistant cortical area %s! Skipping!" % raw_source)
			continue

		var mapping_targets: Dictionary = mapping_summary[raw_source]
		for raw_destination in mapping_targets.keys():
			var destination_cortical_ID: Variant = _resolve_cortical_cache_key(raw_destination)
			if destination_cortical_ID == null:
				push_error("FEAGI CACHE: Mapping refers to nonexistant cortical area %s! Skipping!" % raw_destination)
				continue
			#NOTE: Instead of verifying the morphology exists, we will allow [MappingProperty]'s  system handle it, as it has a fallback should it not be found
			var source_area: AbstractCorticalArea = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas[source_cortical_ID]
			var destination_area: AbstractCorticalArea = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas[destination_cortical_ID]
			var normalized: Variant = _normalize_mapping_rules_to_array(
				mapping_targets[destination_cortical_ID]
			)
			if normalized == null:
				continue
			FEAGI_set_mapping_JSON(source_area, destination_area, normalized as Array)

## Applies mapping summary as a diff to avoid full cache teardown.
func FEAGI_apply_mapping_summary_diff(mapping_summary: Dictionary) -> void:
	# Empty summary during a genome transition can be transient; diff would remove every edge.
	if mapping_summary.is_empty() and not _established_mappings.is_empty():
		var synapse_n: int = 0
		if FeagiCore and FeagiCore.feagi_local_cache:
			synapse_n = int(FeagiCore.feagi_local_cache.synapse_count_current)
		if synapse_n > 0:
			push_warning(
				"FEAGI CACHE: Skipping mapping diff — empty summary while cache has mappings and synapse_count=%d"
				% synapse_n
			)
			return

	var existing_pairs: Array[Array] = []
	for source_id in _established_mappings.keys():
		for destination_id in _established_mappings[source_id].keys():
			existing_pairs.append([source_id, destination_id])

	var seen_pairs: Dictionary = {}
	for raw_source in mapping_summary.keys():
		var source_cortical_ID: Variant = _resolve_cortical_cache_key(raw_source)
		if source_cortical_ID == null:
			push_error("FEAGI CACHE: Mapping refers to nonexistant cortical area %s! Skipping!" % raw_source)
			continue
		var mapping_targets: Dictionary = mapping_summary[raw_source]
		for raw_destination in mapping_targets.keys():
			var destination_cortical_ID: Variant = _resolve_cortical_cache_key(raw_destination)
			if destination_cortical_ID == null:
				push_error("FEAGI CACHE: Mapping refers to nonexistant cortical area %s! Skipping!" % raw_destination)
				continue
			var source_area: AbstractCorticalArea = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas[source_cortical_ID]
			var destination_area: AbstractCorticalArea = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas[destination_cortical_ID]
			var normalized: Variant = _normalize_mapping_rules_to_array(
				mapping_targets[raw_destination]
			)
			if normalized == null:
				continue
			FEAGI_set_mapping_JSON(source_area, destination_area, normalized as Array)
			seen_pairs["%s->%s" % [String(source_cortical_ID), String(destination_cortical_ID)]] = true

	for pair in existing_pairs:
		var source_id: StringName = pair[0]
		var destination_id: StringName = pair[1]
		if seen_pairs.has("%s->%s" % [String(source_id), String(destination_id)]):
			continue
		var source_area := FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.get(source_id, null)
		var destination_area := FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.get(destination_id, null)
		if source_area != null and destination_area != null:
			FEAGI_delete_mappings(source_area, destination_area)
		else:
			push_warning("FEAGI CACHE: Removing mapping with missing area(s): %s -> %s" % [source_id, destination_id])
			if _established_mappings.has(source_id):
				_established_mappings[source_id].erase(destination_id)
				if len(_established_mappings[source_id]) == 0:
					_established_mappings.erase(source_id)

func FEAGI_delete_all_mappings() -> void:
	for source_ID: StringName in established_mappings.keys():
		for destination_ID: StringName in established_mappings[source_ID]:
			var existing_mappings: InterCorticalMappingSet = _established_mappings[source_ID][destination_ID]
			existing_mappings.FEAGI_delete_this_mapping()
	_established_mappings = {}

func FEAGI_delete_mappings(source: AbstractCorticalArea, destination: AbstractCorticalArea) -> void:
	if not _established_mappings.has(source.cortical_ID):
		# mapping already doesnt exist, ignore
		return
	if not _established_mappings[source.cortical_ID].has(destination.cortical_ID):
		# mapping already doesnt exist, ignore
		return
	var existing_mappings: InterCorticalMappingSet = _established_mappings[source.cortical_ID][destination.cortical_ID]
	existing_mappings.FEAGI_delete_this_mapping()
	_established_mappings[source.cortical_ID].erase(destination.cortical_ID)
	if len(_established_mappings[source.cortical_ID]) == 0:
		_established_mappings.erase(source.cortical_ID)

## Remap a cortical ID across cached mapping keys.
func FEAGI_remap_cortical_id(old_id: StringName, new_id: StringName) -> void:
	if old_id == new_id:
		return
	if _established_mappings.has(old_id):
		var existing = _established_mappings[old_id]
		_established_mappings.erase(old_id)
		_established_mappings[new_id] = existing
	for source_id in _established_mappings.keys():
		if _established_mappings[source_id].has(old_id):
			var existing_mapping = _established_mappings[source_id][old_id]
			_established_mappings[source_id].erase(old_id)
			_established_mappings[source_id][new_id] = existing_mapping
	

## Returns true if the given cortical areas have a mapping defined in cache between them, else false
func does_mappings_exist_between_areas(source: AbstractCorticalArea, destination: AbstractCorticalArea) -> bool:
	if not _established_mappings.has(source.cortical_ID):
		return false
	if not _established_mappings[source.cortical_ID].has(destination.cortical_ID):
		return false
	return true

func get_mappings_from_source_cortical_area(source: AbstractCorticalArea):
	pass

func get_mappings_toward_destination_cortical_area(destination: AbstractCorticalArea):
	pass
