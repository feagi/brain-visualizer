extends SpinBox
class_name IntSpinBox

var _default_min_size: Vector2

func _ready():
	
	if custom_minimum_size != Vector2(0,0):
		_default_min_size = custom_minimum_size

func _apply_theme(new_theme: Theme) -> void:
	set_theme(new_theme)

