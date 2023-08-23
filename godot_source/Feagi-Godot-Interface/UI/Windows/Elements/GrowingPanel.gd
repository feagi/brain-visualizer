extends Panel
class_name GrowingPanel
## A Panel that grows to the size of its (first) (control inheriting) child

var _child: Control

func _ready():
	_child = get_child(0)
	_child.resized.connect(_match_size)

func _match_size() -> void:
	size = _child.size

