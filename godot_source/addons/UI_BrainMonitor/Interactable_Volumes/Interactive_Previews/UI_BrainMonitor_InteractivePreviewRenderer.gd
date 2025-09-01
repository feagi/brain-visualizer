extends UI_BrainMonitor_AbstractInteractableVolumeRenderer
class_name UI_BrainMonitor_InteractivePreviewRenderer
## Handles rendering Interactive Previews

const PREFAB: PackedScene = preload("res://addons/UI_BrainMonitor/Interactable_Volumes/Interactive_Previews/Preview_Body.tscn")
const SHADER_SIMPLE_MAT_PATH: StringName = "res://addons/UI_BrainMonitor/Interactable_Volumes/Interactive_Previews/PreviewShaderMatSimple.tres"

var _showing_voxels: bool
var _static_body: StaticBody3D
var _mat: ShaderMaterial

func setup(initial_FEAGI_position: Vector3i, initial_dimensions: Vector3i, show_voxels: bool) -> void:
	print("🔮 RENDERER DEBUG: InteractivePreviewRenderer setup called")
	print("  - Position: %s, Dimensions: %s, Show voxels: %s" % [initial_FEAGI_position, initial_dimensions, show_voxels])
	
	_showing_voxels = show_voxels
	_static_body = PREFAB.instantiate()
	print("  - Static body instantiated: %s" % _static_body)
	
	if _showing_voxels:
		pass # todo
	else:
		_mat = load(SHADER_SIMPLE_MAT_PATH).duplicate()
		print("  - Material loaded: %s" % _mat)
	
	var mesh_instance = _static_body.get_node("MeshInstance3D") as MeshInstance3D
	mesh_instance.material_override = _mat
	print("  - Material applied to mesh instance: %s" % mesh_instance)
	
	add_child(_static_body)
	print("  - Static body added as child")
	
	_position_FEAGI_space = initial_FEAGI_position
	update_dimensions(initial_dimensions)
	print("  - Position and dimensions updated")
	print("🔮 RENDERER DEBUG: InteractivePreviewRenderer setup complete")

func update_position_with_new_FEAGI_coordinate(new_FEAGI_coordinate_position: Vector3i) -> void:
	print("🔮 RENDERER DEBUG: update_position_with_new_FEAGI_coordinate called")
	print("  - New FEAGI position: %s" % new_FEAGI_coordinate_position)
	super(new_FEAGI_coordinate_position)
	print("  - Calculated Godot position: %s" % _position_godot_space)
	_static_body.position = _position_godot_space
	print("  - Static body position set to: %s" % _static_body.position)
	
func update_dimensions(new_dimensions: Vector3i) -> void:
	print("🔮 RENDERER DEBUG: update_dimensions called")
	print("  - New dimensions: %s" % new_dimensions)
	super(new_dimensions)
	print("  - Calculated scale: %s" % _dimensions)
	
	_static_body.scale = _dimensions
	_static_body.position = _position_godot_space # Update position stuff too since these are based in Godot space
	print("  - Static body scale set to: %s" % _static_body.scale)
	print("  - Static body position updated to: %s" % _static_body.position)
	
	if _showing_voxels:
		pass # todo
