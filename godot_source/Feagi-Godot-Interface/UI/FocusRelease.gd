extends Control
class_name FocusRelease
## Exists to release the focus of the mouse from UI elements when anywhere else is clicked


# Called when the node enters the scene tree for the first time.
func _ready():
	gui_input.connect(_focused_on_background)

func _focused_on_background(_event: InputEvent) -> void:
	
	if _event is InputEventMouseButton:
		print("clicked")
		release_focus()
