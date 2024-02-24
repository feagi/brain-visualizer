extends Object
class_name MorphologiesCache
## Stores all morphologies available in the genome

signal morphology_added(morphology: Morphology)
signal morphology_about_to_be_removed(morphology: Morphology)
signal morphology_updated(morphology: Morphology)

## A list of all available morphologies in the FEAGI genome by name
var available_morphologies: Dictionary:
	get: return _available_morphologies

var _available_morphologies: Dictionary = {}

func add_morphology_by_dict(properties: Dictionary) -> void:
	var morphology_name: StringName = properties["morphology_name"]
	var morphology_type: Morphology.MORPHOLOGY_TYPE  = properties["type"]
	var morphology_internal_class: Morphology.MORPHOLOGY_INTERNAL_CLASS
	if "internal_class" in properties.keys():
		morphology_internal_class = properties["internal_class"]
	else:
		morphology_internal_class = Morphology.MORPHOLOGY_INTERNAL_CLASS.CUSTOM
	
	if morphology_name in available_morphologies.keys():
		push_error("Attempted to create already cached morphology " + morphology_name + ", Skipping!")
		return
	_available_morphologies[morphology_name] = Morphology.create(morphology_name, morphology_type, morphology_internal_class, properties)
	morphology_added.emit(_available_morphologies[morphology_name])

## Retrieved updated info of morphology from FEAGI
func update_morphology_by_dict(morphology_properties: Dictionary) -> void:
	var morphology_name: StringName = morphology_properties["morphology_name"]
	if morphology_name not in _available_morphologies.keys():
		push_error("Attemped to update non-cached morphology %s, Skipping..." % [morphology_properties["morphology_name"]])
		return
	var updating_morphology: Morphology = _available_morphologies[morphology_name]
	var morphology_internal_class: Morphology.MORPHOLOGY_INTERNAL_CLASS = Morphology.MORPHOLOGY_INTERNAL_CLASS[morphology_properties["class"].to_upper()]
	updating_morphology.feagi_update(morphology_properties["parameters"], morphology_internal_class)
	morphology_updated.emit(updating_morphology)

## Should only be called by FEAGI - removes a morphology by name
func remove_morphology(morphology_Name: StringName) -> void:
	if morphology_Name not in _available_morphologies.keys():
		push_error("Attemped to delete non-cached morphology %s, Skipping..." % [morphology_Name])
		return
	var deleting: Morphology = _available_morphologies[morphology_Name]
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

## To update morphology listing given a dict with keys of morphology names and its value being the str type of morphology (NOT FULL OBJECT / DICTIONARY)
func update_morphology_cache_from_summary(_new_listing_with_types: Dictionary) -> void:
	
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
		var adding_type: Morphology.MORPHOLOGY_TYPE = Morphology.MORPHOLOGY_TYPE[(_new_listing_with_types[add].to_upper())]
		var adding_morphology: Morphology = Morphology.create_placeholder(add, adding_type)
		_available_morphologies[add] = adding_morphology
		morphology_added.emit(adding_morphology)
	
func attempt_to_get_morphology_arr_from_string_name_arr(requested: Array[StringName], surpress_missing_error: bool = false) -> Array[Morphology]:
	var output: Array[Morphology] = []
	for req_morph: StringName in requested:
		if req_morph in _available_morphologies.keys():
			output.append(_available_morphologies[req_morph])
		else:
			if !surpress_missing_error:
				push_error("Unable to find requested morphology by name of '%s', Returning Empty!" % req_morph)
	return output
