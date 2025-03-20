extends UI_BrainMonitor_AbstractCorticalAreaRenderer
class_name UI_BrainMonitor_DDACorticalAreaRenderer
## Renders a cortical area using the DDA Shader on a Box Mesh. Makes use of textures instead of buffers which is slower, but is supported by WebGL

const PREFAB: PackedScene = preload("res://addons/UI_BrainMonitor/Cortical_Areas/Renderers/DDA/DDABody.tscn")
const DDA_MAT_PATH: StringName = "res://addons/UI_BrainMonitor/Cortical_Areas/Renderers/DDA/DDA_CA_mat.tres"


var _static_body: StaticBody3D
var _DDA_mat: ShaderMaterial
var _activation_image_dimensions: Vector2i = Vector2i(-1,-1) # ensures the first run will not have matching dimensions
var _activation_image: Image
var _activation_image_texture: ImageTexture
var _friendly_name_label: Label3D
var _cortical_dimensions: Vector3i
var _cortical_location: Vector3i # FEAGI space

func setup(area: AbstractCorticalArea) -> void:
	_static_body = PREFAB.instantiate()
	_DDA_mat = load(DDA_MAT_PATH).duplicate()
	(_static_body.get_node("MeshInstance3D") as MeshInstance3D).material_override = _DDA_mat
	add_child(_static_body)
	
	_friendly_name_label = Label3D.new()
	_friendly_name_label.font_size = 192
	add_child(_friendly_name_label)

	# Set initial properties
	_activation_image_texture = ImageTexture.new()
	_cortical_location = area.coordinates_3D # such that when calling Update dimensions, the location is correct
	update_friendly_name(area.friendly_name)
	update_dimensions(area.dimensions_3D)
	# Dimensions updates position itself as well

func update_friendly_name(new_name: String) -> void:
	_friendly_name_label.text = new_name

func update_position(new_position: Vector3i) -> void:
	_cortical_location = new_position

	var lower_left_front_corner_offset: Vector3 = _static_body.scale / 2.0
	lower_left_front_corner_offset.z = -lower_left_front_corner_offset.z
	var offset: Vector3 = lower_left_front_corner_offset
	new_position.z = -new_position.z
	_static_body.position = Vector3(new_position) + offset
	_friendly_name_label.position = _static_body.position + Vector3(0.0, _static_body.scale.y / 2.0 + 1.5, 0.0 )


func update_dimensions(new_dimensions: Vector3i) -> void:
	_cortical_dimensions = new_dimensions
	_static_body.scale = new_dimensions
	
	_DDA_mat.set_shader_parameter("voxel_count_x", new_dimensions.x)
	_DDA_mat.set_shader_parameter("voxel_count_y", new_dimensions.y)
	_DDA_mat.set_shader_parameter("voxel_count_z", new_dimensions.z)
	var max_dim_size: int = max(new_dimensions.x, new_dimensions.y, new_dimensions.z)
	var calculated_depth: int = ceili(log(float(max_dim_size)) / log(2.0)) # since log is with base e, ln(a) / ln(2) = log_base_2(a)
	_DDA_mat.set_shader_parameter("shared_SVO_depth", calculated_depth)
	update_position(_cortical_location)
	

func update_visualization_data(visualization_data: PackedByteArray) -> void:
	var retrieved_image_dimensions: Vector2i = Vector2i(visualization_data.decode_u16(0), visualization_data.decode_u16(2))
	if retrieved_image_dimensions != _activation_image_dimensions:
		_activation_image_dimensions = retrieved_image_dimensions
		_activation_image = Image.create_from_data(_activation_image_dimensions.x, _activation_image_dimensions.y, false, Image.Format.FORMAT_RF, visualization_data.slice(4))
		_activation_image_texture.set_image(_activation_image)
	else:
		_activation_image.set_data(_activation_image_dimensions.x, _activation_image_dimensions.y, false, Image.Format.FORMAT_RF, visualization_data.slice(4)) # TODO is there a way to set this data without reallocating it?
		_activation_image_texture.update(_activation_image)
	_DDA_mat.set_shader_parameter("activation_SVO", _activation_image_texture)

func world_godot_position_to_neuron_coordinate(world_godot_position: Vector3) -> Vector3i:
	world_godot_position -= _static_body.position
	var dimensions_cortical: Vector3i = Vector3i(roundi(_static_body.scale.x), roundi(_static_body.scale.y), roundi(_static_body.scale.z))
	var world_pos_int: Vector3i = Vector3i(floori(world_godot_position.x), floori(world_godot_position.y), floori(world_godot_position.z))
	
	return world_pos_int - Vector3i(floori(_static_body.scale.x / 2), floori(_static_body.scale.y / 2), floori(_static_body.scale.z / 2))



# TODO other controls
