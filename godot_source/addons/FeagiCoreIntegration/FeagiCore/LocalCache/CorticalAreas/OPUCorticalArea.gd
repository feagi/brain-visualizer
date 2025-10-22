extends AbstractCorticalArea
class_name OPUCorticalArea
## Cortical area for processing outputs

signal cortical_device_count_updated(new_count: int, this_cortical_area: AbstractCorticalArea)
signal cortical_dimensions_per_device_updated(new_dims: Vector3i, this_cortical_area: AbstractCorticalArea)

var device_count: int:
	get: return _device_count

var cortical_dimensions_per_device: Vector3i:
	get: return _cortical_dimensions_per_device

var has_controller_ID: bool:
	get: return _genome_ID in FeagiCore.feagi_local_cache.OPU_cortical_ID_to_capability_key

var controller_ID: StringName:
	get: 
		if _genome_ID in FeagiCore.feagi_local_cache.OPU_cortical_ID_to_capability_key:
			return FeagiCore.feagi_local_cache.OPU_cortical_ID_to_capability_key[_genome_ID]
		else:
			return &""

func _init(ID: StringName, cortical_name: StringName, cortical_dimensions: Vector3i, visiblity: bool = true):
	var parent_region: BrainRegion = null
	if !FeagiCore.feagi_local_cache.brain_regions.is_root_available():
		push_error("FEAGI CORE CACHE: Unable to define root region for OPU %s as the root region isnt loaded!" % ID)
	else:
		parent_region = FeagiCore.feagi_local_cache.brain_regions.get_root_region()
	super(ID, cortical_name, cortical_dimensions, parent_region, visiblity) 

static func create_from_template(ID: StringName, template: CorticalTemplate, new_device_count: int, visiblity: bool = true) -> OPUCorticalArea:
	return OPUCorticalArea.new(ID, template.cortical_name, template.calculate_IOPU_dimension(new_device_count), visiblity)

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

## Given an array of configurator capability dictionaries (recieved from agent properties), get all custom names of this cortical area
func get_custom_names(configurator_capabilities: Array[Dictionary], feagi_index: int) -> Array[StringName]:
	if !has_controller_ID:
		return []
	var output: Array[StringName] = []
	for configurator_capability in configurator_capabilities:
		if !configurator_capability.has("output"):
			continue
		var configurator_output: Dictionary = configurator_capability["output"]
		if !configurator_output.has(str(controller_ID)):
			continue
		var devices: Dictionary = configurator_output[controller_ID]
		for device: Dictionary in devices.values():
			if !device.has("feagi_index"):
				continue
			if str(device["feagi_index"]).to_int() != feagi_index:
				continue
			output.append((str(configurator_capability["agent_ID"]) + ": " + str(device["custom_name"])))
	return output

func _get_group() -> AbstractCorticalArea.CORTICAL_AREA_TYPE:
	return AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU

#OVERRIDDEN
func _user_can_edit_dimensions_directly() -> bool:
	return false

func _has_neuron_firing_parameters() -> bool:
	return true

var _device_count: int = 0
var _cortical_dimensions_per_device: Vector3i = Vector3i(1,1,1)

#endregion

#region Neuron Firing Parameters

# Holds all Neuron Firing Parameters
var neuron_firing_parameters: CorticalPropertyNeuronFiringParameters = CorticalPropertyNeuronFiringParameters.new(self)
#endregion
