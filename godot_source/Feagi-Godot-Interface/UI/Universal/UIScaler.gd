extends Object
class_name UIScaler

var reset_control_size_after_resize: bool = true

var _control: Control
var _control_default_size: Vector2i
var _label: Label
var _label_default_font_size: int
var _button: BaseButton
var _button_default_font_size: int

func _init() -> void:
	VisConfig.UI_manager.UI_scale_changed.connect(_UI_scale_changed)

func define_control_size(control: Control, use_custom_minimum_size = false) -> void:
	_control = control
	if use_custom_minimum_size:
		_control_default_size = _control.custom_minimum_size
	else:
		_control_default_size = _control.size

func define_label_font_size(label: Label, default_font_size: int) -> void:
	_label = label
	_label_default_font_size = default_font_size

func define_button_font_size(button: BaseButton, default_button_font_size: int) -> void:
	_button = button
	_button_default_font_size = default_button_font_size

func _UI_scale_changed(multiplier: float) -> void:
	if _control != null:
		_update_control_size(_control, _control_default_size, multiplier, reset_control_size_after_resize)
	if _label != null:
		_update_label_font(_label, _label_default_font_size, multiplier)
	if _button != null:
		_update_button_font(_button, _button_default_font_size, multiplier)

func _update_control_size(control: Control, default_size: Vector2i, scale: float, reset_size_to_min: bool) -> void:
	control.custom_minimum_size = default_size * scale
	if reset_size_to_min:
		control.size = Vector2i(0,0)

func _update_label_font(label: Label, default_size: int, scale: float) -> void:
	label.add_theme_font_size_override("font_size", default_size * scale)

func _update_button_font(button: BaseButton, default_size: int, scale: float) -> void:
	button.add_theme_font_size_override("font_size", default_size * scale)

