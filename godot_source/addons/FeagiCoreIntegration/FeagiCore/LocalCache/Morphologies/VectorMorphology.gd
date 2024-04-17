extends BaseMorphology
class_name VectorMorphology
## BaseMorphology of type Vector

var vectors: Array[Vector3i]
# PackedVector3iArrays do not exist as per https://github.com/godotengine/godot/pull/66616
# While a similar effect can be emulated using a PackedInt32 array and a Stride of 3, these arrays are so small it likely isn't worth the effort for such minimal memory savings

func _init(morphology_name: StringName, is_using_placeholder_data: bool, feagi_defined_internal_class: MORPHOLOGY_INTERNAL_CLASS, morphology_vectors: Array[Vector3i]):
	super(morphology_name, is_using_placeholder_data, feagi_defined_internal_class)
	type = MORPHOLOGY_TYPE.VECTORS
	vectors = morphology_vectors

## Called by FEAGI when updating a morphology definition (when type is consistent)
func feagi_update(parameter_value: Dictionary, retrieved_internal_class: MORPHOLOGY_INTERNAL_CLASS) -> void:
	var raw_vector3_array: Array[Array] = []
	raw_vector3_array.assign(parameter_value["vectors"]) # manual array casting
	vectors = FEAGIUtils.array_of_arrays_to_vector3i_array(raw_vector3_array)
	super(parameter_value , retrieved_internal_class )

## Used when we update values and Feagi confirms it
func feagi_confirmed_value_update(new_vectors: Array[Vector3i]) -> void:
	vectors = new_vectors
	numerical_properties_updated.emit(self)

func to_dictionary() -> Dictionary:
	return {
		"vectors": FEAGIUtils.vector3i_array_to_array_of_arrays(vectors)
	}
