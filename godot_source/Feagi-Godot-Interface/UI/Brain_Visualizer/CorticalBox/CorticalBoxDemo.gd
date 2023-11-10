extends MeshInstance3D
class_name CorticalBoxDemo
## Acts as a hologram to show where and how big a generated cortical area will be

func _toggle_rendering(is_rendering: bool) -> void:
	visible = is_rendering

func _window_closed(irrelevant) -> void:
	queue_free()

func _update_size_position(new_size: Vector3, new_position: Vector3) -> void:
	scale = new_size
	position = new_position


 
