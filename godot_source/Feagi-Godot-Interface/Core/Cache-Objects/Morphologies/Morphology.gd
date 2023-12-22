extends Object
class_name Morphology
## Base morpology class, should not be spawned directly, instead spawn one of the types
const USER_NONEDITABLE_MORPHOLOGIES: PackedStringArray = ["memory"] # Which morphologies can the user not edit the details of?

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
var is_user_editable: bool = true ## if true, morphology cannot be edited or deleted

func _init(morphology_name: StringName, is_using_placeholder_data: bool):
	name = morphology_name
	is_placeholder_data = is_using_placeholder_data
	is_user_editable = !morphology_name in USER_NONEDITABLE_MORPHOLOGIES

static func morphology_array_to_string_array_of_names(morphologies: Array[Morphology]) -> Array[StringName]:
	var output: Array[StringName] = []
	for morphology: Morphology in morphologies:
		output.append(morphology.name)
	return output

