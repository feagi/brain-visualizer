extends BaseDraggableWindow
class_name WindowOptionsMenu

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

func _on_accept_press() -> void:
	pass
