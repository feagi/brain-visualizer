extends EditAbstractParameter
class_name EditBoolParameter

var _bool: CheckBox

func setup(parameter: BooleanParameter) -> void:
	base_setup(parameter)
	_bool = $Value
	_bool.disabled = false
	_bool.focus_mode = Control.FOCUS_ALL
	_bool.button_pressed = parameter.value

func export() -> AbstractParameter:
	var parameter: BooleanParameter = super()
	parameter.value = _bool.button_pressed
	return parameter
