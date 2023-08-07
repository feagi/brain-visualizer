extends Object
class_name Morphology
## Base morpology class, should not be spawned directly, instead spawn one of the types

enum TYPE {
    PATTERN,
    VECTOR,
    FUNCTION,
    COMPOSITE,
}

var name: StringName
var type: TYPE

func _init(morphology_name: StringName, morphology_type: TYPE):
    name = morphology_name
    type = morphology_type