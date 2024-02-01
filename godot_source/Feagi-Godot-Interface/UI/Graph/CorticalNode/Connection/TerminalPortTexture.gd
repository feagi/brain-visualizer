extends TextureRect
class_name TerminalPortTexture

signal terminal_moved()

func _ready() -> void:
	set_notify_transform(true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		terminal_moved.emit()
