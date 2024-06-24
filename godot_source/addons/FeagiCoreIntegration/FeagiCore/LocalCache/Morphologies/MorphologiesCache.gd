extends RefCounted
class_name MorphologiesCache
## Stores all morphologies available in the genome

signal morphology_added(morphology: BaseMorphology)
signal morphology_about_to_be_removed(morphology: BaseMorphology) # Must have this since dropdown popups do not support independent processing
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
	print("FEAGI CACHE: Replacing morphology details cache...")
	
	for current_morphology: StringName in _available_morphologies.keys():
		if !(all_morphology_details.keys().has(current_morphology)):
			# This morphology doesnt exist anymore, delete it
			print("CACHE: deleting morphology no longer in use: %s..." % current_morphology)
			_available_morphologies.erase(current_morphology)
	
	var current_morphlogy_dict: Dictionary
	for feagi_retrieved_morphology_name: StringName in all_morphology_details.keys():
		current_morphlogy_dict = all_morphology_details[feagi_retrieved_morphology_name]
		if feagi_retrieved_morphology_name in _available_morphologies.keys():
			# Morphology exists but needs to be updated
			_available_morphologies[feagi_retrieved_morphology_name].feagi_update(
				current_morphlogy_dict["parameters"],
				BaseMorphology.morphology_class_str_to_class(current_morphlogy_dict["class"])
			)
		else:
			# Morphology doesn't exist in cache, create it!	
			_available_morphologies[feagi_retrieved_morphology_name] = BaseMorphology.create_from_FEAGI_template(feagi_retrieved_morphology_name, current_morphlogy_dict)

	
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
	if morphology_name in _available_morphologies:
		return _available_morphologies[morphology_name]
	return null
