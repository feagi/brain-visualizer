extends EditAbstractParameter
class_name EditVector3Parameter

var _x: SpinBox
var _y: SpinBox
var _z: SpinBox

func setup(parameter: Vector3Parameter) -> void:
	base_setup(parameter)
	_x = $x
	_y = $y
	_z = $z
	_x.editable = true
	_y.editable = true
	_z.editable = true
	_x.focus_mode = Control.FOCUS_ALL
	_y.focus_mode = Control.FOCUS_ALL
	_z.focus_mode = Control.FOCUS_ALL
	if parameter.value.x == IntegerParameter.NAN_EQUIVILANT_FOR_INT:
		_x.value = parameter.default.x
		_y.value = parameter.default.y
		_z.value = parameter.default.z
	else:
		_x.value = parameter.value.x
		_y.value = parameter.value.y
		_z.value = parameter.value.z
	
func export() -> AbstractParameter:
	var parameter: Vector3Parameter = super()
	parameter.value = Vector3(_x.value, _y.value, _z.value)
	return parameter
