extends RefCounted
class_name BaseMorphology
## Base morpology class, should not be spawned directly, instead spawn one of the types
const USER_NONMODIFIABLE_MORPHOLOGY_CLASSES_AS_PER_FEAGI: Array[MORPHOLOGY_INTERNAL_CLASS] = [MORPHOLOGY_INTERNAL_CLASS.CORE] # Which morphologies classes can the user not edit the details of?

signal numerical_properties_updated(self_reference: BaseMorphology)
signal retrieved_usage(usage_mappings: Array[PackedStringArray], is_being_used: bool, self_reference: BaseMorphology)
signal retrieved_description(description: StringName, self_reference: BaseMorphology)
signal internal_class_updated(new_internal_class: MORPHOLOGY_INTERNAL_CLASS) # Mainly used when we go from placeholder data to real data
signal editability_changed(editable: EDITABILITY)
signal deletability_changed(deletable: DELETABILITY)
signal about_to_be_deleted(self_reference: BaseMorphology)

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

enum EDITABILITY {
	IS_EDITABLE,
	NOT_EDITABLE_CORE_CLASS,
	NOT_EDITABLE_UNKNOWN,
	WARNING_EDITABLE_USED
}

enum DELETABILITY {
	IS_DELETABLE,
	NOT_EDITABLE_CORE_CLASS,
	NOT_DELETABLE_USED,
	NOT_DELETABLE_UNKNOWN
}
#TODO some of these vars should be privated with a public property access only!
var name: StringName
var description: StringName # TODO retrieve!
var type: MORPHOLOGY_TYPE
var internal_class: MORPHOLOGY_INTERNAL_CLASS # Will ALWAYS be CORE if data is placeholder
var is_placeholder_data: bool ## If numerical data inside this morphology is empty not because it is empty, but because we havent retrieved it from FEAGI yet
#TODO var is_definition_vessel: bool = false ## If this morphology object is merely a vessel to transport a definition around, and is not actually stored in cache or serves any other function
var latest_known_usage_by_cortical_area: Array[PackedStringArray]: ## May be out of date, be sure to poll latest when needed
	get: 
		return _last_known_usage_by_cortical_area
		
var latest_known_number_of_uses: int:
	get:
		return len(_last_known_usage_by_cortical_area)
		
var latest_known_is_being_used: bool:
	get:
		return len(_last_known_usage_by_cortical_area) > 0
		
var _last_known_usage_by_cortical_area: Array[PackedStringArray] = []

func _init(morphology_name: StringName, is_using_placeholder_data: bool, feagi_defined_internal_class: MORPHOLOGY_INTERNAL_CLASS):
	name = morphology_name
	is_placeholder_data = is_using_placeholder_data
	internal_class = feagi_defined_internal_class

## Spawns correct morphology type given dict from FEAGI and other details
static func create(morphology_name: StringName, morphology_type: MORPHOLOGY_TYPE, feagi_defined_internal_class: MORPHOLOGY_INTERNAL_CLASS, morphology_details: Dictionary) -> BaseMorphology:
	match morphology_type:
		BaseMorphology.MORPHOLOGY_TYPE.FUNCTIONS:
			var params: Dictionary
			if "parameters" in morphology_details.keys():
				params = morphology_details["parameters"]
			else:
				params = morphology_details
			return FunctionMorphology.new(morphology_name, false, feagi_defined_internal_class, params)
		BaseMorphology.MORPHOLOGY_TYPE.VECTORS:
			return VectorMorphology.new(morphology_name, false, feagi_defined_internal_class, FEAGIUtils.array_of_arrays_to_vector3i_array(morphology_details["vectors"]))
		BaseMorphology.MORPHOLOGY_TYPE.PATTERNS:
			return PatternMorphology.new(morphology_name, false, feagi_defined_internal_class, PatternVector3Pairs.raw_pattern_nested_array_to_array_of_PatternVector3s(morphology_details["patterns"]))
		BaseMorphology.MORPHOLOGY_TYPE.COMPOSITE:
			return CompositeMorphology.new(morphology_name, false, feagi_defined_internal_class, FEAGIUtils.array_to_vector3i(morphology_details["src_seed"]), FEAGIUtils.array_of_arrays_to_vector2i_array(morphology_details["src_pattern"]), morphology_details["mapper_morphology"])
		_:
			# Something else? Error out
			@warning_ignore("assert_always_false")
			assert(false, "Invalid BaseMorphology attempted to spawn")
			return NullMorphology.new()

## Creates a morphology as per the template from feagi
static func create_from_FEAGI_template(morphology_name: StringName, template_from_FEAGI_summary_call: Dictionary) -> BaseMorphology:
	var type: MORPHOLOGY_TYPE = BaseMorphology.morphology_type_str_to_type(template_from_FEAGI_summary_call["type"])
	var morphology_class: MORPHOLOGY_INTERNAL_CLASS = BaseMorphology.morphology_class_str_to_class(template_from_FEAGI_summary_call["class"])
	var parameters: Dictionary = template_from_FEAGI_summary_call["parameters"]
	return BaseMorphology.create(morphology_name, type, morphology_class, parameters)

## creates a morphology object but fills data with placeholder data until FEAGI responds
static func create_placeholder(morphology_name: StringName, morphology_type: MORPHOLOGY_TYPE) -> BaseMorphology:
	match morphology_type:
		BaseMorphology.MORPHOLOGY_TYPE.FUNCTIONS:
			return FunctionMorphology.new(morphology_name, true, MORPHOLOGY_INTERNAL_CLASS.UNKNOWN, {})
		BaseMorphology.MORPHOLOGY_TYPE.VECTORS:
			return VectorMorphology.new(morphology_name, true, MORPHOLOGY_INTERNAL_CLASS.UNKNOWN, [])
		BaseMorphology.MORPHOLOGY_TYPE.PATTERNS:
			return PatternMorphology.new(morphology_name, true, MORPHOLOGY_INTERNAL_CLASS.UNKNOWN, [])
		BaseMorphology.MORPHOLOGY_TYPE.COMPOSITE:
			return CompositeMorphology.new(morphology_name, true, MORPHOLOGY_INTERNAL_CLASS.UNKNOWN, Vector3i(1,1,1), [], "NOT_SET")
		_:
			# Something else? Error out
			@warning_ignore("assert_always_false")
			assert(false, "Invalid BaseMorphology attempted to spawn")
			return NullMorphology.new()

static func morphology_array_to_string_array_of_names(morphologies: Array[ BaseMorphology]) -> Array[StringName]:
	var output: Array[StringName] = []
	for morphology: BaseMorphology in morphologies:
		output.append(morphology.name)
	return output

static func morphology_type_to_string(morphology_type: MORPHOLOGY_TYPE) -> StringName:
	return str(MORPHOLOGY_TYPE.keys()[int(morphology_type)]).to_lower()

static func morphology_type_str_to_type(morphology_type_str: StringName) -> MORPHOLOGY_TYPE:
	if morphology_type_str.to_upper() not in MORPHOLOGY_TYPE:
		return MORPHOLOGY_TYPE.NULL
	return BaseMorphology.MORPHOLOGY_TYPE[(morphology_type_str.to_upper())]

static func morphology_class_to_string(morphology_class: MORPHOLOGY_INTERNAL_CLASS) -> StringName:
	return str(MORPHOLOGY_INTERNAL_CLASS.keys()[int(morphology_class)]).to_lower()

static func morphology_class_str_to_class(morphology_class_str: StringName) -> MORPHOLOGY_INTERNAL_CLASS:
	if morphology_class_str.to_upper() not in MORPHOLOGY_INTERNAL_CLASS:
		return MORPHOLOGY_INTERNAL_CLASS.UNKNOWN
	return BaseMorphology.MORPHOLOGY_INTERNAL_CLASS[(morphology_class_str.to_upper())]

## Use to retrieve if the morphology is deletable. Can become out of date without recent morphology and morphlogy usage data!
func get_latest_known_deletability() -> DELETABILITY:
	if internal_class == MORPHOLOGY_INTERNAL_CLASS.UNKNOWN:
		return DELETABILITY.NOT_DELETABLE_UNKNOWN
	if internal_class in USER_NONMODIFIABLE_MORPHOLOGY_CLASSES_AS_PER_FEAGI:
		return DELETABILITY.NOT_EDITABLE_CORE_CLASS
	if latest_known_is_being_used:
		return DELETABILITY.NOT_DELETABLE_USED
	return DELETABILITY.IS_DELETABLE

## Use to retrieve if the morphology is editable. Can become out of date without recent morphology and morphlogy usage data!
func get_latest_known_editability() -> EDITABILITY:
	if internal_class == MORPHOLOGY_INTERNAL_CLASS.UNKNOWN:
		return EDITABILITY.NOT_EDITABLE_UNKNOWN
	if internal_class in USER_NONMODIFIABLE_MORPHOLOGY_CLASSES_AS_PER_FEAGI:
		return EDITABILITY.NOT_EDITABLE_CORE_CLASS
	if latest_known_is_being_used:
		return EDITABILITY.WARNING_EDITABLE_USED
	return EDITABILITY.IS_EDITABLE

## Called by feagi to update usage
func feagi_update_usage(feagi_raw_input: Array[Array]) -> void:
	var deletability: DELETABILITY = get_latest_known_deletability()
	var editability: EDITABILITY = get_latest_known_editability()
	_last_known_usage_by_cortical_area = []
	for mapping: Array in feagi_raw_input:
		_last_known_usage_by_cortical_area.append(PackedStringArray([mapping[0], mapping[1]]))
	retrieved_usage.emit(_last_known_usage_by_cortical_area, latest_known_is_being_used, self)
	if deletability != get_latest_known_deletability():
		deletability_changed.emit(get_latest_known_deletability())
	if editability != get_latest_known_editability():
		editability_changed.emit(get_latest_known_editability())
	
		
## Called by FEAGI when updating a morphology definition (when type is consistent)
func feagi_update(_parameter_value: Dictionary, retrieved_internal_class: MORPHOLOGY_INTERNAL_CLASS) -> void:
	# extend in child classes
	var deletability: DELETABILITY = get_latest_known_deletability()
	var editability: EDITABILITY = get_latest_known_editability()
	is_placeholder_data = false
	if retrieved_internal_class != internal_class:
		internal_class = retrieved_internal_class
		internal_class_updated.emit(internal_class)
		if deletability != get_latest_known_deletability():
			deletability_changed.emit(get_latest_known_deletability())
		if editability != get_latest_known_editability():
			editability_changed.emit(get_latest_known_editability())
	numerical_properties_updated.emit(self)
