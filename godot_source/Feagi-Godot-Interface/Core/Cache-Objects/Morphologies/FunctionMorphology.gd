extends Morphology
class_name FunctionMorphology
## A "Custom" Morphology type

var parameters: Dictionary

func _init(morphology_name: StringName, morphology_type: TYPE, custom_parameters: Dictionary):
    super(morphology_name, morphology_type)
    parameters = custom_parameters

