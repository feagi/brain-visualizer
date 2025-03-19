extends RefCounted
class_name UI_BrainMonitor_SelectionRaycasts

const RAYCAST_LENGTH: float = 10000

signal currently_mousing_overs(raycasts: Array[PhysicsRayQueryParameters3D]) # for every mouse on screen, what are we mousing over? (in the case of VR, we may be mousing over multiple things at once)


func shoot_ray_pancake(pancake_cam: UI_BrainMonitor_PancakeCamera) -> void:
	var mouse_position: Vector2 = pancake_cam.get_viewport().get_mouse_position()
	var ray_from: Vector3 = pancake_cam.project_ray_origin(mouse_position)
	var ray_endpoint: Vector3 = (pancake_cam.project_ray_normal(mouse_position) * RAYCAST_LENGTH) + ray_from
	
	
