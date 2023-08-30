extends VBoxContainer
class_name LeftBarPremium

var membrane_toggle: CheckButton
var post_synaptic_toggle: CheckButton

func _ready() -> void:
	membrane_toggle = $Membrane
	post_synaptic_toggle = $PostSynaptic
	if !VisConfig.left_bar_allow_premium_monitoring:
		membrane_toggle.disabled = true
		post_synaptic_toggle.disabled = true


func initial_values_from_FEAGI(is_membrane_monitoring: bool, is_postsynaptic_monitoring: bool) -> void:
	membrane_toggle.button_pressed = is_membrane_monitoring
	post_synaptic_toggle.button_pressed = is_postsynaptic_monitoring

