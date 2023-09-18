extends Control
class_name FullScreenControl
## Control that scales to full screen window size

signal click_event(event: InputEventMouseButton)

func _ready() -> void:
	size = VisConfig.UI_manager.screen_size
	VisConfig.UI_manager.screen_size_changed.connect(_screen_size_changed)
	gui_input.connect(_check_for_click_input)


func _screen_size_changed(new_screen_size: Vector2) -> void:
	size = new_screen_size

func _check_for_click_input(event: InputEvent):
	if !(event is InputEventMouseButton):
		return
	print("UI: Background %s recieved a click event" % name)
	click_event.emit(event)

	

