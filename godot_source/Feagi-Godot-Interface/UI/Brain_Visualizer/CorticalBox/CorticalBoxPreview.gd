extends MeshInstance3D
class_name CorticalBoxPreview
## Acts as a hologram to show where and how big a generated cortical area will be

func toggle_rendering(is_rendering: bool) -> void:
	visible = is_rendering

func window_closed(irrelevant) -> void:
	queue_free()

func update_size(new_size: Vector3) -> void:
	scale = new_size
	
func update_position(new_position: Vector3) -> void:
	position = new_position


 
