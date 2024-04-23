extends VBoxContainer
class_name CorticalPropertiesCorticalAreaMonitoring

var membrane_toggle: ToggleButton
var post_synaptic_toggle: ToggleButton
var _cortical_reference: BaseCorticalArea

func _ready() -> void:
	membrane_toggle = $HBoxContainer/Membrane
	post_synaptic_toggle = $HBoxContainer2/PostSynaptic
	if !FeagiCore.feagi_local_cache.influxdb_availability:
		membrane_toggle.disabled = true
		post_synaptic_toggle.disabled = true
		membrane_toggle.tooltip_text = "Feature is unavailable"
		post_synaptic_toggle.tooltip_text = "Feature is unavailable"
		


func display_cortical_properties(cortical_reference: BaseCorticalArea) -> void:
	membrane_toggle.set_toggle_no_signal(cortical_reference.is_monitoring_membrane_potential)
	post_synaptic_toggle.set_toggle_no_signal(cortical_reference.is_monitoring_synaptic_potential)
	cortical_reference.changed_monitoring_membrane_potential.connect(_FEAGI_set_membrane_toggle)
	cortical_reference.changed_monitoring_synaptic_potential.connect(_FEAGI_set_synaptic_toggle)
	_cortical_reference = cortical_reference

func _FEAGI_set_membrane_toggle(state: bool) -> void:
	membrane_toggle.set_toggle_no_signal(state)

func _FEAGI_set_synaptic_toggle(state: bool) -> void:
	post_synaptic_toggle.set_toggle_no_signal(state)

func _user_request_change_membrane_monitoring_status(new_state:bool) -> void:
	pass
	FeagiCore.requests.toggle_membrane_monitoring(_cortical_reference.cortical_ID, new_state)

func _user_request_change_synaptic_monitoring_status(new_state:bool) -> void:
	pass
	FeagiCore.requests.toggle_synaptic_monitoring(_cortical_reference.cortical_ID, new_state)

