extends EditAbstractParameter
class_name EditStringParameter

var _string: LineEdit

func setup(parameter: StringParameter) -> void:
	base_setup(parameter)
	_string = $Value
	_string.editable = true
	_string.focus_mode = Control.FOCUS_ALL
	_string.text = parameter.value
	
func export() -> AbstractParameter:
	var parameter: StringParameter = super()
	parameter.value = _string.text
	return parameter
