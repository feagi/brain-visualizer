extends RefCounted
class_name CorticalPropertyMultiReferenceHandler

signal send_to_update_button(update_button: Button, key: StringName, value: Variant)

var _cortical_references: Array[AbstractCorticalArea]
var _control: Control
var _section_name: String # may be empty string if it is not in a subsection
var _variable_name: String
var _button_for_sending_to_FEAGI: Button
var _variable_key_for_FEAGI: StringName


func _init(cortical_references: Array[AbstractCorticalArea], control: Control, section_name: String, variable_name: String, variable_key_for_FEAGI: StringName, button_for_sending_to_FEAGI: Button):
	_cortical_references = cortical_references
	_control = control
	_section_name = section_name
	_variable_name = variable_name
	_button_for_sending_to_FEAGI = button_for_sending_to_FEAGI
	_variable_key_for_FEAGI = variable_key_for_FEAGI
	if _control is TextInput:
		(_control as TextInput).text_confirmed.connect(_proxy_emit)
		return
	if _control is IntInput:
		(_control as IntInput).int_confirmed.connect(_proxy_emit)
		return
	if _control is FloatInput:
		(_control as FloatInput).float_confirmed.connect(_proxy_emit)
		return
	if _control is ToggleButton:
		(_control as ToggleButton).toggled.connect(_proxy_emit)
		return


## To be called after cortical areas are updated in cache to avoid repetitve spam
func post_load_setup_and_connect_signals_from_FEAGI(signal_name: String):
	var section_object: RefCounted
	for area in _cortical_references:
		if _section_name != "":
			section_object = area.get(_section_name) # Assumption is that all cortical areas have the section
		else:
			section_object = area # to allow us to grab universal properties
		
		
		
		var signal_ref: Signal = section_object.get(signal_name)
		signal_ref.connect(refresh_values_from_cache_and_update_control)


func refresh_values_from_cache_and_update_control(_irrelevant1 = null, _irrelevant2 = null):
	var differences: int = -1 # first one will always fail
	var section_object: RefCounted
	var current_value: Variant = null
	var previous_value: Variant = null
	for area in _cortical_references:
		if _section_name != "":
			section_object = area.get(_section_name) # Assumption is that all cortical areas have the section
		else:
			section_object = area # to allow us to grab universal properties
		current_value = section_object.get(_variable_name)
		if previous_value != current_value:
			previous_value = current_value
			differences += 1
			if differences > 0:
				# Differences, assign invalid
				_set_control_as_conflicting_values()
				return
			continue
		continue
	# If we got here, values are identical
	if current_value != null:
		_set_control_to_value(current_value)

func _set_control_to_value(value: Variant) -> void:
	if _control is TextInput:
		(_control as TextInput).text = value
		return
	if _control is IntInput:
		(_control as IntInput).set_int(value)
		return
	if _control is FloatInput:
		(_control as FloatInput).set_float(value)
		return
	if _control is ToggleButton:
		(_control as ToggleButton).set_toggle_no_signal(value)
		return
	

func _set_control_as_conflicting_values() -> void:
	if _control is AbstractLineInput:
		(_control as AbstractLineInput).set_text_as_invalid()
		return
	if _control is ToggleButton:
		(_control as ToggleButton).is_inbetween = true
		return

func _proxy_emit(value: Variant) -> void:
	send_to_update_button.emit(_button_for_sending_to_FEAGI, _variable_key_for_FEAGI, value)
