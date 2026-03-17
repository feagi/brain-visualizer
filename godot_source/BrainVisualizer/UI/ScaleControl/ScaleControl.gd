extends Control
class_name ScaleControl
## Independent UI scale control positioned at top-right corner

# Index into BV.UI.possible_UI_scales (expected ascending: 0.5, 0.75, 1.0, 1.25, 1.5, 2.0).
# Default: +1 level relative to 1.0x -> 1.25x.
var _index_scale: int = 3
var _increase_button: TextureButton
var _decrease_button: TextureButton

func _ready():
	# Get button references
	_increase_button = $Panel/VBoxContainer/IncreaseButton
	_decrease_button = $Panel/VBoxContainer/DecreaseButton
	
	_sync_index_with_loaded_theme()
	
	# Initialize button states
	_update_button_states()

func _increase_scale() -> void:
	_index_scale += 1
	_index_scale = mini(_index_scale, len(BV.UI.possible_UI_scales) - 1)
	_update_button_states()
	print("ScaleControl: Requesting scale change to " + str(BV.UI.possible_UI_scales[_index_scale]))
	BV.UI.request_switch_to_theme(BV.UI.possible_UI_scales[_index_scale], UIManager.THEME_COLORS.DARK)

func _decrease_scale() -> void:
	_index_scale -= 1
	_index_scale = maxi(_index_scale, 0)
	_update_button_states()
	print("ScaleControl: Requesting scale change to " + str(BV.UI.possible_UI_scales[_index_scale]))
	BV.UI.request_switch_to_theme(BV.UI.possible_UI_scales[_index_scale], UIManager.THEME_COLORS.DARK)

func _update_button_states() -> void:
	_increase_button.disabled = _index_scale == len(BV.UI.possible_UI_scales) - 1
	_decrease_button.disabled = _index_scale == 0

## Aligns button state with the startup theme selected by UIManager.
func _sync_index_with_loaded_theme() -> void:
	if BV.UI.possible_UI_scales.is_empty():
		return
	var current_scale: float = BV.UI.loaded_theme_scale.x
	for i in range(BV.UI.possible_UI_scales.size()):
		if abs(BV.UI.possible_UI_scales[i] - current_scale) < 0.0001:
			_index_scale = i
			return



