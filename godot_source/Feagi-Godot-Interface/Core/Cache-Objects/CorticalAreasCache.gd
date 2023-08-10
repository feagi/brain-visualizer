extends Object
class_name CorticalAreasCache
## Stores all cortical areas available in the genome

var cortical_areas: Dictionary:
    get: return _cortical_areas


var _cortical_areas: Dictionary = {}


# TODO add / remove / update cortical areas
# TODO add signal passthroughs for cortical areas


func update_cortical_area_cache_from_summary(_new_listing_with_summaries: Dictionary) -> void:

    # TODO: Possible optimizations used packedStringArrays and less duplications
    var new_listing: Array = _new_listing_with_summaries.keys()
    var removed: Array = _cortical_areas.keys().duplicate()
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

	# remove removed cortical areas
    for remove in removed:
        FeagiCacheEvents.cortical_area_removed.emit(_cortical_areas[remove])
        _cortical_areas.erase(remove)
    
	# note: not preallocating here certain things due to reference shenanigans, attempt later when system is stable
	# add added cortical areas
    var new_area_summary: Dictionary
    var new_cortical_type: CorticalArea.CORTICAL_AREA_TYPE
    var new_cortical_name: StringName
    var new_cortical_visibility: bool
    var new_cortical_dimensions: Vector3i
    for add in added:
        # since we only have a input dict with the name and type of morphology, we need to generate placeholder objects
        new_area_summary = _new_listing_with_summaries[add]
        new_cortical_type = CorticalArea.CORTICAL_AREA_TYPE[new_area_summary["type"].to_upper()]
        new_cortical_name = new_area_summary["name"]
        new_cortical_visibility = new_area_summary["visible"]
        new_cortical_dimensions = new_area_summary["dimensions"]
        var adding_cortical_area: CorticalArea = CorticalArea.new(add, new_cortical_name, new_cortical_type, new_cortical_visibility, new_cortical_dimensions)

        # check if 3D and 2D positions exist, if so apply them
        # signals here can emit all they want, they arent connected yet, so theres no chance of feedback loops
        if new_area_summary["position_2d"][0] != null: # assume either all are null or none are
            adding_cortical_area.coordinates_2D = FEAGIUtils.array_to_vector2i(new_area_summary["position_2d"])
        if new_area_summary["position_3d"][0] != null: # assume either all are null or none are
            adding_cortical_area.coordinates_3D = FEAGIUtils.array_to_vector3i(new_area_summary["position_3d"])
        
        _cortical_areas[add] = adding_cortical_area
        FeagiCacheEvents.cortical_area_added.emit(adding_cortical_area)



