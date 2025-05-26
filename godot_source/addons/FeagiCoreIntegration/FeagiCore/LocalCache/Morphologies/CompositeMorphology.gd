extends BaseMorphology
class_name CompositeMorphology
## BaseMorphology of type Composite

var source_seed: Vector3i
var source_pattern: Array[Vector2i]

## String name of an existing morphology
var mapper_morphology_name: StringName

func _init(morphology_name: StringName, is_using_placeholder_data: bool, feagi_defined_internal_class: MORPHOLOGY_INTERNAL_CLASS, src_seed: Vector3i, src_pattern: Array[Vector2i], mapper_morphology: StringName):
	super(morphology_name, is_using_placeholder_data, feagi_defined_internal_class)
	type = MORPHOLOGY_TYPE.COMPOSITE
	source_seed = src_seed
	source_pattern = src_pattern
	mapper_morphology_name = mapper_morphology

## Called by FEAGI when updating a morphology definition (when type is consistent)
func feagi_update(parameter_value: Dictionary, retrieved_internal_class: MORPHOLOGY_INTERNAL_CLASS) -> void:
	source_seed = BaseMorphology._safe_convert_to_vector3i(parameter_value["src_seed"], "src_seed")
	var raw_source_pattern_array: Array[Array] = []
	raw_source_pattern_array.assign(parameter_value["src_pattern"]) # manual array casting
	source_pattern = FEAGIUtils.array_of_arrays_to_vector2i_array(raw_source_pattern_array)
	mapper_morphology_name = parameter_value["mapper_morphology"]
	super(parameter_value , retrieved_internal_class )

## Used when we update values and Feagi confirms it
func feagi_confirmed_value_update(new_seed: Vector3i, new_pattern: Array[Vector2i]) -> void:
	source_seed = new_seed
	source_pattern = new_pattern
	numerical_properties_updated.emit(self)

func to_dictionary() -> Dictionary:
	return {
		"src_seed": FEAGIUtils.vector3i_to_array(source_seed),
		"src_pattern": FEAGIUtils.vector2i_array_to_array_of_arrays(source_pattern),
		"mapper_morphology": mapper_morphology_name
	}
