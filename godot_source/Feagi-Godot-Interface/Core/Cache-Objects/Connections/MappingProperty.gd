extends Object
class_name MappingProperty
## Mapping property between 2 cortical areas
## This object is never actually stored in a cache, its created as needed to represent a connections details

const INT8_MAX: int = 2147483647 # This is likely the max supported int in vector3i, but you should NOT be getting this close anyways

var source_cortical_area: CorticalArea:
    get: return _src_cortical_area
var destination_cortical_area: CorticalArea:
    get: return _dst_cortical_area
var morphology_used: Morphology:
    get: return _morphology_used
var is_plastic: bool:
    get: return _plasticity_flag
var post_synaptic_current_multiplier: float:
    get: return post_synaptic_current_multiplier


var _morphology_used: Morphology
var _scalar: Vector3i # must all be non-zero positive
var _post_synaptic_current_multiplier: float
var _plasticity_flag: bool
var _src_cortical_area: CorticalArea
var _dst_cortical_area: CorticalArea

func _init(source_cortical: CorticalArea, destination_cortical: CorticalArea, morphology: Morphology, positive_scalar: Vector3i, current_multilpier: float, plasticity: bool):
    _src_cortical_area = source_cortical
    _dst_cortical_area = destination_cortical
    _morphology_used = morphology
    _scalar = Vector3i(FEAGIUtils.bounds_int(positive_scalar.x, 1, INT8_MAX), FEAGIUtils.bounds_int(positive_scalar.y, 1, INT8_MAX), FEAGIUtils.bounds_int(positive_scalar.z, 1, INT8_MAX))
    _post_synaptic_current_multiplier = current_multilpier
    _plasticity_flag = plasticity
