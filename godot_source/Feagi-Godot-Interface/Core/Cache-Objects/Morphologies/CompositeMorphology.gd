extends Morphology
class_name CompositeMorphology
## Morphology of type Composite

var source_seed: Vector3i
var source_pattern: Array[Vector2i]

## String name of an existing morphology
var mapper_morphology_name: StringName

func _init(morphology_name: StringName, is_using_placeholder_data: bool, src_seed: Vector3i, src_pattern: Array[Vector2i], mapper_morphology: StringName):
	super(morphology_name, is_using_placeholder_data)
	type = MORPHOLOGY_TYPE.COMPOSITE
	source_seed = src_seed
	source_pattern = src_pattern
	mapper_morphology_name = mapper_morphology

func to_dictionary() -> Dictionary:
	return {
		"src_seed": FEAGIUtils.vector3i_to_array(source_seed),
		"src_pattern": FEAGIUtils.vector2i_array_to_array_of_arrays(source_pattern),
		"mapper_morphology": mapper_morphology_name
	}
