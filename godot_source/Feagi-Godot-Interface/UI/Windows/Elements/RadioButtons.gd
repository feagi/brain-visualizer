extends BoxContainer
class_name RadioButtons
# Holds a grouping of radio buttons. To fill, place CheckBox nodes as children

signal button_pressed(button_index: int, button_label: StringName)

@export var allow_deselecting: bool = false

var button_group: ButtonGroup

func _ready():
	button_group = ButtonGroup.new()
	var children: Array = get_children()
	for child in children:
		child.button_group = button_group
	button_group.allow_unpress = allow_deselecting
	button_group.pressed.connect(_emit_pressed)

func _emit_pressed(button: Button) -> void:
	button_pressed.emit(button.get_index(), button.text)
