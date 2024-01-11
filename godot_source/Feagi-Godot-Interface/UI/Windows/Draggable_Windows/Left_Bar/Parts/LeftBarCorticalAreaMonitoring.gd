extends VBoxContainer
class_name LeftBarCorticalAreaMonitoring

var membrane_toggle: CheckButton
var post_synaptic_toggle: CheckButton
var _cortical_reference: BaseCorticalArea

func _ready() -> void:
	membrane_toggle = $HBoxContainer/Membrane
	post_synaptic_toggle = $HBoxContainer2/PostSynaptic
	if !VisConfig.is_premium:
		membrane_toggle.disabled = true
		post_synaptic_toggle.disabled = true
	else:
		membrane_toggle.toggled.connect(_user_request_change_membrane_monitoring_status)
		post_synaptic_toggle.toggled.connect(_user_request_change_synaptic_monitoring_status)


func display_cortical_properties(cortical_reference: BaseCorticalArea) -> void:
	membrane_toggle.button_pressed = cortical_reference.is_monitoring_membrane_potential
	post_synaptic_toggle.button_pressed = cortical_reference.is_monitoring_synaptic_potential
	cortical_reference.changed_monitoring_membrane_potential.connect(_FEAGI_set_membrane_toggle)
	cortical_reference.changed_monitoring_synaptic_potential.connect(_FEAGI_set_synaptic_toggle)
	_cortical_reference = cortical_reference

func _FEAGI_set_membrane_toggle(state: bool) -> void:
	membrane_toggle.set_pressed_no_signal(state)

func _FEAGI_set_synaptic_toggle(state: bool) -> void:
	post_synaptic_toggle.set_pressed_no_signal(state)

func _user_request_change_membrane_monitoring_status(new_state:bool) -> void:
	FeagiRequests.request_change_membrane_monitoring_status(_cortical_reference, new_state)

func _user_request_change_synaptic_monitoring_status(new_state:bool) -> void:
	FeagiRequests.request_change_synaptic_monitoring_status(_cortical_reference, new_state)

