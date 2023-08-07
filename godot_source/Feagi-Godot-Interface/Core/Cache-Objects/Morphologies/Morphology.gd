extends Object
class_name Morphology
## Base morpology class, should not be spawned directly, instead spawn one of the types

enum MORPHOLOGY_TYPE {
    PATTERN,
    VECTOR,
    FUNCTION,
    COMPOSITE,
}

var name: StringName
var type: MORPHOLOGY_TYPE

func _init(morphology_name: StringName):
    name = morphology_name