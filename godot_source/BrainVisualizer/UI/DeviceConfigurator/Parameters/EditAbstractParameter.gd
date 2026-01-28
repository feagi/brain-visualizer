extends BoxContainer
class_name EditAbstractParameter

const PARAMETER_TSCNS_FOLDER_PATH: StringName = "res://BrainVisualizer/UI/DeviceConfigurator/Parameters/"

var _cached_parameter_duplicate: AbstractParameter

## Spawns and setsup a parameter UI scene and adds it to a given parent
static func spawn_and_add_parameter_editor(parameter: AbstractParameter, parent_to_be: Control) -> EditAbstractParameter:
	var edit_UI: EditAbstractParameter = null
	if parameter is BooleanParameter:
		edit_UI = load(PARAMETER_TSCNS_FOLDER_PATH + "EditBoolParameter.tscn").instantiate()
		(edit_UI as EditBoolParameter).setup(parameter)
	elif parameter is FloatParameter:
		edit_UI = load(PARAMETER_TSCNS_FOLDER_PATH + "EditFloatParameter.tscn").instantiate()
		(edit_UI as EditFloatParameter).setup(parameter)
	elif parameter is IntegerParameter:
		edit_UI = load(PARAMETER_TSCNS_FOLDER_PATH + "EditIntParameter.tscn").instantiate()
		(edit_UI as EditIntParameter).setup(parameter)
	elif parameter is ObjectParameter:
		edit_UI = load(PARAMETER_TSCNS_FOLDER_PATH + "EditObjectParameter.tscn").instantiate()
		(edit_UI as EditObjectParameter).setup(parameter)
	elif parameter is Vector3Parameter:
		edit_UI = load(PARAMETER_TSCNS_FOLDER_PATH + "EditVector3Parameter.tscn").instantiate()
		(edit_UI as EditVector3Parameter).setup(parameter)
	elif parameter is PercentageParameter:
		edit_UI = load(PARAMETER_TSCNS_FOLDER_PATH + "EditPercentageParameter.tscn").instantiate()
		(edit_UI as EditPercentageParameter).setup(parameter)
	elif parameter is StringParameter:
		edit_UI = load(PARAMETER_TSCNS_FOLDER_PATH + "EditStringParameter.tscn").instantiate()
		(edit_UI as EditStringParameter).setup(parameter)
	else:
		push_error("No UI defined for given parameter type!")
		return null
	parent_to_be.add_child(edit_UI)
	return edit_UI

func base_setup(parameter: AbstractParameter) -> void:
	var label_text: Label = $Label
	label_text.text = parameter.label
	label_text.tooltip_text = parameter.description
	name = parameter.label
	_cached_parameter_duplicate = parameter.duplicate(true)

func export() -> AbstractParameter:
	# NOTE: Be sure to extend this in child classes to update values!
	return _cached_parameter_duplicate
