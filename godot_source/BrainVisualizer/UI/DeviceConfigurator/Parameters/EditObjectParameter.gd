extends EditAbstractParameter
class_name EditObjectParameter

var _holder: VBoxContainer

func setup(parameter: ObjectParameter) -> void:
	base_setup(parameter)
	_holder = $Holder
	for subparameter in parameter.value:
		EditAbstractParameter.spawn_and_add_parameter_editor(subparameter, _holder)
	
func export() -> AbstractParameter:
	var parameter: ObjectParameter = super()
	var subparameters: Array[AbstractParameter] = []
	for child in _holder.get_children():
		if child is EditAbstractParameter:
			subparameters.append(child.export())
	parameter.value = subparameters
	return parameter
