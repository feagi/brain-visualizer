extends VBoxContainer
class_name LeftBarMiddle

## User pressed update button, the following changes are requested
signal user_requested_update(changed_values: Dictionary)

var _Voxel_Neuron_Density: IntInput
var _Synaptic_Attractivity: IntInput
var _Post_Synaptic_Potential: IntInput
var _PSP_Max: IntInput
var _Plasticity_Constant: FloatInput
var _Fire_Threshold: IntInput
var _Threshold_Limit: IntInput
var _Refactory_Period: IntInput
var _Leak_Constant: IntInput
var _Leak_Varibility: IntInput
var _Threshold_Inc: IntInput
var _Consecutive_Fire_Count: IntInput
var _Snooze_Period: IntInput
var _Degeneracy_Constant: IntInput

var _hiding_container: HiderFrozenSize

var _growing_cortical_update: Dictionary

func _ready():
	_Voxel_Neuron_Density = $Voxel_Neuron_Density/Voxel_Neuron_Density
	_Synaptic_Attractivity = $Synaptic_Attractivity/Synaptic_Attractivity
	_Post_Synaptic_Potential = $Post_Synaptic_Potential/Post_Synaptic_Potential
	_PSP_Max = $PSP_Max/PSP_Max
	_Plasticity_Constant = $Plasticity_Constant/Plasticity_Constant
	_Fire_Threshold = $Fire_Threshold/Fire_Threshold
	_Threshold_Limit = $Threshold_Limit/Threshold_Limit
	_Refactory_Period = $Refactory_Period/Refactory_Period
	_Leak_Constant = $Leak_Constant/Leak_Constant
	_Leak_Varibility = $Leak_Varibility/Leak_Varibility
	_Threshold_Inc = $Threshold_Inc/Threshold_Inc
	_Consecutive_Fire_Count = $Consecutive_Fire_Count/Consecutive_Fire_Count
	_Snooze_Period = $Snooze_Period/Snooze_Period
	_Degeneracy_Constant = $Degeneracy_Constant/Degeneracy_Constant
	_hiding_container = $Update_Button_Hider

	_Voxel_Neuron_Density.int_confirmed.connect(user_request_Voxel_Neuron_Density)
	_Synaptic_Attractivity.int_confirmed.connect(user_request_Synaptic_Attractivity)
	_Post_Synaptic_Potential.int_confirmed.connect(user_request_Post_Synaptic_Potential)
	_PSP_Max.int_confirmed.connect(user_request_PSP_Max)
	_Plasticity_Constant.float_confirmed.connect(user_request_Plasticity_Constant)
	_Fire_Threshold.int_confirmed.connect(user_request_Fire_Threshold)
	_Threshold_Limit.int_confirmed.connect(user_request_Threshold_Limit)
	_Refactory_Period.int_confirmed.connect(user_request_Refactory_Period)
	_Leak_Constant.int_confirmed.connect(user_request_Leak_Constant)
	_Leak_Varibility.int_confirmed.connect(user_request_Leak_Varibility)
	_Threshold_Inc.int_confirmed.connect(user_request_Threshold_Inc)
	_Consecutive_Fire_Count.int_confirmed.connect(user_request_Consecutive_Fire_Count)
	_Snooze_Period.int_confirmed.connect(user_request_Snooze_Period)
	_Degeneracy_Constant.int_confirmed.connect(user_request_Degeneracy_Constant)

## set initial values from FEAGI Cache
func initial_values_from_FEAGI(cortical_reference: CorticalArea) -> void:
	var details: CorticalAreaDetails = cortical_reference.details
	_Voxel_Neuron_Density.current_int = details.cortical_neuron_per_vox_count
	_Synaptic_Attractivity.current_int = details.cortical_synaptic_attractivity
	_Post_Synaptic_Potential.current_int = details.neuron_post_synaptic_potential
	_PSP_Max.current_int = details.neuron_post_synaptic_potential_max
	_Plasticity_Constant.current_float = details.neuron_plasticity_constant
	_Fire_Threshold.current_int = details.neuron_fire_threshold
	_Threshold_Limit.current_int = details.neuron_firing_threshold_limit
	_Refactory_Period.current_int = details.neuron_refractory_period
	_Leak_Constant.current_int = details.neuron_leak_coefficient
	_Leak_Varibility.current_int = details.neuron_leak_variability
	_Threshold_Inc.current_int = details.neuron_fire_threshold_increment
	_Consecutive_Fire_Count.current_int = details.neuron_consecutive_fire_count
	_Snooze_Period.current_int = details.neuron_snooze_period
	_Degeneracy_Constant.current_int = details.neuron_degeneracy_coefficient

## Properties changed from FEAGI side, reflect here
func FEAGI_set_properties(cortical_area: CorticalArea) -> void:
	print("Left pane recieved new cortical details")
	var cortical_area_details: CorticalAreaDetails = cortical_area.details

	_Voxel_Neuron_Density.external_update_int(cortical_area_details.cortical_neuron_per_vox_count)
	_Synaptic_Attractivity.external_update_int(cortical_area_details.cortical_synaptic_attractivity)
	_Post_Synaptic_Potential.external_update_int(cortical_area_details.neuron_post_synaptic_potential)
	_PSP_Max.external_update_int(cortical_area_details.neuron_post_synaptic_potential_max)
	_Plasticity_Constant.external_update_float(cortical_area_details.neuron_plasticity_constant)
	_Fire_Threshold.external_update_int(cortical_area_details.neuron_fire_threshold)
	_Threshold_Limit.external_update_int(cortical_area_details.neuron_firing_threshold_limit)
	_Refactory_Period.external_update_int(cortical_area_details.neuron_refractory_period)
	_Leak_Constant.external_update_int(cortical_area_details.neuron_leak_coefficient)
	_Leak_Varibility.external_update_int(cortical_area_details.neuron_leak_variability)
	_Threshold_Inc.external_update_int(cortical_area_details.neuron_fire_threshold_increment)
	_Consecutive_Fire_Count.external_update_int(cortical_area_details.neuron_consecutive_fire_count)
	_Snooze_Period.external_update_int(cortical_area_details.neuron_snooze_period)
	_Degeneracy_Constant.external_update_int(cortical_area_details.neuron_degeneracy_coefficient)

	_hiding_container.toggle_child_visibility(false)
	_growing_cortical_update = {} # reset queued changes


## User pressed update button
func _user_requests_update() -> void:
	print("User requests %d changes to cortical details" % [_growing_cortical_update.size])
	user_requested_update.emit(_growing_cortical_update)

func user_request_Voxel_Neuron_Density(value: int) -> void:
	_growing_cortical_update["cortical_neuron_per_vox_count"] = value
	_hiding_container.toggle_child_visibility(true)

func user_request_Synaptic_Attractivity(value: int) -> void:
	_growing_cortical_update["cortical_synaptic_attractivity"] = value
	_hiding_container.toggle_child_visibility(true)

func user_request_Post_Synaptic_Potential(value: int) -> void:
	_growing_cortical_update["neuron_post_synaptic_potential"] = value
	_hiding_container.toggle_child_visibility(true)

func user_request_PSP_Max(value: int) -> void:
	_growing_cortical_update["neuron_post_synaptic_potential_max"] = value
	_hiding_container.toggle_child_visibility(true)

func user_request_Plasticity_Constant(value: int) -> void:
	_growing_cortical_update["neuron_plasticity_constant"] = value
	_hiding_container.toggle_child_visibility(true)

func user_request_Fire_Threshold(value: int) -> void:
	_growing_cortical_update["neuron_fire_threshold"] = value
	_hiding_container.toggle_child_visibility(true)

func user_request_Threshold_Limit(value: int) -> void:
	_growing_cortical_update["neuron_firing_threshold_limit"] = value
	_hiding_container.toggle_child_visibility(true)

func user_request_Refactory_Period(value: int) -> void:
	_growing_cortical_update["neuron_refractory_period"] = value
	_hiding_container.toggle_child_visibility(true)

func user_request_Leak_Constant(value: int) -> void:
	_growing_cortical_update["neuron_leak_coefficient"] = value
	_hiding_container.toggle_child_visibility(true)

func user_request_Leak_Varibility(value: int) -> void:
	_growing_cortical_update["neuron_leak_variability"] = value
	_hiding_container.toggle_child_visibility(true)

func user_request_Threshold_Inc(value: int) -> void:
	_growing_cortical_update["neuron_fire_threshold_increment"] = value
	_hiding_container.toggle_child_visibility(true)

func user_request_Consecutive_Fire_Count(value: int) -> void:
	_growing_cortical_update["neuron_consecutive_fire_count"] = value
	_hiding_container.toggle_child_visibility(true)

func user_request_Snooze_Period(value: int) -> void:
	_growing_cortical_update["neuron_snooze_period"] = value
	_hiding_container.toggle_child_visibility(true)

func user_request_Degeneracy_Constant(value: int) -> void:
	_growing_cortical_update["neuron_degeneracy_coefficient"] = value
	_hiding_container.toggle_child_visibility(true)


