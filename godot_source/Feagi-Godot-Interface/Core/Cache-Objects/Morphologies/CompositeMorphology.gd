extends Morphology
class_name CompositeMorphology
## Morphology of type Composite

var source_seed: Vector3i
var source_pattern: Array[Vector2i]

## String name of an existing morphology
var mapper_morphology_name: StringName

func _init(morphology_name: StringName, morphology_type: TYPE, src_seed: Vector3i, src_pattern: Array[Vector2i], mapper_morphology: StringName):
    super(morphology_name, morphology_type)
    source_seed = src_seed
    source_pattern = src_pattern
    mapper_morphology_name = mapper_morphology
