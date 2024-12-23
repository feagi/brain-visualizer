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
	_contrast = $Enhancements/VerticalCollapsible/PanelContainer/PutThingsHere/VBoxContainer/HBoxContainer5/HSlider
	_shadows = $Enhancements/VerticalCollapsible/PanelContainer/PutThingsHere/VBoxContainer/HBoxContainer6/HSlider
	_pixel_change = $Thresholds/VerticalCollapsible/PanelContainer/PutThingsHere/VBoxContainer/HBoxContainer4/HSlider
	
	_button_group = ButtonGroup.new()
	_color_option_color.button_group = _button_group
	_color_option_gray.button_group = _button_group

## Given a formatted dictionary from feagi related to vision tuning parameters, 
func load_from_FEAGI(vision_details: Dictionary) -> void:
	
	# first remove all null values
	var keys: Array = vision_details.keys()
	for key in keys:
		if vision_details[key] == null:
			vision_details.erase(key)
		elif vision_details[key] is Array:
			if len(vision_details[key]) == 0:
				vision_details.erase(key)
			elif vision_details[key][0] == null:
				vision_details.erase(key)
	
	if vision_details.has("central_vision_resolution"):
		_central_vision_res.current_vector = Vector2i(vision_details["central_vision_resolution"][0], vision_details["central_vision_resolution"][1])
	
	if vision_details.has("peripheral_vision_resolution"):
		_peripheral_vision_res.current_vector = Vector2i(vision_details["peripheral_vision_resolution"][0], vision_details["peripheral_vision_resolution"][1])
	
	if vision_details.has("flicker_period"):
		_flicker_period.current_int = vision_details["flicker_period"]
	
	if vision_details.has("color_vision"):
		if vision_details["color_vision"]:
			_color_option_color.button_pressed = true
		else:
			_color_option_gray.button_pressed = true
	
	if vision_details.has("eccentricity"):
		_eccentricity_x.value = vision_details["eccentricity"][0]
		_eccentricity_y.value = vision_details["eccentricity"][0]
	
	if vision_details.has("modulation"):
		_modulation_x.value = vision_details["modulation"][0]
		_modulation_y.value = vision_details["modulation"][0]
	
	if vision_details.has("brightness"):
		_brightness.value = vision_details["brightness"]

	if vision_details.has("contrast"):
		_contrast.value = vision_details["contrast"]

	if vision_details.has("shadows"):
		_shadows.value = vision_details["shadows"]

	if vision_details.has("pixel_change_limit"):
		_pixel_change.value = vision_details["pixel_change_limit"]

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
