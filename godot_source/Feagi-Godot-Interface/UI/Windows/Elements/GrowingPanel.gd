extends Panel
class_name GrowingPanel
## A Panel that grows to the size of its (first) (control inheriting) child

var _child: Control

@export var left_pixel_gap: int = 10
@export var right_pixel_gap: int = 10
@export var top_pixel_gap: int = 10
@export var bottom_pixel_gap: int = 10

func _ready():
	_child = get_child(0)
	_child.resized.connect(_match_size)
	_match_size()

func _match_size() -> void:
	if _child.size == Vector2(0,0):
		return # if a size is set to 0,0, assuming a resize calculation is running
	var addition: Vector2 = Vector2(left_pixel_gap + right_pixel_gap, top_pixel_gap + bottom_pixel_gap)
	size = Vector2(0,0)
	size = _child.size + addition
	_child.position = addition / 2.0
	

