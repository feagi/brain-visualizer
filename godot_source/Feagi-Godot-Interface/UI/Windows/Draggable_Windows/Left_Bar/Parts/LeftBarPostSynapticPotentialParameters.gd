extends VBoxContainer
class_name LeftBarPostSynapticPotentialParameters

## User pressed update button, the following changes are requested
signal user_requested_update(changed_values: Dictionary)

var _Post_Synaptic_Potential: FloatInput
var _PSP_Max: FloatInput
var _Degeneracy_Constant: IntInput
var _PSP_Uniformity: CheckButton
var _MP_Driven_PSP: CheckButton

var _update_button: TextButton_Element

var _growing_cortical_update: Dictionary

func _ready():
	_Post_Synaptic_Potential = $Post_Synaptic_Potential/Post_Synaptic_Potential
	_PSP_Max = $PSP_Max/PSP_Max
	_Degeneracy_Constant = $Degeneracy_Constant/Degeneracy_Constant
	_PSP_Uniformity = $PSP_Uniformity/PSP_Uniformity
	_MP_Driven_PSP = $MP_Driven_PSP/MP_Driven_PSP
	_update_button = $Update_Button
	
	_Post_Synaptic_Potential.float_confirmed.connect(user_request_Post_Synaptic_Potential)
	_PSP_Max.float_confirmed.connect(user_request_PSP_Max)
	_Degeneracy_Constant.int_confirmed.connect(user_request_Degeneracy_Constant)
	_PSP_Uniformity.toggled.connect(user_request_PSP_Uniforimity)
	_MP_Driven_PSP.toggled.connect(user_request_MP_Driven_PSP)


## set initial values from FEAGI Cache
func display_cortical_properties(cortical_reference: BaseCorticalArea) -> void:
	_Post_Synaptic_Potential.current_float = cortical_reference.neuron_post_synaptic_potential
	_PSP_Max.current_float = cortical_reference.neuron_post_synaptic_potential_max
	_Degeneracy_Constant.current_int = cortical_reference.neuron_degeneracy_coefficient
	_PSP_Uniformity.set_pressed_no_signal(cortical_reference.neuron_psp_uniform_distribution)
	_MP_Driven_PSP.set_pressed_no_signal(cortical_reference.neuron_mp_driven_psp)


## User pressed update button
func _user_requests_update() -> void:
	if _growing_cortical_update == {}:
		# If user presses update button but no properties are set to change, do nothing
		_update_button.disabled = true
		return
	print("User requests %d changes to cortical details" % [len(_growing_cortical_update.keys())])
	user_requested_update.emit(_growing_cortical_update)

func user_request_Post_Synaptic_Potential(value: int) -> void:
	_growing_cortical_update["neuron_post_synaptic_potential"] = value

func user_request_PSP_Max(value: int) -> void:
	_growing_cortical_update["neuron_post_synaptic_potential_max"] = value

func user_request_Degeneracy_Constant(value: int) -> void:
	_growing_cortical_update["neuron_degeneracy_coefficient"] = value

func user_request_PSP_Uniforimity(value: bool) -> void:
	_growing_cortical_update["neuron_psp_uniform_distribution"] = value

func user_request_MP_Driven_PSP(value: bool) -> void:
	_growing_cortical_update["neuron_mp_driven_psp"] = value

# Connected via TSCN to editable textboxes
func _enable_update_button():
	_update_button.disabled = false
