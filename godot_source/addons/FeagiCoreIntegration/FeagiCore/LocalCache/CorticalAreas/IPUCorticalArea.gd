extends AbstractCorticalArea
class_name IPUCorticalArea
## Cortical area for processing inputs

signal cortical_device_count_updated(new_count: int, this_cortical_area: AbstractCorticalArea)
signal cortical_dimensions_per_device_updated(new_dims: Vector3i, this_cortical_area: AbstractCorticalArea)


var device_count: int:
	get: return _device_count

var cortical_dimensions_per_device: Vector3i:
	get: return _cortical_dimensions_per_device

func _init(ID: StringName, cortical_name: StringName, cortical_dimensions: Vector3i, visiblity: bool = true):
	var parent_region: BrainRegion = null
	if !FeagiCore.feagi_local_cache.brain_regions.is_root_available():
		push_error("FEAGI CORE CACHE: Unable to define root region for IPU %s as the root region isnt loaded!" % ID)
	else:
		parent_region = FeagiCore.feagi_local_cache.brain_regions.get_root_region()
	super(ID, cortical_name, cortical_dimensions, parent_region, visiblity) 

static func create_from_template(ID: StringName, template: CorticalTemplate, new_channel_count: int, visiblity: bool = true) -> IPUCorticalArea:
	return IPUCorticalArea.new(ID, template.cortical_name, template.calculate_IOPU_dimension(new_channel_count), visiblity)

## Updates all cortical details in here from a dict from FEAGI
func FEAGI_apply_detail_dictionary(data: Dictionary) -> void:
	if data == {}:
		return
	super(data)

	if "dev_count" in data.keys():
		FEAGI_set_device_count(data["dev_count"])
	
	if "cortical_dimensions_per_device" in data.keys():
		FEAGI_set_cortical_dimensions_per_device(FEAGIUtils.array_to_vector3i(data["cortical_dimensions_per_device"]))

	neuron_firing_parameters.FEAGI_apply_detail_dictionary(data)
	return

func FEAGI_set_device_count(new_count: int) -> void:
	_device_count = new_count
	cortical_device_count_updated.emit(new_count, self)

func FEAGI_set_cortical_dimensions_per_device(new_dimensions: Vector3i) -> void:
	_cortical_dimensions_per_device = new_dimensions
	cortical_dimensions_per_device_updated.emit(new_dimensions, self)

func _get_group() -> AbstractCorticalArea.CORTICAL_AREA_TYPE:
	return AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU

#OVERRIDDEN
func _user_can_edit_dimensions_directly() -> bool:
	return false

func _has_neuron_firing_parameters() -> bool:
	return true

var _device_count: int = 0
var _cortical_dimensions_per_device: Vector3i = Vector3i(1,1,1)

#end region

#region Neuron Firing Parameters

# Holds all Neuron Firing Parameters
var neuron_firing_parameters: CorticalPropertyNeuronFiringParameters = CorticalPropertyNeuronFiringParameters.new(self)
#endregion
