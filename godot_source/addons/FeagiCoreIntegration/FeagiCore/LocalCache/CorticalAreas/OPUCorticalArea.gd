extends AbstractCorticalArea
class_name OPUCorticalArea
## Cortical area for processing outputs

func _init(ID: StringName, cortical_name: StringName, cortical_dimensions: Vector3i, visiblity: bool = true):
	var parent_region: BrainRegion = null
	if !FeagiCore.feagi_local_cache.brain_regions.is_root_available():
		push_error("FEAGI CORE CACHE: Unable to define root region for OPU %s as the root region isnt loaded!" % ID)
	else:
		parent_region = FeagiCore.feagi_local_cache.brain_regions.get_root_region()
	super(ID, cortical_name, cortical_dimensions, parent_region, visiblity) 

static func create_from_template(ID: StringName, template: CorticalTemplate, new_channel_count: int, visiblity: bool = true) -> OPUCorticalArea:
	return OPUCorticalArea.new(ID, template.cortical_name, template.calculate_IOPU_dimension(new_channel_count), visiblity)

## Updates all cortical details in here from a dict from FEAGI
func FEAGI_apply_detail_dictionary(data: Dictionary) -> void:
	if data == {}:
		return
	super(data)

	neuron_firing_parameters.FEAGI_apply_detail_dictionary(data)
	return

func _get_group() -> AbstractCorticalArea.CORTICAL_AREA_TYPE:
	return AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU

func _can_set_device_count() -> bool:
	return true

func _has_neuron_firing_parameters() -> bool:
	return true

#endregion

#region Neuron Firing Parameters

# Holds all Neuron Firing Parameters
var neuron_firing_parameters: CorticalPropertyNeuronFiringParameters = CorticalPropertyNeuronFiringParameters.new(self)
#endregion
