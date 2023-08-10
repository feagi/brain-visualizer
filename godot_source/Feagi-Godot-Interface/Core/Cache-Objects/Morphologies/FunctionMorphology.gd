extends Morphology
class_name FunctionMorphology
## A "Custom" Morphology type

var parameters: Dictionary

func _init(morphology_name: StringName, is_using_placeholder_data: bool, custom_parameters: Dictionary):
    super(morphology_name, is_using_placeholder_data)
    type = MORPHOLOGY_TYPE.FUNCTION
    parameters = custom_parameters

