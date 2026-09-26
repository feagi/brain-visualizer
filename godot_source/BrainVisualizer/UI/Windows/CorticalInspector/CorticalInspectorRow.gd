extends VBoxContainer
class_name CorticalInspectorRow
## One cortical tunable: optional min/max boxes, a slider, and a spin box for fine steps.
## Min and max only change the slider scale. They do not write FEAGI.

signal live_value_changed(row_id: StringName, value: float, from_drag: bool)
signal bool_changed(row_id: StringName, pressed: bool)
signal drag_started(row_id: StringName)
signal drag_ended(row_id: StringName)

var _spec: Dictionary = {}
var _lo: float = 0.0
var _hi: float = 1.0
var _live: float = 0.0
var _pointer_drag: bool = false
var _syncing: bool = false

var _label: Label
var _min_field: FloatInput
var _max_field: FloatInput
var _slider: HSlider
var _spin: SpinBox
var _toggle: ToggleButton


## Build the row from a [method CorticalInspectorModel.parameter_specs] entry.
func setup(spec: Dictionary) -> void:
	_spec = spec
	_lo = float(spec["default_min"])
	_hi = float(spec["default_max"])
	_live = _lo
	add_theme_constant_override("separation", 4)
	if str(spec["kind"]) == "bool":
		_build_bool_row()
		return
	_label = Label.new()
	_label.text = str(spec["label"])
	_label.tooltip_text = str(spec["tooltip"])
	add_child(_label)
	_build_slider_row()


## Place the thumb on [param value]. When [param widen] is true, expand min or max so the value fits.
func set_live(value: float, widen: bool) -> void:
	if widen:
		var span := CorticalInspectorModel.span_including_value(_lo, _hi, value)
		_lo = span.x
		_hi = span.y
	_live = value
	_sync_controls()


func live_value() -> float:
	return _live


func set_bool(pressed: bool) -> void:
	if _toggle == null:
		return
	_toggle.set_toggle_no_signal(pressed)


func is_on() -> bool:
	if _toggle == null:
		return false
	return _toggle.button_pressed


## Lock the value slider, number, or toggle. Min and max stay editable.
func set_value_editable(enabled: bool) -> void:
	var tint := Color.WHITE if enabled else Color(0.62, 0.62, 0.62, 1.0)
	if _slider != null:
		_slider.editable = enabled
		_slider.modulate = tint
	if _spin != null:
		_spin.editable = enabled
		_spin.modulate = tint
	if _toggle != null:
		_toggle.disabled = not enabled


func _build_bool_row() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	_label = Label.new()
	_label.text = str(_spec["label"])
	_label.tooltip_text = str(_spec["tooltip"])
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_label)
	_toggle = ToggleButton.new()
	# The source art is 486x256. Ignore that and use the theme ToggleButton size.
	_toggle.enable_autoscaling_with_theme = false
	_toggle.ignore_texture_size = true
	_toggle.stretch_mode = TextureButton.STRETCH_SCALE
	_toggle.theme_type_variation = &"ToggleButton"
	_toggle.size_flags_horizontal = Control.SIZE_SHRINK_END
	_toggle.tooltip_text = str(_spec["tooltip"])
	row.add_child(_toggle)
	_apply_toggle_theme_size()
	if BV != null and BV.UI != null and not BV.UI.theme_changed.is_connected(_apply_toggle_theme_size):
		BV.UI.theme_changed.connect(_apply_toggle_theme_size)
	_toggle.toggled.connect(_on_toggled)


## Theme ToggleButton size_x/size_y already includes the UI scale.
func _apply_toggle_theme_size(_theme: Theme = null) -> void:
	if _toggle == null:
		return
	var theme_size := Vector2i(64, 32)
	if BV != null and BV.UI != null:
		var loaded: Vector2i = BV.UI.get_minimum_size_from_loaded_theme(&"ToggleButton")
		if loaded.x > 0 and loaded.y > 0:
			theme_size = loaded
	_toggle.custom_minimum_size = theme_size


func _exit_tree() -> void:
	if _toggle != null and BV != null and BV.UI != null and BV.UI.theme_changed.is_connected(_apply_toggle_theme_size):
		BV.UI.theme_changed.disconnect(_apply_toggle_theme_size)


func _build_slider_row() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	if bool(_spec["editable_bounds"]):
		_min_field = _make_number_field(0)
		row.add_child(_min_field)
		_min_field.float_confirmed.connect(_on_min_confirmed)
	_slider = HSlider.new()
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.custom_minimum_size = Vector2(140, 24)
	_slider.step = float(_spec["step"])
	if str(_spec["kind"]) == "int" or str(_spec["kind"]) == "percent":
		_slider.rounded = true
	_slider.tooltip_text = str(_spec["tooltip"])
	row.add_child(_slider)
	_slider.value_changed.connect(_on_slider_value)
	_slider.drag_started.connect(_on_drag_started)
	_slider.drag_ended.connect(_on_drag_ended)
	if bool(_spec["editable_bounds"]):
		_max_field = _make_number_field(0)
		row.add_child(_max_field)
		_max_field.float_confirmed.connect(_on_max_confirmed)
	_spin = SpinBox.new()
	_spin.custom_minimum_size = Vector2(120, 0)
	_spin.size_flags_horizontal = Control.SIZE_SHRINK_END
	_spin.step = _micro_step()
	_spin.rounded = str(_spec["kind"]) == "int" or str(_spec["kind"]) == "percent"
	_spin.tooltip_text = str(_spec["tooltip"])
	_spin.update_on_text_changed = false
	row.add_child(_spin)
	_spin.value_changed.connect(_on_spin_value)
	_sync_controls()


func _make_number_field(decimals: int) -> FloatInput:
	var field := FloatInput.new()
	field.custom_minimum_size = Vector2(72, 0)
	field.number_decimal_places = decimals
	field.min_value = -9999999999.0
	field.max_value = 9999999999.0
	field.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return field


func _sync_controls() -> void:
	_syncing = true
	if _min_field != null:
		_min_field.current_float = _lo
	if _max_field != null:
		_max_field.current_float = _hi
	var hi := _hi
	if hi < _lo:
		hi = _lo
	if _slider != null:
		_slider.min_value = _lo
		_slider.max_value = hi
		_slider.set_value_no_signal(clampf(_live, _lo, hi))
	if _spin != null:
		_spin.min_value = _lo
		_spin.max_value = hi
		_spin.set_value_no_signal(clampf(_live, _lo, hi))
	_syncing = false


func _on_slider_value(value: float) -> void:
	if _syncing:
		return
	_live = value
	_syncing = true
	if _spin != null:
		_spin.set_value_no_signal(_live)
	_syncing = false
	var pointer_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	live_value_changed.emit(StringName(str(_spec["id"])), _live, pointer_down or _pointer_drag)


func _on_spin_value(value: float) -> void:
	if _syncing:
		return
	_live = value
	_syncing = true
	if _slider != null:
		_slider.set_value_no_signal(clampf(_live, _lo, _hi))
	_syncing = false
	live_value_changed.emit(StringName(str(_spec["id"])), _live, false)


## Arrow step is finer than the slider for fractional tunables, and 1 for integers.
func _micro_step() -> float:
	var kind := str(_spec["kind"])
	if kind == "int" or kind == "percent":
		return 1.0
	return float(_spec["step"]) / 10.0


func _on_min_confirmed(value: float) -> void:
	if _syncing:
		return
	var span := CorticalInspectorModel.edit_bound(_lo, _hi, _live, true, value)
	_lo = span.x
	_hi = span.y
	_sync_controls()


func _on_max_confirmed(value: float) -> void:
	if _syncing:
		return
	var span := CorticalInspectorModel.edit_bound(_lo, _hi, _live, false, value)
	_lo = span.x
	_hi = span.y
	_sync_controls()


func _on_drag_started() -> void:
	_pointer_drag = true
	drag_started.emit(StringName(str(_spec["id"])))


func _on_drag_ended(_value_changed: bool) -> void:
	_pointer_drag = false
	drag_ended.emit(StringName(str(_spec["id"])))


func _on_toggled(pressed: bool) -> void:
	bool_changed.emit(StringName(str(_spec["id"])), pressed)
