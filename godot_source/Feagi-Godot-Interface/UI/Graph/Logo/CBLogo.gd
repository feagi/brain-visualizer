extends Sprite2D
class_name CBLogo


var _background_offset: Vector2

func _ready():
	_background_offset = position

func set_background_position(panning: Vector2) -> void:
	position = -panning * VisConfig.UI_manager.screen_size + _background_offset
