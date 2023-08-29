extends Object
class_name MappingProperties
## Holds all [MappingProperty] objects / data relevant between a source and destination cortical area
## This object is not stored in the cache, it is created as needed, then can be discarded

var source_cortical_area: CorticalArea:
    get: return _src_cortical
var destination_cortical_area: CorticalArea:
    get: return _dst_cortical
var mappings: Array[MappingProperty]

var _src_cortical: CorticalArea
var _dst_cortical: CorticalArea

func _init(source_area: CorticalArea, destination_area: CorticalArea, mappings_between_them: Array[MappingProperty]) -> void:
    _src_cortical = source_area
    _dst_cortical = destination_area
    mappings = mappings_between_them

## Returns an array of the internal [MappingProperty] objects as FEAGI formatted dictionaries
func to_array() -> Array[Dictionary]:
    var output: Array[Dictionary] = []
    for mapping in mappings:
        output.append(mapping)
    return output

