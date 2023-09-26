extends BoxContainer
class_name RadioButtons
## Holds a grouping of radio buttons. To fill, place CheckBox nodes as children

signal button_pressed(button_index: int, button_label: StringName)

@export var allow_deselecting: bool = false

var currently_selected_index: int:
	get: return _get_pressed_button()

var currently_selected_text: StringName:
	get: return _get_pressed_button_name()



var button_group: ButtonGroup

func _ready():
	button_group = ButtonGroup.new()
	var children: Array = get_children()
	for child in children:
		if child.get_class() == "CheckBox" or child.get_class() == "Button" or child.get_class() == "CheckButton":
			# Just to filter non-button based out.
			child.button_group = button_group
	button_group.allow_unpress = allow_deselecting
	button_group.pressed.connect(_emit_pressed)

func _emit_pressed(button: Button) -> void:
	button_pressed.emit(button.get_index(), button.text)

## Gets indexed of pressed button. Returns -1 if none are pressed
func _get_pressed_button() -> int:
	for child_index in get_child_count():
		if get_child(child_index).button_pressed:
			return child_index
	return -1

func _get_pressed_button_name() -> StringName:
	var pressed_index: int = _get_pressed_button()
	if pressed_index == -1:
		return ""
	return get_child(pressed_index).text