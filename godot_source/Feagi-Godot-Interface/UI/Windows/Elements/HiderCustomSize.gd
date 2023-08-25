extends BoxContainer
class_name HiderConstantSize
## Enables hiding of all children without affecting size / placement

@export var children_visible_at_start: bool = true

## Set children visibility
var children_visible: bool:
	get: return _children_visible
	set(v):
		_children_visible = v
		toggle_child_visibility(v)

var _children_visible: bool

func _ready():
	call_deferred(&"_initial_visibility") # Defer this call to ensure proper sizing

## Set children visibility
func toggle_child_visibility(children_visibility: bool) -> void:
	custom_minimum_size = _get_total_size_of_children()
	_set_children_visibility(children_visibility)

## returns size of all children
func _get_total_size_of_children() -> Vector2:
	var children = get_children()
	var output: Vector2
	for child in children:
		output = output + child.size
	return output

func _set_children_visibility(is_visible: bool) -> void:
	var children = get_children()
	for child in children:
		child.visible = is_visible

func _initial_visibility():
	children_visible = children_visible_at_start
