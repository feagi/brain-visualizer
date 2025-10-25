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
var _is_hovered_over: bool
var _is_selected: bool

func setup(area: AbstractCorticalArea) -> void:
	print("🧠 DDA RENDERER SETUP for cortical area: %s" % area.cortical_ID)
	_static_body = PREFAB.instantiate()
	_DDA_mat = load(WEBGL_DDA_MAT_PATH).duplicate()
	_outline_mat = load(OUTLINE_MAT_PATH).duplicate()
	
	(_static_body.get_node("MeshInstance3D") as MeshInstance3D).material_override = _DDA_mat
	
	add_child(_static_body)
	
	# Create individual plate if needed
	_create_individual_plate_if_needed(area)
	
	# Create friendly name label with high-quality MSDF rendering
	_friendly_name_label = Label3D.new()
	_friendly_name_label.font_size = 512  # High resolution for crisp text at distance
	_friendly_name_label.font = load("res://BrainVisualizer/UI/GenericResources/RobotoCondensed-Bold.ttf")
	_friendly_name_label.modulate = Color.WHITE
	_friendly_name_label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_friendly_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED  # Always face camera
	_friendly_name_label.alpha_scissor_threshold = 0.5  # Clean edges
	_friendly_name_label.no_depth_test = false  # Respect depth for proper occlusion
	_friendly_name_label.render_priority = 1  # Render after most objects
	add_child(_friendly_name_label)

	# Set initial properties
	_activation_image_texture = ImageTexture.new()
	_highlight_image_texture = ImageTexture.new()
	_selection_image_texture = ImageTexture.new()
	
	_position_FEAGI_space = area.coordinates_3D # such that when calling Update dimensions, the location is correct
	update_friendly_name(area.friendly_name)
	update_dimensions(area.dimensions_3D)
	# Dimensions updates position itself as well

func update_friendly_name(new_name: String) -> void:
	_friendly_name_label.text = new_name

func update_position_with_new_FEAGI_coordinate(new_FEAGI_coordinate_position: Vector3i) -> void:
	super(new_FEAGI_coordinate_position)
	
	_static_body.position = _position_godot_space
	_friendly_name_label.position = _position_godot_space + Vector3(0.0, _static_body.scale.y / 2.0 + 2.0, 0.0 )


func update_dimensions(new_dimensions: Vector3i) -> void:
	super(new_dimensions)
	
	_static_body.scale = _dimensions
	_static_body.position = _position_godot_space # Update position stuff too since these are based in Godot space
	_friendly_name_label.position = _position_godot_space + Vector3(0.0, _static_body.scale.y / 2.0 + 2.0, 0.0 )

	_DDA_mat.set_shader_parameter("voxel_count_x", new_dimensions.x)
	_DDA_mat.set_shader_parameter("voxel_count_y", new_dimensions.y)
	_DDA_mat.set_shader_parameter("voxel_count_z", new_dimensions.z)
	var max_dim_size: int = max(new_dimensions.x, new_dimensions.y, new_dimensions.z)
	var calculated_depth: int = ceili(log(float(max_dim_size)) / log(2.0)) # since log is with base e, ln(a) / ln(2) = log_base_2(a)
	calculated_depth = maxi(calculated_depth, 1)
	_DDA_mat.set_shader_parameter("shared_SVO_depth", calculated_depth)
	_outline_mat.set_shader_parameter("thickness_scaling", Vector3(1.0, 1.0, 1.0) / _static_body.scale)
	
	_highlight_SVO = SVOTree.create_SVOTree(new_dimensions)
	_selection_SVO = SVOTree.create_SVOTree(new_dimensions)

func update_visualization_data(visualization_data: PackedByteArray) -> void:
	print("🔄 SVO RENDERER: Processing Type 10 (NEURON_FLAT/SVO) visualization data (", visualization_data.size(), " bytes)")
	
	var retrieved_image_dimensions: Vector2i = Vector2i(visualization_data.decode_u16(0), visualization_data.decode_u16(2))
	if retrieved_image_dimensions != _activation_image_dimensions:
		_activation_image_dimensions = retrieved_image_dimensions
		_activation_image = Image.create_from_data(_activation_image_dimensions.x, _activation_image_dimensions.y, false, Image.Format.FORMAT_RF, visualization_data.slice(4))
		_activation_image_texture.set_image(_activation_image)
		print("   📊 Created new SVO texture: ", _activation_image_dimensions)
	else:
		_activation_image.set_data(_activation_image_dimensions.x, _activation_image_dimensions.y, false, Image.Format.FORMAT_RF, visualization_data.slice(4)) # TODO is there a way to set this data without reallocating it?
		_activation_image_texture.update(_activation_image)
		print("   🔄 Updated existing SVO texture: ", _activation_image_dimensions)
	_DDA_mat.set_shader_parameter("activation_SVO", _activation_image_texture)

func world_godot_position_to_neuron_coordinate(world_godot_position: Vector3) -> Vector3i:
	const EPSILON: float = 1e-6;
	world_godot_position -= _static_body.position
	world_godot_position += _static_body.scale / 2
	var world_godot_position_floored: Vector3i = Vector3i(floori(world_godot_position.x  - EPSILON), floori(world_godot_position.y  - EPSILON), floori(world_godot_position.z))
	world_godot_position_floored.z = _dimensions.z - world_godot_position_floored.z - EPSILON # flip
	world_godot_position_floored = Vector3(
		clampi(world_godot_position_floored.x, 0, _dimensions.x - 1),
		clampi(world_godot_position_floored.y, 0, _dimensions.y - 1),
		clampi(world_godot_position_floored.z, 0, _dimensions.z - 1)
		) # lots of floating point shenanigans here!
	return world_godot_position_floored
	
func set_cortical_area_mouse_over_highlighting(is_highlighted: bool) -> void:
	_is_hovered_over = is_highlighted
	_set_cortical_area_outline(_is_hovered_over, _is_selected)

func set_cortical_area_selection(is_selected: bool) -> void:
	_is_selected = is_selected
	_set_cortical_area_outline(_is_hovered_over, _is_selected)

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

## Creates an individual plate under this cortical area if needed
func _create_individual_plate_if_needed(area: AbstractCorticalArea) -> void:
	# 1) Skip if already on a brain region plate (avoid double plating)
	if _is_on_brain_region_plate():
		return

	# 2) Determine IO status from active brain regions in the scene
	var plate_type := _determine_plate_type(area)  # "input" | "output" | "conflict" | "none"
	if plate_type == "none":
		return

	# 3) Create plate with proper color and thickness (1.0) under the cortical area
	var plate_mesh := MeshInstance3D.new()
	plate_mesh.name = "IndividualPlate"

	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(area.dimensions_3D.x, 1.0, area.dimensions_3D.z)
	plate_mesh.mesh = box_mesh

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.flags_unshaded = true
	material.flags_transparent = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.flags_do_not_receive_shadows = true
	material.flags_disable_ambient_light = true

	match plate_type:
		"input":
			material.albedo_color = Color(0.0, 0.6, 0.0, 0.2)
		"output":
			material.albedo_color = Color(0.0, 0.4, 0.0, 0.2)
		"conflict":
			material.albedo_color = Color(0.8, 0.0, 0.0, 0.2)

	plate_mesh.material_override = material
	plate_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plate_mesh.position = Vector3(0.0, -0.5, 0.0)

	_static_body.add_child(plate_mesh)


# TODO other controls

## Checks if this cortical area is positioned on a brain region's I/O plate
func _is_on_brain_region_plate() -> bool:
	var current_parent := get_parent()
	while current_parent != null:
		if current_parent.name == "InputAreas" or current_parent.name == "OutputAreas" or current_parent.name == "ConflictAreas":
			return true
		current_parent = current_parent.get_parent()
	return false

## Determines what type of plate this cortical area should have based on brain region I/O lists
func _determine_plate_type(area: AbstractCorticalArea) -> String:
	var is_input := false
	var is_output := false

	var brain_monitor := _find_brain_monitor_scene()
	if brain_monitor == null:
		return "none"

	var brain_regions := _find_all_brain_regions_recursive(brain_monitor)
	for region_viz in brain_regions:
		if region_viz == null:
			continue
		var br: BrainRegion = region_viz.representing_region
		if br == null:
			continue

		for link in br.input_open_chain_links:
			if link.destination is AbstractCorticalArea and (link.destination as AbstractCorticalArea).cortical_ID == area.cortical_ID:
				is_input = true
				break
		if not is_input:
			for pm in br.partial_mappings:
				if pm.is_region_input and pm.internal_target_cortical_area and pm.internal_target_cortical_area.cortical_ID == area.cortical_ID:
					is_input = true
					break
		if not is_input:
			for a in br.contained_cortical_areas:
				if a.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU and a.cortical_ID == area.cortical_ID:
					is_input = true
					break

		for link2 in br.output_open_chain_links:
			if link2.source is AbstractCorticalArea and (link2.source as AbstractCorticalArea).cortical_ID == area.cortical_ID:
				is_output = true
				break
		if not is_output:
			for pm2 in br.partial_mappings:
				if not pm2.is_region_input and pm2.internal_target_cortical_area and pm2.internal_target_cortical_area.cortical_ID == area.cortical_ID:
					is_output = true
					break
		if not is_output:
			for a2 in br.contained_cortical_areas:
				if a2.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU and a2.cortical_ID == area.cortical_ID:
					is_output = true
					break

	if is_input and is_output:
		return "conflict"
	elif is_input:
		return "input"
	elif is_output:
		return "output"
	return "none"

## Helper to find the brain monitor scene (accept true scene or BM_* container)
func _find_brain_monitor_scene() -> Node:
	var current := get_parent()
	while current != null:
		if current is UI_BrainMonitor_3DScene:
			return current
		if str(current.name).begins_with("BM_"):
			return current
		current = current.get_parent()
	return null

## Helper to recursively find all brain region 3D objects under a node
func _find_all_brain_regions_recursive(node: Node) -> Array[UI_BrainMonitor_BrainRegion3D]:
	var acc: Array[UI_BrainMonitor_BrainRegion3D] = []
	if node is UI_BrainMonitor_BrainRegion3D:
		acc.append(node as UI_BrainMonitor_BrainRegion3D)
	for child in node.get_children():
		acc.append_array(_find_all_brain_regions_recursive(child))
	return acc
