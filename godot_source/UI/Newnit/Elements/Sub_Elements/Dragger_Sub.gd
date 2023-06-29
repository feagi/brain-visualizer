extends Node
class_name Dragger_Sub

# Dragger exists to handle dragging positional changes

signal value_edited(Vector2)

var _mouseOffset: Vector2

func _init(rootPosition: Vector2):
	super()
	_mouseOffset = get_viewport().get_mouse_position() - rootPosition


func _input(event):
	if event != InputEventMouseMotion: return
	value_edited.emit(get_viewport().get_mouse_position() + _mouseOffset)
