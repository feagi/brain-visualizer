extends Morphology
class_name FunctionMorphology
## A "Custom" Morphology type

var parameters: Dictionary

func _init(morphology_name: StringName, is_using_placeholder_data: bool, feagi_defined_internal_class: MORPHOLOGY_INTERNAL_CLASS, custom_parameters: Dictionary):
	super(morphology_name, is_using_placeholder_data, feagi_defined_internal_class)
	type = MORPHOLOGY_TYPE.FUNCTIONS
	parameters = custom_parameters

## Called by FEAGI when updating a morphology definition (when type is consistent)
func feagi_update(parameter_value: Dictionary, retrieved_internal_class: MORPHOLOGY_INTERNAL_CLASS) -> void:
	parameters = parameter_value
	super(parameter_value , retrieved_internal_class )
