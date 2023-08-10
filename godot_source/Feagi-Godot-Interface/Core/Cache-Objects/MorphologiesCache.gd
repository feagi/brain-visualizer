extends Object
class_name MorphologiesCache
## Stores the (names) of all morphologies available in the genome
## TODO -  we may add more details here later

## A list of all available morphologies in the FEAGI genome by name
var available_morphologies: Dictionary:
    get: return _available_morphologies

var _available_morphologies: Dictionary = {}

# TODO add / remove / update morphologies

## To update morphology listing given a dict with keys of morphology names and its value being the str type of morphology (NOT FULL OBJECT / DICTIONARY)
func update_morphology_cache_from_summary(_new_listing_with_types: Dictionary) -> void:
    
    # TODO: Possible optimizations used packedStringArrays and less duplications
    var new_listing: Array[StringName] = _new_listing_with_types.keys()
    var removed: Array[StringName] = _available_morphologies.keys().duplicate()
    var added: Array[StringName] = []
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
    
    # At this point, added has all names of elements that need to be added, while removed has all elements that need to be removed
    
    # remove removed morphologies
    for remove in removed:
        FeagiCacheEvents.morphology_removed.emit(_available_morphologies[remove])
        _available_morphologies.erase(remove)
    
    # note: not preallocating here due to reference shenanigans, attempt later when system is stable
    # add added morphologies
    for add in added:
        # since we only have a input dict with the name and type of morphology, we need to generate placeholder objects
        var adding_type = Morphology.MORPHOLOGY_TYPE.find_key(_new_listing_with_types[add].to_upper())
        var adding_morphology = MorphologyFactory.create_placeholder(add, adding_type)
        _available_morphologies[add] = adding_morphology
        FeagiCacheEvents.morphology_added.emit(adding_morphology)
    
    