extends Morphology
class_name FunctionMorphology
## A "Custom" Morphology type

var parameters: Dictionary

func _init(morphology_name: StringName, custom_parameters: Dictionary):
    super(morphology_name)
    type = MORPHOLOGY_TYPE.FUNCTION
    parameters = custom_parameters

