extends MeshInstance3D
class_name CorticalBoxPreview
## Acts as a hologram to show where and how big a generated cortical area will be

func _ready() -> void:
	FeagiEvents.genome_is_about_to_reset.connect(delete_preview) # On genome reset, reuse the window close function to delete the preview

func toggle_rendering(is_rendering: bool) -> void:
	visible = is_rendering

func delete_preview() -> void:
	queue_free()

func update_size(new_size: Vector3) -> void:
	scale = new_size
	
func update_position(new_position: Vector3) -> void:
	position = _transform_position(new_position)

## BV uses an alternate space for its coordinates currently, this acts as a translation
func _transform_position(position_in: Vector3i) -> Vector3i:
	return Vector3i(
		(int(scale.x / 2.0) + position_in.x),
		(int(scale.y / 2.0) + position_in.y),
		-(int(scale.z / 2.0) + position_in.z))

 
