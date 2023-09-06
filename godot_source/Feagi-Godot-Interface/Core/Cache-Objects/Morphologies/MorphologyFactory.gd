extends Object
class_name MorphologyFactory
## Handles spawning morphologies of correct types given the morphology info dict returned by Feagi

## Spawns correct morphology type given dict from FEAGI
static func create(name: StringName, morphology_type: Morphology.MORPHOLOGY_TYPE, morphology_details: Dictionary) -> Morphology:
	match morphology_type:
		Morphology.MORPHOLOGY_TYPE.FUNCTIONS:
			return FunctionMorphology.new(name, false, morphology_details["parameters"])
		Morphology.MORPHOLOGY_TYPE.VECTORS:
			return VectorMorphology.new(name, false, FEAGIUtils.array_of_arrays_to_vector3i_array(morphology_details["parameters"]["vectors"]))
		Morphology.MORPHOLOGY_TYPE.PATTERNS:
			return PatternMorphology.new(name, false, PatternVector3Pairs.raw_pattern_nested_array_to_array_of_PatternVector3s(morphology_details["parameters"]["patterns"]))
		Morphology.MORPHOLOGY_TYPE.COMPOSITE:
			return CompositeMorphology.new(name, false, FEAGIUtils.array_to_vector3i(morphology_details["parameters"]["src_seed"]), FEAGIUtils.array_of_arrays_to_vector2i_array(morphology_details["parameters"]["src_pattern"]), morphology_details["parameters"]["mapper_morphology"])
		_:
			# Something else? Error out
			@warning_ignore("assert_always_false")
			assert(false, "Invalid Morphology attempted to spawn")
			return Morphology.new("null", false) # Doesn't do anything, just needed to compile

## creates a morphology object but fills data with placeholder data until FEAGI responds
static func create_placeholder(name: StringName, type: Morphology.MORPHOLOGY_TYPE) -> Morphology:
	match type:
		Morphology.MORPHOLOGY_TYPE.FUNCTIONS:
			return FunctionMorphology.new(name, true, {})
		Morphology.MORPHOLOGY_TYPE.VECTORS:
			return VectorMorphology.new(name, true, [])
		Morphology.MORPHOLOGY_TYPE.PATTERNS:
			return PatternMorphology.new(name, true, [])
		Morphology.MORPHOLOGY_TYPE.COMPOSITE:
			return CompositeMorphology.new(name, true, Vector3i(1,1,1), [], "NOT_SET")
		_:
			# Something else? Error out
			@warning_ignore("assert_always_false")
			assert(false, "Invalid Morphology attempted to spawn")
			return Morphology.new("null", false) # Doesn't do anything, just needed to compile






