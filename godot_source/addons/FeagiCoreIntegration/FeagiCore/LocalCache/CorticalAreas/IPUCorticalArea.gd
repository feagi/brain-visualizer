extends BaseCorticalArea
class_name IPUCorticalArea
## Cortical area for processing inputs


func _init(ID: StringName, cortical_name: StringName, cortical_dimensions: Vector3i, parent_region: BrainRegion, visiblity: bool = true):
	super(ID, cortical_name, cortical_dimensions, parent_region, visiblity) # This abstraction is useless right now! Too Bad!

static func create_from_template(ID: StringName, template: CorticalTemplate, new_channel_count: int, parent_region: BrainRegion, visiblity: bool = true) -> IPUCorticalArea:
	return IPUCorticalArea.new(ID, template.cortical_name, template.calculate_IOPU_dimension(new_channel_count), parent_region, visiblity)

## Updates all cortical details in here from a dict from FEAGI
func FEAGI_apply_detail_dictionary(data: Dictionary) -> void:
	if data == {}:
		return
	super(data)

	neuron_firing_parameters.FEAGI_apply_detail_dictionary(data)
	return

func _get_group() -> BaseCorticalArea.CORTICAL_AREA_TYPE:
	return BaseCorticalArea.CORTICAL_AREA_TYPE.IPU

func _has_neuron_firing_parameters() -> bool:
	return true
#end region

#region Neuron Firing Parameters

# Holds all Neuron Firing Parameters
var neuron_firing_parameters: CorticalPropertyNeuronFiringParameters = CorticalPropertyNeuronFiringParameters.new(self)
#endregion
