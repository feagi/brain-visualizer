extends Object
class_name Morphology
## Base morpology class, should not be spawned directly, instead spawn one of the types

signal retrieved_latest_usuage_of_morphology(usage_mappings: Array[Array])
signal about_to_be_deleted()

# Probably redudant to have an enum when we have multiple classes, but here somewhat for legacy reasons
enum MORPHOLOGY_TYPE {
	PATTERNS,
	VECTORS,
	FUNCTIONS,
	COMPOSITE,
	NULL,
}

var name: StringName
var description: StringName # TODO retrieve!
var type: MORPHOLOGY_TYPE
var is_placeholder_data: bool

func _init(morphology_name: StringName, is_using_placeholder_data: bool):
	name = morphology_name
	is_placeholder_data = is_using_placeholder_data
