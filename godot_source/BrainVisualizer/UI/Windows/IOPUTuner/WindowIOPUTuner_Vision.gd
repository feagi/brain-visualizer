extends VBoxContainer
class_name WindowIOPUTuner_Vision

var _central_vision_res: Vector2iField
var _peripheral_vision_res: Vector2iField
var _flicker_period: IntInput
var _color_option_color: CheckBox
var _color_option_gray: CheckBox
var _eccentricity_x: HSlider
var _eccentricity_y: HSlider
var _modulation_x: HSlider
var _modulation_y: HSlider
var _brightness: HSlider
var _contrast: HSlider
var _shadows: HSlider
var _pixel_change: HSlider

var _button_group: ButtonGroup

func _ready() -> void:
	_central_vision_res = $General/VerticalCollapsible/PanelContainer/PutThingsHere/VBoxContainer/HBoxContainer/Vector2iField
	_peripheral_vision_res = $General/VerticalCollapsible/PanelContainer/PutThingsHere/VBoxContainer/HBoxContainer2/Vector2iField2
	_flicker_period = $General/VerticalCollapsible/PanelContainer/PutThingsHere/VBoxContainer/HBoxContainer3/flicker
	_color_option_color = $General/VerticalCollapsible/PanelContainer/PutThingsHere/VBoxContainer/HBoxContainer4/Color
	_color_option_gray = $General/VerticalCollapsible/PanelContainer/PutThingsHere/VBoxContainer/HBoxContainer4/Grayscale
	_eccentricity_x = $Adjustments/VerticalCollapsible/PanelContainer/PutThingsHere/VBoxContainer/HBoxContainer4/HSlider
	_eccentricity_y = $Adjustments/VerticalCollapsible/PanelContainer/PutThingsHere/VBoxContainer/HBoxContainer5/HSlider
	_modulation_x = $Adjustments/VerticalCollapsible/PanelContainer/PutThingsHere/VBoxContainer/HBoxContainer6/HSlider
	_modulation_y = $Adjustments/VerticalCollapsible/PanelContainer/PutThingsHere/VBoxContainer/HBoxContainer7/HSlider
	_brightness = $Enhancements/VerticalCollapsible/PanelContainer/PutThingsHere/VBoxContainer/HBoxContainer4/HSlider
	_contrast = $Enhancements/VerticalCollapsible/PanelContainer/PutThingsHere/VBoxContainer/HBoxContainer5
	_shadows = $Enhancements/VerticalCollapsible/PanelContainer/PutThingsHere/VBoxContainer/HBoxContainer6/HSlider
	_pixel_change = $Thresholds/VerticalCollapsible/PanelContainer/PutThingsHere/VBoxContainer/HBoxContainer4/HSlider
	
	_button_group = ButtonGroup.new()
	_color_option_color.button_group = _button_group
	_color_option_gray.button_group = _button_group

## Given a formatted dictionary from feagi related to vision tuning parameters, 
func load_from_FEAGI(vision_details_preprocessed: Dictionary) -> void:
	if vision_details_preprocessed.has("central_vision_resolution"):
		if vision_details_preprocessed["central_vision_resolution"] is Vector2i:
			_central_vision_res.current_vector = vision_details_preprocessed["central_vision_resolution"]
		else:
			push_error("WindowIOPUTuner_Vision: central_vision_resolution is not a Vector2i! Was this not preprocessed?")
			_central_vision_res.editable = false
	else:
		push_error("WindowIOPUTuner_Vision: Missing central_vision_resolution!")
		_central_vision_res.editable = false
	
	if vision_details_preprocessed.has("peripheral_vision_resolution"):
		if vision_details_preprocessed["peripheral_vision_resolution"] is Vector2i:
			_peripheral_vision_res.current_vector = vision_details_preprocessed["peripheral_vision_resolution"]
		else:
			push_error("WindowIOPUTuner_Vision: peripheral_vision_resolution is not a Vector2i! Was this not preprocessed?")
			_peripheral_vision_res.editable = false
	else:
		push_error("WindowIOPUTuner_Vision: Missing peripheral_vision_resolution!")
		_peripheral_vision_res.editable = false
	
	if vision_details_preprocessed.has("flicker_period"):
		_flicker_period.current_int = vision_details_preprocessed["flicker_period"]
	else:
		_flicker_period.editable = false
	
	if vision_details_preprocessed.has("color_vision"):
		if vision_details_preprocessed["color_vision"]:
			_color_option_color.button_pressed = true
		else:
			_color_option_gray.button_pressed = true
	else:
		_color_option_color.disabled = true
		_color_option_gray.disabled = true
	
	if vision_details_preprocessed.has("eccentricity"):
		if vision_details_preprocessed["eccentricity"] is Vector2:
			_eccentricity_x.value = vision_details_preprocessed["eccentricity"].x
			_eccentricity_y.value = vision_details_preprocessed["eccentricity"].y
		else:
			push_error("WindowIOPUTuner_Vision: eccentricity is not a Vector2! Was this not preprocessed?")
			_eccentricity_x.editable = false
			_eccentricity_y.editable = false
	else:
		push_error("WindowIOPUTuner_Vision: Missing eccentricity!")
		_eccentricity_x.editable = false
		_eccentricity_y.editable = false
	
	if vision_details_preprocessed.has("modulation"):
		if vision_details_preprocessed["modulation"] is Vector2:
			_modulation_x.value = vision_details_preprocessed["modulation"].x
			_modulation_y.value = vision_details_preprocessed["modulation"].y
		else:
			push_error("WindowIOPUTuner_Vision: modulation is not a Vector2! Was this not preprocessed?")
			_modulation_x.editable = false
			_modulation_y.editable = false
	else:
		push_error("WindowIOPUTuner_Vision: Missing modulation!")
		_modulation_x.editable = false
		_modulation_y.editable = false
	
	if vision_details_preprocessed.has("brightness"):
		_brightness.value = vision_details_preprocessed["brightness"]
	else:
		push_error("WindowIOPUTuner_Vision: Missing brightness!")
		_brightness.editable = false

	if vision_details_preprocessed.has("contrast"):
		_contrast.value = vision_details_preprocessed["contrast"]
	else:
		push_error("WindowIOPUTuner_Vision: Missing contrast!")
		_contrast.editable = false

	if vision_details_preprocessed.has("shadows"):
		_shadows.value = vision_details_preprocessed["shadows"]
	else:
		push_error("WindowIOPUTuner_Vision: Missing shadows!")
		_shadows.editable = false

	if vision_details_preprocessed.has("pixel_change_limit"):
		_pixel_change.value = vision_details_preprocessed["pixel_change_limit"]
	else:
		push_error("WindowIOPUTuner_Vision: Missing pixel_change_limit!")
		_pixel_change.editable = false

## Returns a dictionary to send to FEAGI for vision turning, already formatted properly
func export_for_FEAGI() -> Dictionary:
	return {
		"central_vision_resolution": [_central_vision_res.current_vector.x, _central_vision_res.current_vector.y],
		"peripheral_vision_resolution": [_peripheral_vision_res.current_vector.x, _peripheral_vision_res.current_vector.y],
		"flicker_period": _flicker_period.current_int,
		"color_vision": _color_option_color.button_pressed,
		"eccentricity": [_eccentricity_x.value, _eccentricity_y.value],
		"modulation": [_modulation_x.value, _modulation_y.value],
		"brightness": _brightness.value,
		"contrast": _contrast.value,
		"shadows": _shadows.value,
		"pixel_change_limit": _pixel_change.value,
	}
