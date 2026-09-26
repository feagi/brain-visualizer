extends SceneTree
## Dirty-signal contract for Cortical Area Details Apply buttons.
## Typing must mark dirty immediately; cache/programmatic writes must not.
## Run: godot --headless -s res://BrainVisualizer/UI/GenericElements/test_apply_dirty_signals.gd


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var failures: int = 0
	failures += _test_int_input_typing_emits_user_interacted()
	failures += _test_int_input_programmatic_set_does_not_emit()
	failures += _test_int_input_suffix_focus_does_not_emit()
	failures += _test_int_spinbox_typing_emits_user_interacted()
	failures += _test_int_spinbox_set_value_no_signal_does_not_emit()
	failures += _test_vector3i_spinbox_typing_emits_user_interacted()
	failures += _test_user_interacted_enables_apply_button()
	failures += _test_io_preset_pick_dirties_apply()
	failures += _test_io_preset_apply_button_leaves_disabled_draw_mode()
	if failures == 0:
		print("Apply dirty signal tests: PASS")
		quit(0)
	else:
		push_error("Apply dirty signal tests: FAIL (%d)" % failures)
		quit(1)


func _simulate_line_edit_typing(line: LineEdit, typed: String) -> void:
	# Headless Godot does not deliver GUI key events; emit the same signal typing produces.
	line.text_changed.emit(typed)


func _test_int_input_typing_emits_user_interacted() -> int:
	var field := IntInput.new()
	root.add_child(field)
	var emitted: Array = [false]
	field.user_interacted.connect(func(): emitted[0] = true)
	_simulate_line_edit_typing(field, "12")
	var failed: int = 0 if emitted[0] else 1
	if failed == 1:
		push_error("IntInput typing must emit user_interacted")
	field.queue_free()
	return failed


func _test_int_input_programmatic_set_does_not_emit() -> int:
	var field := IntInput.new()
	root.add_child(field)
	var emitted: Array = [false]
	field.user_interacted.connect(func(): emitted[0] = true)
	field.set_int(7)
	var failed: int = 0 if not emitted[0] else 1
	if failed == 1:
		push_error("IntInput.set_int must not emit user_interacted")
	field.queue_free()
	return failed


func _test_int_input_suffix_focus_does_not_emit() -> int:
	var field := IntInput.new()
	field.suffix = " %"
	root.add_child(field)
	field.set_int(50)
	var emitted: Array = [false]
	field.user_interacted.connect(func(): emitted[0] = true)
	field.grab_focus()
	var failed: int = 0 if not emitted[0] else 1
	if failed == 1:
		push_error("Focusing a suffixed IntInput must not emit user_interacted")
	field.queue_free()
	return failed


func _test_int_spinbox_typing_emits_user_interacted() -> int:
	var spin := IntSpinBox.new()
	root.add_child(spin)
	var emitted: Array = [false]
	spin.user_interacted.connect(func(): emitted[0] = true)
	var line: LineEdit = spin.get_line_edit()
	if line == null:
		push_error("IntSpinBox must expose a LineEdit")
		spin.queue_free()
		return 1
	_simulate_line_edit_typing(line, "9")
	var failed: int = 0 if emitted[0] else 1
	if failed == 1:
		push_error("IntSpinBox LineEdit typing must emit user_interacted")
	spin.queue_free()
	return failed


func _test_int_spinbox_set_value_no_signal_does_not_emit() -> int:
	var spin := IntSpinBox.new()
	root.add_child(spin)
	var emitted: Array = [false]
	spin.user_interacted.connect(func(): emitted[0] = true)
	spin.set_value_no_signal(4)
	var failed: int = 0 if not emitted[0] else 1
	if failed == 1:
		push_error("IntSpinBox.set_value_no_signal must not emit user_interacted")
	spin.queue_free()
	return failed


func _test_vector3i_spinbox_typing_emits_user_interacted() -> int:
	var packed: PackedScene = load("res://BrainVisualizer/UI/GenericElements/Vectors/Vector3iSpinBoxField.tscn")
	if packed == null:
		push_error("Vector3iSpinBoxField.tscn failed to load")
		return 1
	var field: Vector3iSpinboxField = packed.instantiate()
	root.add_child(field)
	var emitted: Array = [false]
	field.user_interacted.connect(func(): emitted[0] = true)
	var x_spin: SpinBox = field.get_node("HBoxContainer/IntX")
	if x_spin == null:
		push_error("Vector3iSpinboxField missing IntX")
		field.queue_free()
		return 1
	var line: LineEdit = x_spin.get_line_edit()
	_simulate_line_edit_typing(line, "11")
	var failed: int = 0 if emitted[0] else 1
	if failed == 1:
		push_error("Vector3iSpinboxField typing must emit user_interacted")
	field.queue_free()
	return failed


func _test_user_interacted_enables_apply_button() -> int:
	var spin := IntSpinBox.new()
	var apply := Button.new()
	apply.disabled = true
	root.add_child(spin)
	root.add_child(apply)
	if spin.has_signal("user_interacted"):
		spin.user_interacted.connect(func(): apply.disabled = false)
	var line: LineEdit = spin.get_line_edit()
	_simulate_line_edit_typing(line, "3")
	var failed: int = 0 if not apply.disabled else 1
	if failed == 1:
		push_error("user_interacted must enable the section Apply button")
	spin.queue_free()
	apply.queue_free()
	return failed


func _load_cortical_properties_script() -> Variant:
	# Load after autoloads exist. A class_name reference compiles the window before BV is registered.
	return load("res://BrainVisualizer/UI/Windows/AdvancedCorticalProperties/AdvancedCorticalProperties.gd")


func _test_io_preset_pick_dirties_apply() -> int:
	var properties_script: Variant = _load_cortical_properties_script()
	if properties_script == null:
		push_error("AdvancedCorticalProperties.gd failed to compile")
		return 1
	var dirty_changed: bool = properties_script.call("io_preset_pick_dirties_apply", &"Interconnect", &"Input", false)
	var clean_same: bool = properties_script.call("io_preset_pick_dirties_apply", &"Input", &"Input", false)
	var clean_locked: bool = properties_script.call("io_preset_pick_dirties_apply", &"Interconnect", &"Output", true)
	var clean_conflict: bool = properties_script.call("io_preset_pick_dirties_apply", &"Interconnect", &"Conflict", false)
	if dirty_changed and not clean_same and not clean_locked and not clean_conflict:
		return 0
	push_error("IO preset pick must dirty Apply only when the unlocked role actually changes")
	return 1


func _test_io_preset_apply_button_leaves_disabled_draw_mode() -> int:
	var properties_script: Variant = _load_cortical_properties_script()
	if properties_script == null:
		push_error("AdvancedCorticalProperties.gd failed to compile")
		return 1
	var apply := Button.new()
	apply.disabled = true
	root.add_child(apply)
	properties_script.call("set_apply_button_enabled", apply, true)
	var failed: int = 0
	if apply.disabled or apply.get_draw_mode() == BaseButton.DRAW_DISABLED:
		push_error("IO preset change must leave Summary Apply enabled and out of the disabled draw mode")
		failed = 1
	apply.queue_free()
	return failed
