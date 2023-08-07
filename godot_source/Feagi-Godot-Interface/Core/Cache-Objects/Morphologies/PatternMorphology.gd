extends Morphology
class_name PatternMorphology
## Morphology of type Pattern

var patterns: Array[PatternVector3]

func _init(morphology_name: StringName, morphology_type: TYPE, morphology_patterns: Array[PatternVector3]):
    super(morphology_name, morphology_type)
    patterns = morphology_patterns