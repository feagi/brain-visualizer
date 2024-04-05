extends RefCounted
class_name MorphologiesCache
## Stores all morphologies available in the genome

signal morphology_added(morphology: BaseMorphology)
signal morphology_about_to_be_removed(morphology: BaseMorphology)
signal morphology_updated(morphology: BaseMorphology)

## A list of all available morphologies in the FEAGI genome by name
var available_morphologies: Dictionary:
	get: return _available_morphologies

var _available_morphologies: Dictionary = {}

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
	morphology_added.emit(_available_morphologies[morphology_name])

## Retrieved updated info of morphology from FEAGI
func update_morphology_by_dict(morphology_properties: Dictionary) -> void:
	var morphology_name: StringName = morphology_properties["morphology_name"]
	if morphology_name not in _available_morphologies.keys():
		push_error("Attemped to update non-cached morphology %s, Skipping..." % [morphology_properties["morphology_name"]])
		return
	var updating_morphology: BaseMorphology = _available_morphologies[morphology_name]
	var morphology_internal_class: BaseMorphology.MORPHOLOGY_INTERNAL_CLASS = BaseMorphology.MORPHOLOGY_INTERNAL_CLASS[morphology_properties["class"].to_upper()]
	updating_morphology.feagi_update(morphology_properties["parameters"], morphology_internal_class)
	morphology_updated.emit(updating_morphology)

## Should only be called by FEAGI - removes a morphology by name
func remove_morphology(morphology_Name: StringName) -> void:
	if morphology_Name not in _available_morphologies.keys():
		push_error("Attemped to delete non-cached morphology %s, Skipping..." % [morphology_Name])
		return
	var deleting: BaseMorphology = _available_morphologies[morphology_Name]
	morphology_about_to_be_removed.emit(deleting)
	_available_morphologies.erase(morphology_Name)
	deleting.free()
	
## Removes all morphologies from cache. Should only be called during a reset
func hard_wipe_cached_morphologies():
	print("CACHE: Wiping morphologies...")
	var all_morphology_names: Array = _available_morphologies.keys()
	for morphology_name in all_morphology_names:
		remove_morphology(morphology_name)
	print("CACHE: Wiping morphologies complete!")


## To update morphology listing given a dict with details about all morphologies
func update_morphology_cache_from_summary(all_morphology_details: Dictionary) -> void:
	print("CACHE: Replacing morphology detail cache...")
	
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




# TODO: OLD, remove this!
## To update morphology listing given a dict with keys of morphology names and its value being the str type of morphology (NOT FULL OBJECT / DICTIONARY)
func update_morphology_cache_from_summary_deprecated(_new_listing_with_types: Dictionary) -> void:
	
	# TODO: Possible optimizations used packedStringArrays and less duplications
	var new_listing: Array = _new_listing_with_types.keys()
	var removed: Array = _available_morphologies.keys().duplicate()
	var added: Array = []
	var search: int # init here to reduce GC
	
	# Check what has to be added, what has to be removed
	for new in new_listing:
		search = removed.find(new)
		if search != -1:
			# item was found
			removed.remove_at(search)
			continue
		# new item
		added.append(new)
		continue
	
	# At this point, 'added' has all names of elements that need to be added, while 'removed' has all elements that need to be removed
	
	# remove removed morphologies
	for remove in removed:
		_available_morphologies.erase(remove)
	
	# note: not preallocating here due to reference shenanigans, attempt later when system is stable
	# add added morphologies
	for add in added:
		# since we only have a input dict with the name and type of morphology, we need to generate placeholder objects
		var adding_type: BaseMorphology.MORPHOLOGY_TYPE = BaseMorphology.MORPHOLOGY_TYPE[(_new_listing_with_types[add].to_upper())]
		var adding_morphology: BaseMorphology = BaseMorphology.create_placeholder(add, adding_type)
		_available_morphologies[add] = adding_morphology
		morphology_added.emit(adding_morphology)
	
func attempt_to_get_morphology_arr_from_string_name_arr(requested: Array[StringName], surpress_missing_error: bool = false) -> Array[BaseMorphology]:
	var output: Array[BaseMorphology] = []
	for req_morph: StringName in requested:
		if req_morph in _available_morphologies.keys():
			output.append(_available_morphologies[req_morph])
		else:
			if !surpress_missing_error:
				push_error("Unable to find requested morphology by name of '%s', Returning Empty!" % req_morph)
	return output
