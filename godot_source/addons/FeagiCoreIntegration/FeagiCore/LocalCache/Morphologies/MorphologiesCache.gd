extends RefCounted
class_name MorphologiesCache
## Stores all morphologies available in the genome

signal morphology_added(morphology: BaseMorphology)
signal morphology_about_to_be_removed(morphology: BaseMorphology) # Must have this since dropdown popups do not support independent processing
signal morphology_renamed(old_name: StringName, morphology: BaseMorphology)
signal morphology_updated(morphology: BaseMorphology)

## A list of all available morphologies in the FEAGI genome by name
var available_morphologies: Dictionary:
	get: return _available_morphologies

var _available_morphologies: Dictionary = {}

## Should only be called by FEAGI - Adds a morphology
func add_morphology_by_dict(properties: Dictionary) -> void:
	var morphology_name: StringName = properties["morphology_name"]
	var morphology_type: BaseMorphology.MORPHOLOGY_TYPE  = properties["type"]
	var morphology_internal_class: BaseMorphology.MORPHOLOGY_INTERNAL_CLASS
	if "internal_class" in properties.keys():
		morphology_internal_class = properties["internal_class"]
	else:
		morphology_internal_class = BaseMorphology.MORPHOLOGY_INTERNAL_CLASS.CUSTOM
	
	if morphology_name in available_morphologies.keys():
		push_error("Attempted to create already cached morphology " + morphology_name + ", Skipping!")
		return
	_available_morphologies[morphology_name] = BaseMorphology.create(morphology_name, morphology_type, morphology_internal_class, properties)
	print("FEAGI CACHE: Added morphology %" % morphology_name)
	morphology_added.emit(_available_morphologies[morphology_name])

##  Should only be called by FEAGI - Updates info of morphology
func update_morphology_by_dict(morphology_properties: Dictionary) -> void:
	var morphology_name: StringName = morphology_properties["morphology_name"]
	if morphology_name not in _available_morphologies.keys():
		push_error("Attemped to update non-cached morphology %s, Skipping..." % [morphology_properties["morphology_name"]])
		return
	var updating_morphology: BaseMorphology = _available_morphologies[morphology_name]
	var morphology_internal_class: BaseMorphology.MORPHOLOGY_INTERNAL_CLASS
	if "class" in morphology_properties.keys():
		morphology_internal_class = BaseMorphology.MORPHOLOGY_INTERNAL_CLASS[morphology_properties["class"].to_upper()]
	else:
		push_error("MORPHOLOGY: Unknown / Unspecified morphology class for %s! Assigning UNKNOWN for the class! This is likely due to the use of outdated or broken genomes!" % morphology_name)
		morphology_internal_class = BaseMorphology.MORPHOLOGY_INTERNAL_CLASS.UNKNOWN
	updating_morphology.feagi_update(morphology_properties["parameters"], morphology_internal_class)
	morphology_updated.emit(updating_morphology)

## Updates cache after a successful rename. Call only after FEAGI rename succeeds.
func rename_morphology_in_cache(old_name: StringName, new_name: StringName) -> void:
	if old_name not in _available_morphologies.keys():
		push_error("Attempted to rename non-cached morphology %s, Skipping..." % [old_name])
		return
	if new_name in _available_morphologies.keys():
		push_error("Attempted to rename morphology %s to existing name %s, Skipping..." % [old_name, new_name])
		return
	var morphology: BaseMorphology = _available_morphologies[old_name]
	_available_morphologies.erase(old_name)
	morphology.name = new_name
	_available_morphologies[new_name] = morphology
	morphology_renamed.emit(old_name, morphology)

## Should only be called by FEAGI - removes a morphology by name
func remove_morphology(morphology_Name: StringName) -> void:
	if morphology_Name not in _available_morphologies.keys():
		push_error("Attemped to delete non-cached morphology %s, Skipping..." % [morphology_Name])
		return
	var deleting: BaseMorphology = _available_morphologies[morphology_Name]
	morphology_about_to_be_removed.emit(deleting)
	deleting.FEAGI_delete_morphology()
	_available_morphologies.erase(morphology_Name)

## Adds a Composite Morphology by definition
func add_defined_composite_morphology(morphology_name: StringName, src_seed: Vector3i, src_pattern: Array[Vector2i], mapper_morphology: StringName, feagi_defined_internal_class: BaseMorphology.MORPHOLOGY_INTERNAL_CLASS = BaseMorphology.MORPHOLOGY_INTERNAL_CLASS.UNKNOWN) -> void:
	if morphology_name in _available_morphologies.keys():
		push_error("Attempted to create already cached morphology " + morphology_name + ", Skipping!")
		return
	var composite: CompositeMorphology = CompositeMorphology.new(morphology_name, false, feagi_defined_internal_class, src_seed, src_pattern, mapper_morphology)
	_available_morphologies[morphology_name] = composite
	morphology_added.emit(composite)

## Adds a Vector Morphology by definition
func add_defined_vector_morphology(morphology_name: StringName, morphology_vectors: Array[Vector3i], feagi_defined_internal_class: BaseMorphology.MORPHOLOGY_INTERNAL_CLASS = BaseMorphology.MORPHOLOGY_INTERNAL_CLASS.UNKNOWN) -> void:
	if morphology_name in _available_morphologies.keys():
		push_error("Attempted to create already cached morphology " + morphology_name + ", Skipping!")
		return
	var vector: VectorMorphology = VectorMorphology.new(morphology_name, false, feagi_defined_internal_class, morphology_vectors)
	_available_morphologies[morphology_name] = vector
	morphology_added.emit(vector)

## Adds a Pattern Morphology by definition
func add_defined_pattern_morphology(morphology_name: StringName, morphology_patterns: Array[PatternVector3Pairs], feagi_defined_internal_class: BaseMorphology.MORPHOLOGY_INTERNAL_CLASS = BaseMorphology.MORPHOLOGY_INTERNAL_CLASS.UNKNOWN) -> void:
	if morphology_name in _available_morphologies.keys():
		push_error("Attempted to create already cached morphology " + morphology_name + ", Skipping!")
		return
	var pattern: PatternMorphology = PatternMorphology.new(morphology_name, false, feagi_defined_internal_class, morphology_patterns)
	_available_morphologies[morphology_name] = pattern
	morphology_added.emit(pattern)

## Removes all morphologies from cache. Should only be called during a reset
func hard_wipe_cached_morphologies():
	print("CACHE: Wiping morphologies...")
	var all_morphology_names: Array = _available_morphologies.keys()
	for morphology_name in all_morphology_names:
		remove_morphology(morphology_name)
	print("CACHE: Wiping morphologies complete!")

## To update morphology listing given a dict with details about all morphologies
func update_morphology_cache_from_summary(all_morphology_details: Dictionary) -> void:
	if all_morphology_details.is_empty():
		_available_morphologies.clear()
		return
	# HTTP/JSON keys are often String; cache may use StringName. Normalize for existence checks.
	var api_id_strings: Dictionary = {}
	for k in all_morphology_details.keys():
		api_id_strings[String(k).strip_edges()] = true
	var to_erase: Array[Variant] = []
	for cur in _available_morphologies.keys():
		if not api_id_strings.has(String(cur).strip_edges()):
			to_erase.append(cur)
	for cur in to_erase:
		print("CACHE: deleting morphology no longer in use: %s..." % cur)
		_available_morphologies.erase(cur)

	for raw_name in all_morphology_details.keys():
		var name_key: StringName = StringName(String(raw_name).strip_edges())
		var current_morphlogy_dict: Dictionary = all_morphology_details[raw_name]
		var existing: BaseMorphology = try_get_morphology_by_ambiguous_key(name_key)
		if existing != null:
			if not _available_morphologies.has(name_key):
				for k in _available_morphologies.keys():
					if String(k) == String(name_key):
						_available_morphologies.erase(k)
						break
				_available_morphologies[name_key] = existing
			_available_morphologies[name_key].feagi_update(
				current_morphlogy_dict["parameters"],
				BaseMorphology.morphology_class_str_to_class(current_morphlogy_dict["class"])
			)
		else:
			_available_morphologies[name_key] = BaseMorphology.create_from_FEAGI_template(name_key, current_morphlogy_dict)


## Collect morphology_id strings from cortical_map_detailed-style mapping summary.
func _collect_morphology_ids_from_mapping_summary(mapping_summary: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var seen: Dictionary = {}
	for _src in mapping_summary.keys():
		var targets: Variant = mapping_summary[_src]
		if targets is not Dictionary:
			continue
		var mapping_targets: Dictionary = targets as Dictionary
		for _dst in mapping_targets.keys():
			var rules: Variant = mapping_targets[_dst]
			if rules is Dictionary:
				var mid0: Variant = (rules as Dictionary).get("morphology_id", null)
				if mid0 != null:
					var s0: String = String(mid0).strip_edges()
					if not s0.is_empty() and not seen.has(s0):
						seen[s0] = true
						out.append(s0)
				continue
			if rules is not Array:
				continue
			for rule in rules:
				if rule is Dictionary:
					var mid: Variant = (rule as Dictionary).get("morphology_id", null)
					if mid != null:
						var s: String = String(mid).strip_edges()
						if not s.is_empty() and not seen.has(s):
							seen[s] = true
							out.append(s)
				elif rule is Array:
					var arr: Array = rule as Array
					if arr.size() > 0:
						var s2: String = String(arr[0]).strip_edges()
						if not s2.is_empty() and not seen.has(s2):
							seen[s2] = true
							out.append(s2)
	return out


func _find_morphology_template_in_summary(morphologies_summary: Dictionary, morph_id_str: String) -> Dictionary:
	for k in morphologies_summary.keys():
		if String(k).strip_edges() == morph_id_str:
			var v: Variant = morphologies_summary[k]
			if v is Dictionary:
				return v as Dictionary
	return {}


## After [method update_morphology_cache_from_summary], add any mapping-referenced morphologies still missing
## (recovers from String/StringName skew or ordering edge cases).
func ensure_morphologies_referenced_in_mappings(mapping_summary: Dictionary, morphologies_summary: Dictionary) -> void:
	for morph_id_str in _collect_morphology_ids_from_mapping_summary(mapping_summary):
		if try_get_morphology_by_ambiguous_key(morph_id_str) != null:
			continue
		var template_dict: Dictionary = _find_morphology_template_in_summary(morphologies_summary, morph_id_str)
		if template_dict.is_empty():
			push_warning(
				"FEAGI CACHE: Morphology '%s' is referenced in cortical mappings but has no definition in morphologies summary"
				% morph_id_str
			)
			continue
		var name_key: StringName = StringName(morph_id_str)
		_available_morphologies[name_key] = BaseMorphology.create_from_FEAGI_template(name_key, template_dict)

func attempt_to_get_morphology_arr_from_string_name_arr(requested: Array[StringName], surpress_missing_error: bool = false) -> Array[BaseMorphology]:
	var output: Array[BaseMorphology] = []
	for req_morph: StringName in requested:
		if req_morph in _available_morphologies.keys():
			output.append(_available_morphologies[req_morph])
		else:
			if !surpress_missing_error:
				push_error("Unable to find requested morphology by name of '%s', Returning Empty!" % req_morph)
	return output

## Gets a morphology by name if exists, otherwise returns null
func try_get_morphology_object(morphology_name: StringName) -> BaseMorphology:
	return try_get_morphology_by_ambiguous_key(morphology_name)


## Resolve morphology id from HTTP JSON ([String]) or cache ([StringName]) keys.
func try_get_morphology_by_ambiguous_key(morph_id: Variant) -> BaseMorphology:
	if morph_id == null:
		return null
	if _available_morphologies.has(morph_id):
		return _available_morphologies[morph_id]
	var token: String = String(morph_id).strip_edges()
	if token.is_empty():
		return null
	for k in _available_morphologies.keys():
		if String(k) == token:
			return _available_morphologies[k]
	return null
