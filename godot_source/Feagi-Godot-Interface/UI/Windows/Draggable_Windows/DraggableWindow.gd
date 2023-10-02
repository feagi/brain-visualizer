extends GrowingPanel
class_name DraggableWindow

signal closed_window(window_name: StringName)

func _ready() -> void:
	super._ready()

func close_window(window_name: StringName) -> void:
	print("WINDOWS UI: User closed %s window" % window_name)
	closed_window.emit(window_name)

func save_to_memory() -> Dictionary:
	assert(false, "DraggableWindow 'save_to_memory' has not been overridden!")
	return {}

func load_from_memory(_previous_data: Dictionary) -> void:
	assert(false, "DraggableWindow 'load_from_memory' has not been overridden!")

func _user_closed_window() -> void:
	assert(false, "DraggableWindow '_user_closed_window' has not been overridden!")
