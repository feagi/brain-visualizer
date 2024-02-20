extends Object
class_name Morphology
## Base morpology class, should not be spawned directly, instead spawn one of the types
const USER_NONEDITABLE_MORPHOLOGIES_AS_PER_FEAGI: Array[MORPHOLOGY_INTERNAL_CLASS] = [MORPHOLOGY_INTERNAL_CLASS.CORE] # Which morphologies can the user not edit the details of?

signal numerical_properties_updated(self_reference: Morphology)
signal retrieved_usage(usage_mappings: Array[PackedStringArray], is_being_used: bool, self_reference: Morphology)
signal retrieved_description(description: StringName, self_reference: Morphology)
signal internal_class_updated(new_internal_class: MORPHOLOGY_INTERNAL_CLASS)
signal about_to_be_deleted(self_reference: Morphology)

# Probably redudant to have an enum when we have multiple classes, but here somewhat for legacy reasons
enum MORPHOLOGY_TYPE {
	PATTERNS,
	VECTORS,
	FUNCTIONS,
	COMPOSITE,
	NULL,
}

enum MORPHOLOGY_INTERNAL_CLASS {
	CUSTOM,
	CORE,
	UNKNOWN
}

var name: StringName
var description: StringName # TODO retrieve!
var type: MORPHOLOGY_TYPE
var internal_class: MORPHOLOGY_INTERNAL_CLASS # Will ALWAYS be CORE if data is placeholder
var is_placeholder_data: bool
var is_user_editable: bool = true ## if false, morphology cannot be edited or deleted
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

func _init(morphology_name: StringName, is_using_placeholder_data: bool, feagi_defined_internal_class: MORPHOLOGY_INTERNAL_CLASS):
	name = morphology_name
	is_placeholder_data = is_using_placeholder_data
	internal_class = feagi_defined_internal_class
	is_user_editable = !internal_class in USER_NONEDITABLE_MORPHOLOGIES_AS_PER_FEAGI

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		about_to_be_deleted.emit(self) # Notify all others about deletion

## Spawns correct morphology type given dict from FEAGI
static func create(name: StringName, morphology_type: MORPHOLOGY_TYPE, feagi_defined_internal_class: MORPHOLOGY_INTERNAL_CLASS, morphology_details: Dictionary) -> Morphology:
	match morphology_type:
		Morphology.MORPHOLOGY_TYPE.FUNCTIONS:
			return FunctionMorphology.new(name, false, feagi_defined_internal_class, morphology_details["parameters"])
		Morphology.MORPHOLOGY_TYPE.VECTORS:
			return VectorMorphology.new(name, false, feagi_defined_internal_class, FEAGIUtils.array_of_arrays_to_vector3i_array(morphology_details["vectors"]))
		Morphology.MORPHOLOGY_TYPE.PATTERNS:
			return PatternMorphology.new(name, false, feagi_defined_internal_class, PatternVector3Pairs.raw_pattern_nested_array_to_array_of_PatternVector3s(morphology_details["patterns"]))
		Morphology.MORPHOLOGY_TYPE.COMPOSITE:
			return CompositeMorphology.new(name, false, feagi_defined_internal_class, FEAGIUtils.array_to_vector3i(morphology_details["src_seed"]), FEAGIUtils.array_of_arrays_to_vector2i_array(morphology_details["src_pattern"]), morphology_details["mapper_morphology"])
		_:
			# Something else? Error out
			@warning_ignore("assert_always_false")
			assert(false, "Invalid Morphology attempted to spawn")
			return NullMorphology.new()

## creates a morphology object but fills data with placeholder data until FEAGI responds
static func create_placeholder(name: StringName, type: MORPHOLOGY_TYPE) -> Morphology:
	match type:
		Morphology.MORPHOLOGY_TYPE.FUNCTIONS:
			return FunctionMorphology.new(name, true, MORPHOLOGY_INTERNAL_CLASS.UNKNOWN, {})
		Morphology.MORPHOLOGY_TYPE.VECTORS:
			return VectorMorphology.new(name, true, MORPHOLOGY_INTERNAL_CLASS.UNKNOWN, [])
		Morphology.MORPHOLOGY_TYPE.PATTERNS:
			return PatternMorphology.new(name, true, MORPHOLOGY_INTERNAL_CLASS.UNKNOWN, [])
		Morphology.MORPHOLOGY_TYPE.COMPOSITE:
			return CompositeMorphology.new(name, true, MORPHOLOGY_INTERNAL_CLASS.UNKNOWN, Vector3i(1,1,1), [], "NOT_SET")
		_:
			# Something else? Error out
			@warning_ignore("assert_always_false")
			assert(false, "Invalid Morphology attempted to spawn")
			return NullMorphology.new()

static func morphology_array_to_string_array_of_names(morphologies: Array[Morphology]) -> Array[StringName]:
	var output: Array[StringName] = []
	for morphology: Morphology in morphologies:
		output.append(morphology.name)
	return output

static func morphology_type_to_string(morphology_type: MORPHOLOGY_TYPE) -> StringName:
	return str(MORPHOLOGY_TYPE.keys()[int(morphology_type)]).to_lower()

## Called by feagi to update usage
func feagi_update_usage(feagi_raw_input: Array[Array]) -> void:
	_usage_by_cortical_area = []
	for mapping: Array in feagi_raw_input:
		_usage_by_cortical_area.append(PackedStringArray([mapping[0], mapping[1]]))
	retrieved_usage.emit(_usage_by_cortical_area, is_being_used, self)

## Called by FEAGI when updating a morphology definition (when type is consistent)
func feagi_update(_parameter_value: Dictionary, retrieved_internal_class: MORPHOLOGY_INTERNAL_CLASS) -> void:
	# extend in child classes
	is_placeholder_data = false
	if retrieved_internal_class != internal_class:
		internal_class = retrieved_internal_class
		internal_class_updated.emit(internal_class)
	numerical_properties_updated.emit(self)
	

