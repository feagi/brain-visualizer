extends UI_BrainMonitor_InputEvent_Abstract
class_name UI_BrainMonitor_InputEvent_FocusChanged
## Essentially a fake Godot [InputEvent] tailored for BM inputs

var is_focused: bool
# NOTE: The start position / end position vars are not valid for this object type!

func _init(is_currently_focused: bool):
	is_focused = is_currently_focused

func get_ray_query() -> PhysicsRayQueryParameters3D:
	push_error("'UI_BrainMonitor_InputEvent_FocusChanged' does not have valid raycast queries!")
	return null
