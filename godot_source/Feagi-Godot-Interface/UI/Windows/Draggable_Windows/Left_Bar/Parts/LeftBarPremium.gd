extends VBoxContainer
class_name LeftBarPremium

var membrane_toggle: CheckButton
var post_synaptic_toggle: CheckButton

func _ready() -> void:
	membrane_toggle = $Membrane
	post_synaptic_toggle = $PostSynaptic
	if !VisConfig.is_premium:
		membrane_toggle.disabled = true
		post_synaptic_toggle.disabled = true


func initial_values_from_FEAGI(cortical_reference: CorticalArea) -> void:

	membrane_toggle.button_pressed = cortical_reference.is_monitoring_membrane_potential
	post_synaptic_toggle.button_pressed = cortical_reference.is_monitoring_synaptic_potential
	cortical_reference.changed_monitoring_membrane_potential.connect(_FEAGI_set_membrane_toggle)
	cortical_reference.changed_monitoring_synaptic_potential.connect(_FEAGI_set_synaptic_toggle)

func _FEAGI_set_membrane_toggle(state: bool) -> void:
	membrane_toggle.button_pressed = state

func _FEAGI_set_synaptic_toggle(state: bool) -> void:
	post_synaptic_toggle.button_pressed = state
