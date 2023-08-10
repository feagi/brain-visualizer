extends Object
class_name MorphologyFactory
## Handles spawning morphologies of correct types given the morphology info dict returned by Feagi

## Spawns correct morphology type given dict from FEAGI
static func create(morphology_details: Dictionary) -> Morphology:
    var name: StringName = morphology_details["morphology_name"]
    var parameters: Dictionary = morphology_details["Dictionary"]
    var type_str: StringName = morphology_details["type"]
    var type: Morphology.MORPHOLOGY_TYPE = Morphology.MORPHOLOGY_TYPE.find_key(type_str.to_upper())
    match type:
        Morphology.MORPHOLOGY_TYPE.FUNCTION:
            return FunctionMorphology.new(name, false, parameters["parameters"])
        Morphology.MORPHOLOGY_TYPE.VECTOR:
            return VectorMorphology.new(name, false, FEAGIUtils.array_of_arrays_to_vector3i_array(parameters["vectors"]))
        Morphology.MORPHOLOGY_TYPE.PATTERN:
            return PatternMorphology.new(name, false, _raw_pattern_nested_array_to_array_of_PatternVector3s(parameters["patterns"]))
        Morphology.MORPHOLOGY_TYPE.COMPOSITE:
            return CompositeMorphology.new(name, false, FEAGIUtils.array_to_vector3i(parameters["src_seed"]), FEAGIUtils.array_of_arrays_to_vector2i_array(parameters["src_pattern"]), parameters["mapper_morphology"])
        _:
            # Something else? Error out
            @warning_ignore("assert_always_false")
            assert(false, "Invalid Morphology attempted to spawn")
            return Morphology.new("null", false) # Doesn't do anything, just needed to compile

## creates a morphology object but fills data with placeholder data until FEAGI responds
static func create_placeholder(name: StringName, type: Morphology.MORPHOLOGY_TYPE) -> Morphology:
    match type:
        Morphology.MORPHOLOGY_TYPE.FUNCTION:
            return FunctionMorphology.new(name, true, {})
        Morphology.MORPHOLOGY_TYPE.VECTOR:
            return VectorMorphology.new(name, true, [])
        Morphology.MORPHOLOGY_TYPE.PATTERN:
            return PatternMorphology.new(name, true, [])
        Morphology.MORPHOLOGY_TYPE.COMPOSITE:
            return CompositeMorphology.new(name, true, Vector3i(1,1,1), [], "NOT_SET")
        _:
            # Something else? Error out
            @warning_ignore("assert_always_false")
            assert(false, "Invalid Morphology attempted to spawn")
            return Morphology.new("null", false) # Doesn't do anything, just needed to compile


## Converts an array of arrays from the pattern morphologies into an array of PatternVector3s
static func _raw_pattern_nested_array_to_array_of_PatternVector3s(raw_array: Array[Array]) -> Array[PatternVector3Pairs]:
    # Preinit up here to reduce GC
    var X: PatternVal
    var Y: PatternVal
    var Z: PatternVal
    var pair: Array = [null, null]
    var output: Array[PatternVector3Pairs] = []
    for pair_in in raw_array:
        for pair_in_index in [0,1]:
            for vector_raw in pair_in[pair_in_index]:
                X = PatternVal.new(vector_raw[0])
                Y = PatternVal.new(vector_raw[1])
                Z = PatternVal.new(vector_raw[2])
                pair[pair_in_index] = PatternVector3.new(X, Y, Z)
        output.append(PatternVector3Pairs.new(pair[0], pair[1]))
    return output





