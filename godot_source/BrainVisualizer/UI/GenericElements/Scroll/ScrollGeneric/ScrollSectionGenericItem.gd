extends HBoxContainer
class_name ScrollSectionGenericItem
## A generic Scroll item that supports any control

var name_tag: StringName:
	get: return _name_tag

var _lookup_key: Variant
var _name_tag: StringName
var _control: Control

func setup(control: Control, key_to_lookup: Variant, name_tag: StringName) -> void:
	_control = control
	_lookup_key = key_to_lookup
	_name_tag = name_tag
	add_child(_control)
	move_child(_control, 0)

func get_lookup_key() -> Variant:
	return _lookup_key

## Get the control that was created here
func get_control() -> Control:
	return _control

## Returns the text button if it exists (otherwise returns null)
func get_text_button() -> Button:
	return _control.get_node("Text")

## Returns the delete button if it exists (otherwise returns null)
func get_delete_button() -> TextureButton:
	return _control.get_node("Delete")

## Returns the edit button if it exists (otherwise returns null)
func get_edit_button() -> TextureButton:
	return _control.get_node("Edit")

func set_highlighting(is_highlighted: bool) -> void:
	if (_control as Variant).has_method("set_highlighting"):
		(_control as Variant).set_highlighting(is_highlighted)
		return
	push_warning("UI: Included control has no 'is_highlighting' function! Skipping setting highlight state!")

