extends GrowingPanel
class_name DraggableWindow

signal closed_window(window_name: StringName)

func _ready() -> void:
	super._ready()

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

func _user_closed_window() -> void:
	assert(false, "DraggableWindow '_user_closed_window' has not been overridden!")
