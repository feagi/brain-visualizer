extends RefCounted
class_name UI_BrainMonitor_InputEvent_Abstract
## Essentially a fake Godot [InputEvent] tailored for BM inputs

enum CLICK_BUTTON {
	NONE, # never used, essentially a placeholder
	MAIN,
	SECONDARY
}

var ray_start_point: Vector3
var ray_end_point: Vector3

func _init() -> void:
	assert(false, "'UI_BrainMonitor_InputEvent_Abstract' cannot be instantiated directly!")

func get_ray_query() -> PhysicsRayQueryParameters3D:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	query.from = ray_start_point
	query.to = ray_end_point
	return query
