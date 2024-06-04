extends HBoxContainer
class_name ScrollSectionGenericItem
## A generic Scroll item that supports any control, and that has a delete button

signal deleted(self_ref: ScrollSectionGenericItem)

var lookup_key: Variant:
	get: return _lookup_key

var _lookup_key: Variant
var _delete_button: ButtonTextureRectScaling
var _control: Control
var _self_delete: bool

func setup(control: Control, key_to_lookup: Variant, enable_delete_button: bool = true, delete_button_deletes_item: bool = true) -> void:
	_delete_button = $Delete
	_control = control
	_lookup_key = key_to_lookup
	_self_delete = delete_button_deletes_item
	add_child(_control)
	move_child(_control, 0)
	if !enable_delete_button:
		_delete_button.queue_free()
	
func get_control() -> Control:
	return _control

func _delete_button_pressed() -> void:
	deleted.emit(self)
	if _self_delete:
		queue_free()
