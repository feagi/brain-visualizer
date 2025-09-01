extends UI_BrainMonitor_AbstractInteractableVolumeRenderer
class_name UI_BrainMonitor_InteractivePreviewRenderer
## Handles rendering Interactive Previews

const PREFAB: PackedScene = preload("res://addons/UI_BrainMonitor/Interactable_Volumes/Interactive_Previews/Preview_Body.tscn")
const SHADER_SIMPLE_MAT_PATH: StringName = "res://addons/UI_BrainMonitor/Interactable_Volumes/Interactive_Previews/PreviewShaderMatSimple.tres"

var _showing_voxels: bool
var _static_body: StaticBody3D
var _mat: ShaderMaterial

func setup(initial_FEAGI_position: Vector3i, initial_dimensions: Vector3i, show_voxels: bool) -> void:
	_showing_voxels = show_voxels
	_static_body = PREFAB.instantiate()
	
	if _showing_voxels:
		pass # todo
	else:
		_mat = load(SHADER_SIMPLE_MAT_PATH).duplicate()
	
	(_static_body.get_node("MeshInstance3D") as MeshInstance3D).material_override = _mat
	add_child(_static_body)
	
	_position_FEAGI_space = initial_FEAGI_position
	update_dimensions(initial_dimensions)

func update_position_with_new_FEAGI_coordinate(new_FEAGI_coordinate_position: Vector3i) -> void:
	super(new_FEAGI_coordinate_position)
	_static_body.position = _position_godot_space
	
func update_dimensions(new_dimensions: Vector3i) -> void:
	super(new_dimensions)
	
	_static_body.scale = _dimensions
	_static_body.position = _position_godot_space # Update position stuff too since these are based in Godot space
	
	if _showing_voxels:
		pass # todo
