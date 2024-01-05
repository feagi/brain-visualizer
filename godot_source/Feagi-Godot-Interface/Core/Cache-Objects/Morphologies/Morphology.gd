extends Object
class_name Morphology
## Base morpology class, should not be spawned directly, instead spawn one of the types
const USER_NONEDITABLE_MORPHOLOGIES: PackedStringArray = ["memory"] # Which morphologies can the user not edit the details of?

signal retrieved_usage(usage_mappings: Array[PackedStringArray], is_being_used: bool, self_reference: Morphology)
signal retrieved_description(description: StringName, self_reference: Morphology)
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
var usage_by_cortical_area: Array[PackedStringArray]: ## May be out of date, be sure to poll latest when needed
	get: 
		return _usage_by_cortical_area
var number_of_uses: int:
	get:
		return len(_usage_by_cortical_area)
var is_being_used: bool:
	get:
		return len(_usage_by_cortical_area) > 0

var _usage_by_cortical_area: Array[PackedStringArray] = []

func _init(morphology_name: StringName, is_using_placeholder_data: bool):
	name = morphology_name
	is_placeholder_data = is_using_placeholder_data
	is_user_editable = !morphology_name in USER_NONEDITABLE_MORPHOLOGIES

static func morphology_array_to_string_array_of_names(morphologies: Array[Morphology]) -> Array[StringName]:
	var output: Array[StringName] = []
	for morphology: Morphology in morphologies:
		output.append(morphology.name)
	return output

## Called by feagi to update usage
func feagi_update_usage(feagi_raw_input: Array[Array]) -> void:
	_usage_by_cortical_area = []
	for mapping: Array in feagi_raw_input:
		_usage_by_cortical_area.append(PackedStringArray([mapping[0], mapping[1]]))
	retrieved_usage.emit(_usage_by_cortical_area, is_being_used, self)
