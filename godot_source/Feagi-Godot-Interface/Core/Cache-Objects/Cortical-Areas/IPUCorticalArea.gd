extends BaseCorticalArea
class_name IPUCorticalArea
## Cortical area for processing inputs

#region Base Functionality
var channel_count: int:
	get: return _channel_count

var _channel_count: int

func _init(ID: StringName, template: CorticalTemplate, new_channel_count: int, visiblity: bool = true):
	_cortical_ID = ID
	_name = template.cortical_name
	_dimensions = template.calculate_IOPU_dimension(new_channel_count)
	_channel_count = new_channel_count
	_cortical_visiblity = visiblity

## Updates all cortical details in here from a dict from FEAGI
func FEAGI_apply_detail_dictionary(data: Dictionary) -> void:
	if data == {}:
		return
	super(data)

	if "neuron_fire_threshold" in data.keys(): 
		neuron_fire_threshold = data["neuron_fire_threshold"]
	if "neuron_fire_threshold_increment" in data.keys(): 
		neuron_fire_threshold_increment = FEAGIUtils.array_to_vector3i(data["neuron_fire_threshold_increment"])
	if "neuron_firing_threshold_limit" in data.keys(): 
		neuron_firing_threshold_limit = data["neuron_firing_threshold_limit"]
	if "neuron_refractory_period" in data.keys(): 
		neuron_refractory_period = data["neuron_refractory_period"]
	if "neuron_leak_coefficient" in data.keys(): 
		neuron_leak_coefficient = data["neuron_leak_coefficient"]
	if "neuron_leak_variability" in data.keys(): 
		neuron_leak_variability = data["neuron_leak_variability"]
	if "neuron_consecutive_fire_count" in data.keys(): 
		neuron_consecutive_fire_count = data["neuron_consecutive_fire_count"]
	if "neuron_snooze_period" in data.keys(): 
		neuron_snooze_period = data["neuron_snooze_period"]
	if "neuron_mp_charge_accumulation" in data.keys(): 
		neuron_mp_charge_accumulation = data["neuron_mp_charge_accumulation"]
	return

func _get_group() -> BaseCorticalArea.CORTICAL_AREA_TYPE:
	return BaseCorticalArea.CORTICAL_AREA_TYPE.IPU
#end region

#region Neuron Firing Parameters
var neuron_mp_charge_accumulation: bool = false
var neuron_leak_coefficient: int = 0
var neuron_leak_variability: int = 0
var neuron_refractory_period: int = 0
var neuron_consecutive_fire_count: int = 0
var neuron_snooze_period: int = 0
var neuron_fire_threshold: int = 0
var neuron_firing_threshold_limit: int = 0
var neuron_fire_threshold_increment: Vector3 = Vector3(0,0,0)
#endregion
