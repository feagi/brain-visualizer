extends HBoxContainer
class_name ScrollSectionGenericItem
## A generic Scroll item that supports any control, and that has a delete button

signal deleted(self_ref: ScrollSectionGenericItem)

var _delete_button: ButtonTextureRectScaling
var _control: Control
var _self_delete: bool

# Called when the node enters the scene tree for the first time.
func _ready():
	_delete_button = $Delete

func setup(control: Control, enable_delete_button: bool = true, delete_button_deletes_item: bool = true) -> void:
	_control = control
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
