extends Node
class_name Dragger_Sub

# Dragger exists to handle dragging positional changes

signal value_edited(Vector2)

var _mouseOffset: Vector2

func _init(rootPosition: Vector2):
	super()
	_mouseOffset = rootPosition

func _ready():
	_mouseOffset = get_viewport().get_mouse_position() - _mouseOffset

func _input(event):
	if event != InputEventMouseMotion: return
	value_edited.emit(event.position + _mouseOffset)
