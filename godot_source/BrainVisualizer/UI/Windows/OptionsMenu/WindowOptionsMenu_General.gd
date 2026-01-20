extends VBoxContainer
class_name WindowOptionsMenu_General

var _version: LineEdit
var _interface_dropdown: OptionButton
var _advanced_mode: ToggleButton
var _autoconfigure_IO: ToggleButton


func _ready() -> void:
	_version = $VBoxContainer/Version
	_interface_dropdown = $VBoxContainer2/OptionButton
	_advanced_mode = $VBoxContainer3/ToggleButton
	_autoconfigure_IO = $VBoxContainer4/ToggleButton
	
	_advanced_mode.set_toggle_no_signal(BV.UI.is_in_advanced_mode)
	# Keep the UI magnification dropdown in sync with the global UI scale controls (top-right +/-).
	if not BV.UI.theme_changed.is_connected(_on_theme_changed):
		BV.UI.theme_changed.connect(_on_theme_changed)
	_interface_dropdown.selected = _get_theme_index()
	_version.text = Time.get_datetime_string_from_unix_time(BVVersion.brain_visualizer_timestamp)

func _on_theme_changed(_new_theme: Theme) -> void:
	# Update dropdown selection to reflect the latest chosen UI magnification.
	if _interface_dropdown == null:
		return
	_interface_dropdown.selected = _get_theme_index()

## Attempts to set BV settings as described in UI
func apply_settings() -> void:
	if _interface_dropdown.get_selected_id() != -1:
		var option_string: String = _interface_dropdown.get_item_text(_interface_dropdown.get_selected_id())
		var split_strings: PackedStringArray = option_string.split(" ")
		var color_setting: UIManager.THEME_COLORS
		if split_strings[1] == "Dark":
			color_setting = UIManager.THEME_COLORS.DARK
		var zoom_value: float = split_strings[0].to_float()
		BV.UI.request_switch_to_theme(zoom_value, color_setting)
	BV.UI.set_advanced_mode(_advanced_mode.button_pressed)


# This is really stupid, but temporary
func _get_theme_index() -> int:
	var search: Dictionary = {
		0.5: 0,
		0.75: 1,
		1.0: 2,
		1.25: 3,
		1.5: 4,
		2.0: 5,
	}
	#var color_mode: String = "Dark" # TODO no alternatives
	var sizing_string: float = BV.UI.loaded_theme_scale.x
	return search[sizing_string]
