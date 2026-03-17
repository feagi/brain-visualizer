extends EditAbstractParameter
class_name EditPercentageParameter

var _percentage: SpinBox

func setup(parameter: PercentageParameter) -> void:
	base_setup(parameter)
	_percentage = $Value
	_percentage.editable = true
	_percentage.focus_mode = Control.FOCUS_ALL
	_percentage.max_value = parameter.maximum
	_percentage.min_value = parameter.minimum
	if parameter.value == IntegerParameter.NAN_EQUIVILANT_FOR_INT:
		_percentage.value = parameter.default
	else:
		_percentage.value = parameter.value
	
func export() -> AbstractParameter:
	var parameter: PercentageParameter = super()
	parameter.value = int(_percentage.value)
	return parameter
