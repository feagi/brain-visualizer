extends BaseMorphology
class_name PatternMorphology
## BaseMorphology of type Pattern

var patterns: Array[PatternVector3Pairs]

func _init(morphology_name: StringName, is_using_placeholder_data: bool, feagi_defined_internal_class: MORPHOLOGY_INTERNAL_CLASS, morphology_patterns: Array[PatternVector3Pairs]):
	super(morphology_name, is_using_placeholder_data, feagi_defined_internal_class)
	type = MORPHOLOGY_TYPE.PATTERNS
	patterns = morphology_patterns

## Called by FEAGI when updating a morphology definition (when type is consistent)
func feagi_update(parameter_value: Dictionary, retrieved_internal_class: MORPHOLOGY_INTERNAL_CLASS) -> void:
	var raw_pattern_array: Array[Array] = []
	raw_pattern_array.assign(parameter_value["patterns"])  # manual array casting
	patterns = PatternVector3Pairs.raw_pattern_nested_array_to_array_of_PatternVector3s(raw_pattern_array)
	super(parameter_value , retrieved_internal_class )

## Used when we update values and Feagi confirms it
func feagi_confirmed_value_update(new_patterns: Array[PatternVector3Pairs]) -> void:
	patterns = new_patterns
	numerical_properties_updated.emit(self)

func to_dictionary() -> Dictionary:
	return {
		"patterns": FEAGIUtils.array_of_PatternVector3Pairs_to_array_of_array_of_array_of_array_of_elements(patterns)
	}
