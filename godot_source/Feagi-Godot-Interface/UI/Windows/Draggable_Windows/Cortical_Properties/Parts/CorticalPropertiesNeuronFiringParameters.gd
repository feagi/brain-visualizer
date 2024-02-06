extends VBoxContainer
class_name CorticalPropertiesNeuronFiringParameters

## User pressed update button, the following changes are requested
signal user_requested_update(changed_values: Dictionary)

var _Fire_Threshold: IntInput
var _Threshold_Limit: IntInput
var _neuron_excitability: IntInput
var _Refactory_Period: IntInput
var _Leak_Constant: IntInput
var _Leak_Variability: IntInput
var _Consecutive_Fire_Count: IntInput
var _Snooze_Period: IntInput
var _Threshold_Inc: Vector3fField
var _MP_Accumulation: CheckButton

var _update_button: TextButton_Element

var _growing_cortical_update: Dictionary

func _ready():
	_Fire_Threshold = $Fire_Threshold/Fire_Threshold
	_Threshold_Limit = $Threshold_Limit/Threshold_Limit
	_Refactory_Period = $Refactory_Period/Refactory_Period
	_Leak_Constant = $Leak_Constant/Leak_Constant
	_Leak_Variability = $Leak_Variability/Leak_Variability
	_Threshold_Inc = $Fire_Threshold_Increment
	_Consecutive_Fire_Count = $Consecutive_Fire_Count/Consecutive_Fire_Count
	_Snooze_Period = $Snooze_Period/Snooze_Period
	_MP_Accumulation = $MP_Accumulation/MP_Accumulation
	_neuron_excitability = $Neuron_Excitability/Neuron_Excitability
	_update_button = $Update_Button
	
	_Fire_Threshold.int_confirmed.connect(user_request_Fire_Threshold)
	_Threshold_Limit.int_confirmed.connect(user_request_Threshold_Limit)
	_Refactory_Period.int_confirmed.connect(user_request_Refactory_Period)
	_Leak_Constant.int_confirmed.connect(user_request_Leak_Constant)
	_Leak_Variability.int_confirmed.connect(user_request_Leak_Variability)
	_Consecutive_Fire_Count.int_confirmed.connect(user_request_Consecutive_Fire_Count)
	_neuron_excitability.int_confirmed.connect(_user_request_neuron_excitability)
	_Snooze_Period.int_confirmed.connect(user_request_Snooze_Period)
	_Threshold_Inc.user_updated_vector.connect(user_request_Threshold_Inc)
	_MP_Accumulation.toggled.connect(user_request_MP_Accumumulation)


## set initial values from FEAGI Cache
func display_cortical_properties(cortical_reference) -> void: #NOTE: Can't type input since we cannot define multiple potential input classes
	_Fire_Threshold.current_int = cortical_reference.neuron_firing_parameters.neuron_fire_threshold
	_Threshold_Limit.current_int = cortical_reference.neuron_firing_parameters.neuron_firing_threshold_limit
	_Refactory_Period.current_int = cortical_reference.neuron_firing_parameters.neuron_refractory_period
	_Leak_Constant.current_int = cortical_reference.neuron_firing_parameters.neuron_leak_coefficient
	_Leak_Variability.current_int = cortical_reference.neuron_firing_parameters.neuron_leak_variability
	_Consecutive_Fire_Count.current_int = cortical_reference.neuron_firing_parameters.neuron_consecutive_fire_count
	_Snooze_Period.current_int = cortical_reference.neuron_firing_parameters.neuron_snooze_period
	_Threshold_Inc.current_vector = cortical_reference.neuron_firing_parameters.neuron_fire_threshold_increment
	_neuron_excitability.current_int = cortical_reference.neuron_firing_parameters.neuron_excitability
	_MP_Accumulation.set_pressed_no_signal(cortical_reference.neuron_firing_parameters.neuron_mp_charge_accumulation)
	
	cortical_reference.neuron_firing_parameters.neuron_mp_charge_accumulation_updated.connect(_feagi_update_MP_Accumumulation)
	cortical_reference.neuron_firing_parameters.neuron_leak_coefficient_updated.connect(_feagi_update_Leak_Constant)
	cortical_reference.neuron_firing_parameters.neuron_leak_variability_updated.connect(_feagi_update_Leak_Variability)
	cortical_reference.neuron_firing_parameters.neuron_refractory_period_updated.connect(_feagi_update_refactory_period)
	cortical_reference.neuron_firing_parameters.neuron_consecutive_fire_count_updated.connect(_feagi_update_Consecutive_Fire_Count)
	cortical_reference.neuron_firing_parameters.neuron_snooze_period_updated.connect(_feagi_update_Snooze_Period)
	cortical_reference.neuron_firing_parameters.neuron_fire_threshold_updated.connect(_feagi_update_Fire_Threshold)
	cortical_reference.neuron_firing_parameters.neuron_firing_threshold_limit_updated.connect(_feagi_update_Threshold_Limit)
	cortical_reference.neuron_firing_parameters.neuron_excitability_updated.connect(_feagi_update_Neuron_Excitability)
	cortical_reference.neuron_firing_parameters.neuron_fire_threshold_increment_updated.connect(_feagi_update_Threshold_Inc)
	
	

## User pressed update button
func _user_requests_update() -> void:
	if _growing_cortical_update == {}:
		# If user presses update button but no properties are set to change, do nothing
		return
	print("User requests %d changes to cortical details" % [len(_growing_cortical_update.keys())])
	user_requested_update.emit(_growing_cortical_update)

func user_request_Fire_Threshold(value: int) -> void:
	_growing_cortical_update["neuron_fire_threshold"] = value

func user_request_Threshold_Limit(value: int) -> void:
	_growing_cortical_update["neuron_firing_threshold_limit"] = value

func user_request_Refactory_Period(value: int) -> void:
	_growing_cortical_update["neuron_refractory_period"] = value

func user_request_Leak_Constant(value: int) -> void:
	_growing_cortical_update["neuron_leak_coefficient"] = value

func user_request_Leak_Variability(value: int) -> void:
	_growing_cortical_update["neuron_leak_variability"] = value

func user_request_Threshold_Inc(value: Vector3) -> void:
	_growing_cortical_update["neuron_fire_threshold_increment"] = FEAGIUtils.vector3_to_array(value)

func user_request_Consecutive_Fire_Count(value: int) -> void:
	_growing_cortical_update["neuron_consecutive_fire_count"] = value

func user_request_Snooze_Period(value: int) -> void:
	_growing_cortical_update["neuron_snooze_period"] = value

func user_request_MP_Accumumulation(value: bool) -> void:
	_growing_cortical_update["neuron_mp_charge_accumulation"] = value

func _user_request_neuron_excitability(value: int) -> void:
	_growing_cortical_update["neuron_excitability"] = value


func _feagi_update_Fire_Threshold(value: int, _cortical_ref) -> void:
	_Fire_Threshold.current_int = value

func _feagi_update_Threshold_Limit(value: int, _cortical_ref) -> void:
	_Threshold_Limit.current_int = value

func _feagi_update_refactory_period(value: int, _cortical_ref) -> void:
	_Refactory_Period.current_int  = value

func _feagi_update_Leak_Constant(value: int, _cortical_ref) -> void:
	_Leak_Constant.current_int = value

func _feagi_update_Leak_Variability(value: int, _cortical_ref) -> void:
	_Leak_Variability.current_int = value

func _feagi_update_Threshold_Inc(value: Vector3, _cortical_ref) -> void:
	_Threshold_Inc.current_vector = value

func _feagi_update_Consecutive_Fire_Count(value: int, _cortical_ref) -> void:
	_Consecutive_Fire_Count.current_int = value

func _feagi_update_Snooze_Period(value: int, _cortical_ref) -> void:
	_Snooze_Period.current_int = value

func _feagi_update_Neuron_Excitability(value: int, _cortical_ref) -> void:
	_neuron_excitability.current_int = value

func _feagi_update_MP_Accumumulation(value: bool, _cortical_ref) -> void:
	_MP_Accumulation.set_pressed_no_signal(value)

# Connected via TSCN to editable textboxes
func _enable_update_button():
	_update_button.disabled = false
