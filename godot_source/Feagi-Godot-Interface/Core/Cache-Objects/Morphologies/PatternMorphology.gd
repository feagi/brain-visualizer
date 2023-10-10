extends Morphology
class_name PatternMorphology
## Morphology of type Pattern

var patterns: Array[PatternVector3Pairs]

func _init(morphology_name: StringName, is_using_placeholder_data: bool, morphology_patterns: Array[PatternVector3Pairs]):
	super(morphology_name, is_using_placeholder_data)
	type = MORPHOLOGY_TYPE.PATTERNS
	patterns = morphology_patterns

func to_dictionary() -> Dictionary:
	return {
		"patterns": FEAGIUtils.array_of_PatternVector3Pairs_to_array_of_array_of_array_of_array_of_elements(patterns)
	}
