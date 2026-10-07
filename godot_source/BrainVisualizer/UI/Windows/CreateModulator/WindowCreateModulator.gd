extends BaseDraggableWindow
class_name WindowCreateModulator

const WINDOW_NAME: StringName = "create_modulator"

const _TYPES: Array[String] = [
	"neuro.firing_threshold",
	"neuro.leak",
	"neuro.firing_probability",
	"synaptic.transmission_gain",
	"synaptic.reward",
	"synaptic.learning_rate",
]

var _type_list: OptionButton
var _instance_id: LineEdit
var _magnitude: LineEdit
var _duration: LineEdit
var _rest: LineEdit
var _graded: CheckBox
var _full_scale: LineEdit
var _status: Label
var _create_button: Button


func setup() -> void:
	_setup_base_window(WINDOW_NAME)
	_titlebar.title = "Add modulator"
	_build_form()


func _build_form() -> void:
	if _window_internals.get_node_or_null("InstanceId") != null:
		return
	_type_list = OptionButton.new()
	_type_list.name = "ModulatorType"
	for kind in _TYPES:
		_type_list.add_item(kind)
	_window_internals.add_child(_labeled_row("Type", _type_list))
	_instance_id = _line("InstanceId", "instance id")
	_window_internals.add_child(_labeled_row("Instance id", _instance_id))
	_magnitude = _line("Magnitude", "0")
	_window_internals.add_child(_labeled_row("Magnitude percent", _magnitude))
	_duration = _line("Duration", "1")
	_window_internals.add_child(_labeled_row("Effect duration (bursts)", _duration))
	_rest = _line("Rest", "0")
	_window_internals.add_child(_labeled_row("Rest (bursts)", _rest))
	_graded = CheckBox.new()
	_graded.text = "Graded"
	_graded.toggled.connect(_on_graded_toggled)
	_window_internals.add_child(_graded)
	_full_scale = _line("FullScale", "1")
	_full_scale.editable = false
	_window_internals.add_child(_labeled_row("Full scale potential", _full_scale))
	_status = Label.new()
	_status.name = "Status"
	_window_internals.add_child(_status)
	_create_button = Button.new()
	_create_button.text = "Create"
	_create_button.pressed.connect(_on_create)
	_window_internals.add_child(_create_button)


func _labeled_row(title: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(180, 0)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


func _line(node_name: String, text: String) -> LineEdit:
	var field := LineEdit.new()
	field.name = node_name
	field.text = text
	field.custom_minimum_size = Vector2(180, 0)
	return field


func _on_graded_toggled(enabled: bool) -> void:
	if _full_scale != null:
		_full_scale.editable = enabled


func _on_create() -> void:
	var instance_id := _instance_id.text.strip_edges()
	if instance_id.is_empty():
		_status.text = "Instance id is required"
		return
	var magnitude := float(_magnitude.text)
	if magnitude < -100.0:
		_status.text = "Magnitude percent must be >= -100"
		return
	var duration := int(_duration.text)
	if duration < 1:
		_status.text = "Effect duration must be at least 1 burst"
		return
	var body := {
		"type": _TYPES[_type_list.selected],
		"magnitude_percent": magnitude,
		"effect_duration_bursts": duration,
		"rest_bursts": maxi(0, int(_rest.text)),
		"graded": _graded.button_pressed,
	}
	if _graded.button_pressed:
		var scale := float(_full_scale.text)
		if scale <= 0.0:
			_status.text = "Graded modulators require full scale potential > 0"
			return
		body["full_scale_potential"] = scale
	_create_button.disabled = true
	_status.text = "Creating..."
	var created: FeagiRequestOutput = await FeagiCore.requests.create_modulator(instance_id, body)
	_create_button.disabled = false
	if created == null or created.has_errored:
		_status.text = "Create failed"
		if created != null:
			var detail := created.decode_response_as_string()
			if not detail.is_empty():
				_status.text = detail
		return
	await FeagiCore.feagi_local_cache.refresh_cortical_areas_from_feagi()
	close_window()
