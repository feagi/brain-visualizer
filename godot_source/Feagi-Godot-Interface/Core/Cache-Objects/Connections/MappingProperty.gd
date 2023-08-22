extends Object
class_name MappingProperty
## Mapping property between 2 cortical areas

const INT8_MAX: int = 2147483647 # This is likely the max supported int in vector3i, but you should NOT be getting this close anyways

var morphology: StringName
var scalar: Vector3i # must all be non-zero positive
var post_synaptic_current_multiplier: float
var plasticity_flag: bool

func _init(morphology_name: StringName, positive_scalar: Vector3i, current_multilpier: float, plasticity: bool):
    morphology = morphology_name
    positive_scalar = Vector3i(FEAGIUtils.bounds_int(positive_scalar.x, 1, INT8_MAX), FEAGIUtils.bounds_int(positive_scalar.y, 1, INT8_MAX), FEAGIUtils.bounds_int(positive_scalar.z, 1, INT8_MAX))
    post_synaptic_current_multiplier = current_multilpier
    plasticity_flag = plasticity

func get_morphology_ref() -> Morphology:
    return FeagiCache.morphology_cache.available_morphologies[morphology]