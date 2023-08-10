extends Morphology
class_name VectorMorphology
## Morphology of type Vector

var vectors: Array[Vector3i]
# PackedVector3iArrays do not exist as per https://github.com/godotengine/godot/pull/66616
# While a similar effect can be emulated using a PackedInt32 array and a Stride of 3, these arrays are so small it likely isn't worth the effort for such minimal memory savings

func _init(morphology_name: StringName, is_using_placeholder_data: bool, morphology_vectors: Array[Vector3i]):
    super(morphology_name, is_using_placeholder_data)
    type = MORPHOLOGY_TYPE.VECTOR
    vectors = morphology_vectors