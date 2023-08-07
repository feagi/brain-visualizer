extends Morphology
class_name PatternMorphology
## Morphology of type Pattern

var patterns: Array[PatternVector3Pairs]

func _init(morphology_name: StringName, morphology_patterns: Array[PatternVector3Pairs]):
    super(morphology_name)
    type = MORPHOLOGY_TYPE.PATTERN
    patterns = morphology_patterns