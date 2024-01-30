extends BaseCorticalArea
class_name CoreCorticalArea
## Cannot be edited or removed

#region Base Functionality
func _init(ID: StringName, cortical_name: StringName, cortical_dimensions: Vector3i, visiblity: bool = true):
	_cortical_ID = ID
	_name = cortical_name
	_dimensions = cortical_dimensions
	_cortical_visiblity = visiblity

## Updates all cortical details in here from a dict from FEAGI
func FEAGI_apply_detail_dictionary(data: Dictionary) -> void:
	if data == {}:
		return
	super(data)

	neuron_firing_parameters.FEAGI_apply_detail_dictionary(data)
	return

func _user_can_edit_name() -> bool:
	return false

func _user_can_delete_area() -> bool:
	return false

func _get_group() -> BaseCorticalArea.CORTICAL_AREA_TYPE:
	return BaseCorticalArea.CORTICAL_AREA_TYPE.CORE

func _has_neuron_firing_parameters() -> bool:
	return true
#end region

#region Neuron Firing Parameters

# Holds all Neuron Firing Parameters
var neuron_firing_parameters: CorticalPropertyNeuronFiringParameters = CorticalPropertyNeuronFiringParameters.new()
#endregion
