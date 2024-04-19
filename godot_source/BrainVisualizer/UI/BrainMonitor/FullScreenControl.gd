extends Control
class_name FullScreenControl
## Control that scales to full screen window size

signal click_event(event: InputEventMouseButton)
signal pan_event(event: InputEventPanGesture)
signal keyboard_event(event: InputEventKey)

func _ready() -> void:
	#TODO clean up this
	size = get_node("/root/BrainVisualizer/UIManager").screen_size
	get_node("/root/BrainVisualizer/UIManager").screen_size_changed.connect(_screen_size_changed)
	gui_input.connect(_check_for_click_input)
	_screen_size_changed(get_viewport().get_visible_rect().size)

func _screen_size_changed(new_screen_size: Vector2) -> void:
	size = new_screen_size

func _check_for_click_input(event: InputEvent):
	if event is InputEventMouseButton:
		#print("UI: Background %s recieved a click event" % name) # commented out since this often results in log spam
		click_event.emit(event)

	if event is InputEventPanGesture:
		#print("UI: Background %s recieved a pan event" % name) # commented out since this often results in log spam
		pan_event.emit(event)
	
	if event is InputEventKey:
		print("a")
		keyboard_event.emit(event)
		
	

