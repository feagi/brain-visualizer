extends EditAbstractParameter
class_name EditIntParameter

var _int: SpinBox

func setup(parameter: IntegerParameter) -> void:
	base_setup(parameter)
	_int = $Value
	_int.editable = true
	_int.focus_mode = Control.FOCUS_ALL
	_int.max_value = parameter.maximum
	_int.min_value = parameter.minimum
	if parameter.value == IntegerParameter.NAN_EQUIVILANT_FOR_INT:
		_int.value = parameter.default
	else:
		_int.value = parameter.value
	
func export() -> AbstractParameter:
	var parameter: IntegerParameter = super()
	parameter.value = int(_int.value)
	return parameter
