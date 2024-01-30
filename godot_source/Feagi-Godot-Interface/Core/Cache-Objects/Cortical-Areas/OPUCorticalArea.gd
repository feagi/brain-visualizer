extends BaseCorticalArea
class_name OPUCorticalArea
## Cortical area for processing outputs

func _init(ID: StringName, cortical_name: StringName, cortical_dimensions: Vector3i, visiblity: bool = true):
	_cortical_ID = ID
	_name = cortical_name
	_dimensions = cortical_dimensions
	_cortical_visiblity = visiblity

static func create_from_template(ID: StringName, template: CorticalTemplate, new_channel_count: int, visiblity: bool = true) -> OPUCorticalArea:
	return OPUCorticalArea.new(ID, template.cortical_name, template.calculate_IOPU_dimension(new_channel_count), visiblity)

## Updates all cortical details in here from a dict from FEAGI
func FEAGI_apply_detail_dictionary(data: Dictionary) -> void:
	if data == {}:
		return
	super(data)

	neuron_firing_parameters.FEAGI_apply_detail_dictionary(data)
	return

func _get_group() -> BaseCorticalArea.CORTICAL_AREA_TYPE:
	return BaseCorticalArea.CORTICAL_AREA_TYPE.OPU

func _has_neuron_firing_parameters() -> bool:
	return true
#endregion

#region Neuron Firing Parameters

# Holds all Neuron Firing Parameters
var neuron_firing_parameters: CorticalPropertyNeuronFiringParameters = CorticalPropertyNeuronFiringParameters.new()
#endregion
