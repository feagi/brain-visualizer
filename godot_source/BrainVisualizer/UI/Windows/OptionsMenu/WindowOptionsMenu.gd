extends BaseDraggableWindow
class_name WindowOptionsMenu

const WINDOW_NAME: StringName = "options_menu"

var _version: LineEdit
var _interface_dropdown: OptionButton
var _advanced_mode: ToggleButton
var _autoconfigure_IO: ToggleButton

func _ready() -> void:
	_version = _window_internals.get_node('VBoxContainer/Version')
	_interface_dropdown = _window_internals.get_node('VBoxContainer2/OptionButton')
	_advanced_mode = _window_internals.get_node('VBoxContainer3/ToggleButton')
	_autoconfigure_IO = _window_internals.get_node('VBoxContainer4/ToggleButton')
	super()
	
func setup() -> void:
	_setup_base_window(WINDOW_NAME)
	_advanced_mode.set_toggle_no_signal(BV.UI.is_in_advanced_mode)
	_interface_dropdown.selected = _get_theme_index()

func _on_accept_press() -> void:
	if _interface_dropdown.get_selected_id() != -1:
		var option_string: String = _interface_dropdown.get_item_text(_interface_dropdown.get_selected_id())
		var split_strings: PackedStringArray = option_string.split(" ")
		var color_setting: UIManager.THEME_COLORS
		if split_strings[0] == "Dark":
			color_setting = UIManager.THEME_COLORS.DARK
		var zoom_value: float = split_strings[1].to_float()
		BV.UI.request_switch_to_theme(zoom_value, color_setting)
	BV.UI.set_advanced_mode(_advanced_mode.button_pressed)
	
	close_window()

# THis is really stupid, but temporary
func _get_theme_index() -> int:
	var search: Dictionary = {
		"0.5": 0,
		"0.75": 1,
		"1.0": 2,
		"1.25": 3,
		"1.5": 4,
		"2.0": 5,
	}
	#var color_mode: String = "Dark" # TODO no alternatives
	var sizing_string: String = str(BV.UI.loaded_theme_scale.x)
	return search[sizing_string]
	
