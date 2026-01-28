extends EditAbstractParameter
class_name EditFloatParameter

var _float: SpinBox

func setup(parameter: FloatParameter) -> void:
	base_setup(parameter)
	_float = $Value
	_float.editable = true
	_float.focus_mode = Control.FOCUS_ALL
	_float.max_value = parameter.maximum
	_float.min_value = parameter.minimum
	if is_nan(parameter.value):
		_float.value = parameter.default
	else:
		_float.value = parameter.value
	
func export() -> AbstractParameter:
	var parameter: FloatParameter = super()
	parameter.value = _float.value
	return parameter
