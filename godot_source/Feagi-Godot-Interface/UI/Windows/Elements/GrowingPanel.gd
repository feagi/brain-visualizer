extends Panel
class_name GrowingPanel
## A Panel that grows to the size of its (first) (control inheriting) child

var _child: Control

@export var left_pixel_gap: int = 0
@export var right_pixel_gap: int = 0
@export var top_pixel_gap: int = 0
@export var bottom_pixel_gap: int = 0

func _ready():
	_child = get_child(0)
	_child.resized.connect(_match_size)
	_match_size()

func _match_size() -> void:
	var addition: Vector2 = Vector2(left_pixel_gap + right_pixel_gap, top_pixel_gap + bottom_pixel_gap)
	size = _child.size + addition
	_child.position = addition / 2.0

