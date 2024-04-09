extends BoxContainer
class_name BoxSeperatorScalar

var _default_seperation: float # Save as float to avoid rounding errors when multiplying

func _ready() -> void:
	_default_seperation = get_theme_constant(&"separation")

func _update_size(multiplier: float) -> void:
	var new_seperation: int = int(_default_seperation * multiplier)
	add_theme_constant_override(&"seperation", new_seperation)

