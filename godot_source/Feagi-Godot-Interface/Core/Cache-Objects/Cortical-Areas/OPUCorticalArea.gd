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

	if "neuron_fire_threshold" in data.keys(): 
		neuron_fire_threshold = data["neuron_fire_threshold"]
	if "neuron_fire_threshold_increment" in data.keys(): 
		neuron_fire_threshold_increment = FEAGIUtils.untyped_array_to_vector3(data["neuron_fire_threshold_increment"])
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
	return BaseCorticalArea.CORTICAL_AREA_TYPE.OPU

func _has_neuron_firing_parameters() -> bool:
	return true
#endregion

#region Neuron Firing Parameters

signal neuron_mp_charge_accumulation_updated(val: bool, this_cortical_area: OPUCorticalArea)
signal neuron_leak_coefficient_updated(val: int, this_cortical_area: OPUCorticalArea)
signal neuron_leak_variability_updated(val: int, this_cortical_area: OPUCorticalArea)
signal neuron_refractory_period_updated(val: int, this_cortical_area: OPUCorticalArea)
signal neuron_consecutive_fire_count_updated(val: int, this_cortical_area: OPUCorticalArea)
signal neuron_snooze_period_updated(val: int, this_cortical_area: OPUCorticalArea)
signal neuron_fire_threshold_updated(val: int, this_cortical_area: OPUCorticalArea)
signal neuron_firing_threshold_limit_updated(val: int, this_cortical_area: OPUCorticalArea)
signal neuron_fire_threshold_increment_updated(val: Vector3, this_cortical_area: OPUCorticalArea)

var neuron_mp_charge_accumulation: bool:
	get:
		return _neuron_mp_charge_accumulation
	set(v):
		_set_neuron_mp_charge_accumulation(v)

var neuron_leak_coefficient: int:
	get:
		return _neuron_leak_coefficient
	set(v):
		_set_neuron_leak_coefficient(v)

var neuron_leak_variability: int:
	get:
		return _neuron_leak_variability
	set(v):
		_set_neuron_leak_variability(v)

var neuron_refractory_period: int:
	get:
		return _neuron_refractory_period
	set(v):
		_set_neuron_refractory_period(v)

var neuron_consecutive_fire_count: int:
	get:
		return _neuron_consecutive_fire_count
	set(v):
		_set_neuron_consecutive_fire_count(v)

var neuron_snooze_period: int:
	get:
		return _neuron_snooze_period
	set(v):
		_set_neuron_snooze_period(v)

var neuron_fire_threshold: int:
	get:
		return _neuron_fire_threshold
	set(v):
		_set_neuron_fire_threshold(v)

var neuron_firing_threshold_limit: int:
	get:
		return _neuron_firing_threshold_limit
	set(v):
		_set_neuron_firing_threshold_limit(v)

var neuron_fire_threshold_increment: Vector3:
	get:
		return _neuron_fire_threshold_increment
	set(v):
		_set_neuron_fire_threshold_increment(v)

var _neuron_mp_charge_accumulation: bool = false
var _neuron_leak_coefficient: int = 0
var _neuron_leak_variability: int = 0
var _neuron_refractory_period: int = 0
var _neuron_consecutive_fire_count: int = 0
var _neuron_snooze_period: int = 0
var _neuron_fire_threshold: int = 0
var _neuron_firing_threshold_limit: int = 0
var _neuron_fire_threshold_increment: Vector3 = Vector3(0,0,0)

func _set_neuron_mp_charge_accumulation(new_val: bool) -> void:
	if new_val == _neuron_mp_charge_accumulation:
		return
	_neuron_mp_charge_accumulation = new_val
	neuron_mp_charge_accumulation_updated.emit(new_val, self)

func _set_neuron_leak_coefficient(new_val: int) -> void:
	if new_val == _neuron_leak_coefficient: 
		return
	_neuron_leak_coefficient = new_val
	neuron_leak_coefficient_updated.emit(new_val, self)

func _set_neuron_leak_variability(new_val: int) -> void:
	if new_val == _neuron_leak_variability: 
		return
	_neuron_leak_variability = new_val
	neuron_leak_variability_updated.emit(new_val, self)

func _set_neuron_refractory_period(new_val: int) -> void:
	if new_val == _neuron_refractory_period: 
		return
	_neuron_refractory_period = new_val
	neuron_refractory_period_updated.emit(new_val, self)

func _set_neuron_consecutive_fire_count(new_val: int) -> void:
	if new_val == _neuron_consecutive_fire_count: 
		return
	_neuron_consecutive_fire_count = new_val
	neuron_consecutive_fire_count_updated.emit(new_val, self)

func _set_neuron_snooze_period(new_val: int) -> void:
	if new_val == _neuron_snooze_period: 
		return
	_neuron_snooze_period = new_val
	neuron_snooze_period_updated.emit(new_val, self)

func _set_neuron_fire_threshold(new_val: int) -> void:
	if new_val == _neuron_fire_threshold: 
		return
	_neuron_fire_threshold = new_val
	neuron_fire_threshold_updated.emit(new_val, self)

func _set_neuron_firing_threshold_limit(new_val: int) -> void:
	if new_val == _neuron_firing_threshold_limit: 
		return
	_neuron_firing_threshold_limit = new_val
	neuron_firing_threshold_limit_updated.emit(new_val, self)

func _set_neuron_fire_threshold_increment(new_val: Vector3) -> void:
	if new_val == _neuron_fire_threshold_increment: 
		return
	_neuron_fire_threshold_increment = new_val
	neuron_fire_threshold_increment_updated.emit(new_val, self)
#endregion
