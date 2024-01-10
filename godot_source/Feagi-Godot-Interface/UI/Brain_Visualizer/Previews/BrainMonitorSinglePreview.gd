extends MeshInstance3D
class_name BrainMonitorSinglePreview
## Acts as a hologram to show where and how big a singular entity will be

const DEFAULT_COLOR: Color = Color(0.133, 0.733, 0.114, 0.8)

@export var default_color: Color = DEFAULT_COLOR

const COLOR_PARAMETER_NAME: StringName = "albedo_color"

var _material: Material

func _ready() -> void:
	FeagiEvents.genome_is_about_to_reset.connect(delete_preview) # On genome reset, reuse the window close function to delete the preview
	_material = get_active_material(0)

func setup(preview_dimensions: Vector3, preview_position: Vector3, color: Color = default_color, is_rendering: bool = true) -> void:
	update_size(preview_dimensions)
	update_position(preview_position)
	toggle_rendering(is_rendering)
	set_color(color)

func toggle_rendering(is_rendering: bool) -> void:
	visible = is_rendering

func delete_preview() -> void:
	queue_free()

func update_size(new_size: Vector3) -> void:
	scale = new_size
	
func update_position(new_position: Vector3) -> void:
	position = BaseCorticalArea.true_position_to_BV_position(new_position, scale) #TODO this func needs to be moved to BMM

func set_color(new_color: Color) -> void:
	_material.set_shader_parameter("COLOR_PARAMETER_NAME", new_color)
