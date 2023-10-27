extends GrowingPanel
class_name DraggableWindow

signal closed_window(window_name: StringName)

func _ready() -> void:
	super._ready()
	gui_input.connect(_bring_to_top_if_click)

## Called from Window manager, to save previous position
func save_to_memory() -> Dictionary:
	return {
		"position": position,
	}

## Called from Window manager, to load previous position
func load_from_memory(previous_data: Dictionary) -> void:
	position = previous_data["position"]

func close_window(window_name: StringName) -> void:
	print("WINDOWS UI: User closed %s window" % window_name)
	closed_window.emit(window_name)

func bring_window_to_top():
	print("UI: WINDOW: Changing window order...")
	VisConfig.UI_manager.window_manager.bring_window_to_top(self)

func _user_closed_window() -> void:
	assert(false, "DraggableWindow '_user_closed_window' has not been overridden!")

func _bring_to_top_if_click(event: InputEvent):
	if !(event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if !(mouse_event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]):
		return
	if !mouse_event.pressed:
		return
	
	bring_window_to_top()
