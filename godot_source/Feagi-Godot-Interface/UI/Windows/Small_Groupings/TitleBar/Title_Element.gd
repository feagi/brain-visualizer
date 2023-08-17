extends Label_Element
class_name Title_Element
## Used exclusively for title bars, probably shouldnt be used elsewhere

## The gap from the left
var gap: int:
	get: return int(position.x)
	set(v): position = Vector2i(v, 0)

func _ready():
	VisConfig.UI_settings_changed.connect(_update_size)
	gap = 10

func _update_size() -> void:
	custom_minimum_size = VisConfig.minimum_button_size_pixel  # Match minimum size of button so that things look even