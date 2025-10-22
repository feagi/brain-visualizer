extends HBoxContainer
class_name SliderPercentage
## UI Element for a percentage based slider witha  slider UI element and a numerical representation

signal percentage_changed(percentage: float) ## Percentage 0.0-100.0 changed
signal value_changed(value: float) ## value 0.0-1.0 changed

@export var initial_label_text: StringName = ""
@export_range(0.0, 1.0) var initial_percentage: float = 0.0

var _label: Label
var _slider: HSlider
var _spinbox: SpinBox

## Percentage value from 0.0 - 100.0
var percentage: float:
	get: 
		if _slider:
			return _slider.value
		return 0.0
	set(v):
		if _slider:
			v = clampf(v, 0.0, 100.0)
			_set_slider_no_signal(v)
			_set_spinbox_no_signal(v)

## Value of percentage from 0.0 - 1.0
var value: float:
	get: 
		if _slider:
			return _slider.value / 100.0
		return 0.0
	set(v):
		if _slider:
			v = clampf(v, 0.0, 1.0)
			_set_slider_no_signal(v * 100.0)
			_set_spinbox_no_signal(v * 100.0)

var label_text: StringName:
	get: 
		if _label:
			return _label.text
		return &""
	set(v):
		if _label:
			_label.text = v

func _ready() -> void:
	_label = $Label
	_slider = $HSlider
	_spinbox = $SpinBox
	percentage = initial_percentage
	label_text = initial_label_text
	_slider.value_changed.connect(func(val: float): percentage_changed.emit(val))
	_slider.value_changed.connect(func(val: float): value_changed.emit(val / 100.0))

func _set_slider_no_signal(percentage: float) -> void:
	_slider.set_value_no_signal(percentage)

func _set_spinbox_no_signal(percentage: float) -> void:
	_spinbox.set_value_no_signal(percentage)
