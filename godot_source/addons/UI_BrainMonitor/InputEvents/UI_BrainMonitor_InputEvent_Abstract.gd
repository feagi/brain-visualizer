extends RefCounted
class_name UI_BrainMonitor_InputEvent_Abstract
## Essentially a fake Godot [InputEvent] tailored for BM inputs

enum CLICK_BUTTON {
	NONE, # never used, essentially a placeholder
	MAIN, # Normal Selection
	SECONDARY, # alternate selection
	HOLD_TO_SELECT_NEURONS, # Alternate key to hold when selecting neurons
	FIRE_SELECTED_NEURONS, # Key that is presed when we want to fire neurons,
	CLEAR_ALL_SELECTED_NEURONS, # Key that is pressed if user wants to clear all selected neurons
}

var ray_start_point: Vector3
var ray_end_point: Vector3
var controller_ID: int = 0 # if there are multiple controllers, this can be used to differentiate between them
var all_buttons_being_held: Array[CLICK_BUTTON] = [] # All buttons being held at time of input

func _init() -> void:
	assert(false, "'UI_BrainMonitor_InputEvent_Abstract' cannot be instantiated directly!")

func get_ray_query() -> PhysicsRayQueryParameters3D:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	query.from = ray_start_point
	query.to = ray_end_point
	return query
