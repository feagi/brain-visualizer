extends UI_BrainMonitor_AbstractCorticalAreaRenderer
class_name UI_BrainMonitor_DDACorticalAreaRenderer
## Renders a cortical area using the DDA Shader on a Box Mesh. Makes use of textures instead of buffers which is slower, but is supported by WebGL

const PREFAB: PackedScene = preload("res://addons/UI_BrainMonitor/Interactable_Volumes/Cortical_Areas/Renderer_DDA/CorticalArea_DDA_Body.tscn")
const WEBGL_DDA_MAT_PATH: StringName = "res://addons/UI_BrainMonitor/Interactable_Volumes/Cortical_Areas/Renderer_DDA/WebGL_RayMarch.tres"
const OUTLINE_MAT_PATH: StringName = "res://addons/UI_BrainMonitor/Interactable_Volumes/BadMeshOutlineMat.tres"

# TODO right now, particularly for selection, we recreate the SVO tree entirely every time a single node is added / removed. This is slow, and we should be adding / removing SVO nodes instead

var _static_body: StaticBody3D
var _DDA_mat: ShaderMaterial
var _outline_mat: ShaderMaterial
var _friendly_name_label: Label3D

var _activation_image_dimensions: Vector2i = Vector2i(-1,-1) # ensures the first run will not have matching dimensions
var _activation_image: Image
var _activation_image_texture: ImageTexture
var _highlight_SVO: SVOTree
var _highlight_image: Image
var _highlight_image_texture: ImageTexture
var _selection_SVO: SVOTree
var _selection_image: Image
var _selection_image_texture: ImageTexture
var _is_moused_over: bool
var _is_selected: bool

func setup(area: AbstractCorticalArea) -> void:
	_static_body = PREFAB.instantiate()
	_DDA_mat = load(WEBGL_DDA_MAT_PATH).duplicate()
	_outline_mat = load(OUTLINE_MAT_PATH).duplicate()
	(_static_body.get_node("MeshInstance3D") as MeshInstance3D).material_override = _DDA_mat
	add_child(_static_body)
	
	_friendly_name_label = Label3D.new()
	_friendly_name_label.font_size = 192
	add_child(_friendly_name_label)

	# Set initial properties
	_activation_image_texture = ImageTexture.new()
	_highlight_image_texture = ImageTexture.new()
	_selection_image_texture = ImageTexture.new()
	_position_FEAGI_space = area.coordinates_3D # such that when calling Update dimensions, the location is correct
	update_friendly_name(area.friendly_name)
	update_dimensions(area.dimensions_3D)
	#update_position_with_new_FEAGI_coordinate(area.coordinates_3D)
	# Dimensions updates position itself as well

func update_friendly_name(new_name: String) -> void:
	_friendly_name_label.text = new_name

func update_position_with_new_FEAGI_coordinate(new_FEAGI_coordinate_position: Vector3i) -> void:
	super(new_FEAGI_coordinate_position)
	
	_static_body.position = _position_godot_space
	_friendly_name_label.position = _position_godot_space + Vector3(0.0, _static_body.scale.y / 2.0 + 1.5, 0.0 )


func update_dimensions(new_dimensions: Vector3i) -> void:
	super(new_dimensions)
	
	_static_body.scale = _dimensions
	_static_body.position = _position_godot_space
	_friendly_name_label.position = _position_godot_space + Vector3(0.0, _static_body.scale.y / 2.0 + 1.5, 0.0 )

	_DDA_mat.set_shader_parameter("voxel_count_x", new_dimensions.x)
	_DDA_mat.set_shader_parameter("voxel_count_y", new_dimensions.y)
	_DDA_mat.set_shader_parameter("voxel_count_z", new_dimensions.z)
	var max_dim_size: int = max(new_dimensions.x, new_dimensions.y, new_dimensions.z)
	var calculated_depth: int = ceili(log(float(max_dim_size)) / log(2.0)) # since log is with base e, ln(a) / ln(2) = log_base_2(a)
	_DDA_mat.set_shader_parameter("shared_SVO_depth", calculated_depth)
	_outline_mat.set_shader_parameter("thickness_scaling", Vector3(1.0, 1.0, 1.0) / _static_body.scale)
	
	_highlight_SVO = SVOTree.create_SVOTree(new_dimensions)
	_selection_SVO = SVOTree.create_SVOTree(new_dimensions)

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
	const EPSILON: float = 1e-6;
	world_godot_position -= _static_body.position
	world_godot_position += _static_body.scale / 2
	var world_godot_position_floored: Vector3i = Vector3i(floori(world_godot_position.x  - EPSILON), floori(world_godot_position.y  - EPSILON), floori(world_godot_position.z))
	world_godot_position_floored.z = _dimensions.z - world_godot_position_floored.z - EPSILON # flip
	world_godot_position_floored = Vector3(
		clampi(world_godot_position_floored.x, 0, _dimensions.x),
		clampi(world_godot_position_floored.y, 0, _dimensions.y),
		clampi(world_godot_position_floored.z, 0, _dimensions.z)
		) # lots of floating point shenanigans here!
	return world_godot_position_floored
	
func set_cortical_area_mouse_over_highlighting(is_highlighted: bool) -> void:
	_is_moused_over = is_highlighted
	_set_cortical_area_outline(_is_moused_over, _is_selected)

func set_cortical_area_selection(is_selected: bool) -> void:
	_is_selected = is_selected
	_set_cortical_area_outline(_is_moused_over, _is_selected)

func set_highlighted_neurons(neuron_coordinates: Array[Vector3i]) -> void:
	# This only gets called if something changes. For now lets just rebuild the SVO each time
	_highlight_SVO.reset_tree()
	for neuron_coordinate in neuron_coordinates:
		# since We give the neuron coordinate in FEAGI space, but DDA renders in godot space, we need to convert this but flipping the Z axis
		neuron_coordinate.z = _dimensions.z - neuron_coordinate.z - 1
		_highlight_SVO.add_node(neuron_coordinate)
	_highlight_image_texture.set_image(_highlight_SVO.export_as_shader_image())
	_DDA_mat.set_shader_parameter("highlight_SVO", _highlight_image_texture)

func set_neuron_selections(neuron_coordinates: Array[Vector3i]) -> void:
	_selection_SVO.reset_tree()
	for neuron_coordinate in neuron_coordinates:
		# since We give the neuron coordinate in FEAGI space, but DDA renders in godot space, we need to convert this but flipping the Z axis
		neuron_coordinate.z = _dimensions.z - neuron_coordinate.z - 1
		_selection_SVO.add_node(neuron_coordinate)
	_selection_image_texture.set_image(_selection_SVO.export_as_shader_image())
	_DDA_mat.set_shader_parameter("selection_SVO", _selection_image_texture)


func _set_cortical_area_outline(mouse_over: bool, selected: bool) -> void:
	if not (mouse_over || selected):
		_DDA_mat.next_pass = null
		return
	_DDA_mat.next_pass = _outline_mat
	if mouse_over && selected:
		_outline_mat.set_shader_parameter("outline_color", Vector4(cortical_area_outline_both_color.r, cortical_area_outline_both_color.g, cortical_area_outline_both_color.b, cortical_area_outline_both_alpha))
	elif mouse_over:
		_outline_mat.set_shader_parameter("outline_color", Vector4(cortical_area_outline_mouse_over_color.r, cortical_area_outline_mouse_over_color.g, cortical_area_outline_mouse_over_color.b, cortical_area_outline_mouse_over_alpha))
	else:
		_outline_mat.set_shader_parameter("outline_color", Vector4(cortical_area_outline_select_color.r, cortical_area_outline_select_color.g, cortical_area_outline_select_color.b, cortical_area_outline_select_alpha))


# TODO other controls
