extends MeshInstance3D
class_name CorticalBoxPreview
## Acts as a hologram to show where and how big a generated cortical area will be

func _ready() -> void:
	FeagiEvents.genome_is_about_to_reset.connect(window_closed) # On genome reset, reuse the window close function to delete the preview

func toggle_rendering(is_rendering: bool) -> void:
	visible = is_rendering

func window_closed(irrelevant = null) -> void:
	queue_free()

func update_size(new_size: Vector3) -> void:
	scale = new_size
	
func update_position(new_position: Vector3) -> void:
	position = new_position * Vector3(1,1,-1)


 
