extends UI_BrainMonitor_AbstractCorticalAreaRenderer
class_name UI_BrainMonitor_DirectPointsCorticalAreaRenderer
## Renders a cortical area using direct point rendering with MultiMeshInstance3D for optimal performance
## This renderer processes Type 11 (Direct Neural Points) data for real-time neural visualization

const NEURON_VOXEL_MESH: PackedScene = preload("res://addons/UI_BrainMonitor/Interactable_Volumes/Cortical_Areas/Renderer_DirectPoints/NeuronVoxel.tscn")
const OUTLINE_MAT_PATH: StringName = "res://addons/UI_BrainMonitor/Interactable_Volumes/BadMeshOutlineMat.tres"

# Rendering components
var _static_body: StaticBody3D
var _multi_mesh_instance: MultiMeshInstance3D
var _multi_mesh: MultiMesh
var _outline_mesh_instance: MeshInstance3D
var _outline_mat: ShaderMaterial
var _friendly_name_label: Label3D

# State tracking
var _is_hovered_over: bool = false
var _is_selected: bool = false
var _current_neuron_count: int = 0
var _max_neurons: int = 10000  # Performance limit

# Highlight and selection tracking
var _highlighted_neurons: Array[Vector3i] = []
var _selected_neurons: Array[Vector3i] = []

func setup(area: AbstractCorticalArea) -> void:
	# Create static body for collision detection
	_static_body = StaticBody3D.new()
	_static_body.name = "DirectPointsBody"
	add_child(_static_body)
	
	# Create collision shape for the cortical area volume
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	collision_shape.shape = box_shape
	_static_body.add_child(collision_shape)
	
	# Create MultiMeshInstance3D for efficient neuron rendering
	_multi_mesh_instance = MultiMeshInstance3D.new()
	_multi_mesh_instance.name = "NeuronVoxels"
	_static_body.add_child(_multi_mesh_instance)
	
	# Setup MultiMesh for instanced rendering
	_multi_mesh = MultiMesh.new()
	_multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	_multi_mesh.instance_count = 0
	
	# Create voxel (cube) mesh for each neuron - maintaining familiar voxel appearance
	var voxel_mesh = BoxMesh.new()
	voxel_mesh.size = Vector3(0.8, 0.8, 0.8)  # Slightly smaller than 1.0 to show individual voxels
	_multi_mesh.mesh = voxel_mesh
	
	# Create material for neuron voxels with color and transparency support
	var neuron_material = StandardMaterial3D.new()
	neuron_material.albedo_color = Color.CYAN
	neuron_material.emission_enabled = true
	neuron_material.emission_color = Color.CYAN
	neuron_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	neuron_material.alpha = 0.8
	_multi_mesh.mesh.surface_set_material(0, neuron_material)
	
	_multi_mesh_instance.multimesh = _multi_mesh
	
	# Create outline mesh for cortical area bounds
	_outline_mesh_instance = MeshInstance3D.new()
	_outline_mesh_instance.name = "CorticalAreaOutline"
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3.ONE
	_outline_mesh_instance.mesh = box_mesh
	_outline_mat = load(OUTLINE_MAT_PATH).duplicate()
	_outline_mesh_instance.material_override = _outline_mat
	_outline_mesh_instance.visible = false  # Hidden by default
	_static_body.add_child(_outline_mesh_instance)
	
	# Create friendly name label
	_friendly_name_label = Label3D.new()
	_friendly_name_label.name = "AreaNameLabel"
	_friendly_name_label.font_size = 192
	_friendly_name_label.modulate = Color.WHITE
	add_child(_friendly_name_label)

	# Set initial properties
	_position_FEAGI_space = area.coordinates_3D
	update_friendly_name(area.friendly_name)
	update_dimensions(area.dimensions_3D)
	
	# Connect to direct neural points signal
	area.recieved_new_direct_neural_points.connect(_on_received_direct_neural_points)
	
	print("DirectPoints voxel renderer setup completed for area: ", area.cortical_ID)

func update_friendly_name(new_name: String) -> void:
	_friendly_name_label.text = new_name

func update_position_with_new_FEAGI_coordinate(new_FEAGI_coordinate_position: Vector3i) -> void:
	super(new_FEAGI_coordinate_position)
	_static_body.position = _position_godot_space
	_outline_mesh_instance.position = Vector3.ZERO  # Relative to static body
	_friendly_name_label.position = _position_godot_space + Vector3(0.0, _static_body.scale.y / 2.0 + 1.5, 0.0)

func update_dimensions(new_dimensions: Vector3i) -> void:
	super(new_dimensions)
	
	# Update static body scale and position
	_static_body.scale = _dimensions
	_static_body.position = _position_godot_space
	
	# Update collision shape size
	var collision_shape = _static_body.get_child(0) as CollisionShape3D
	if collision_shape and collision_shape.shape is BoxShape3D:
		(collision_shape.shape as BoxShape3D).size = Vector3.ONE  # Will be scaled by static_body
	
	# Update outline mesh size
	_outline_mesh_instance.scale = _dimensions
	
	# Update friendly name position
	_friendly_name_label.position = _position_godot_space + Vector3(0.0, _static_body.scale.y / 2.0 + 1.5, 0.0)
	
	# Update outline material scaling
	_outline_mat.set_shader_parameter("thickness_scaling", Vector3(1.0, 1.0, 1.0) / _static_body.scale)
	
	print("DirectPoints voxel renderer dimensions updated: ", new_dimensions)

func update_visualization_data(visualization_data: PackedByteArray) -> void:
	# This method handles legacy SVO data for backward compatibility
	# The main rendering now uses _on_received_direct_neural_points
	print("⚡ DPR RENDERER: Received legacy Type 10 (SVO) data (", visualization_data.size(), " bytes) - clearing points for compatibility")
	
	# For now, clear all points if we receive SVO data
	_clear_all_neurons()

func _on_received_direct_neural_points(points_data: PackedByteArray) -> void:
	"""Handle Type 11 direct neural points data"""
	print("⚡ DPR RENDERER: Processing Type 11 (Direct Neural Points) data (", points_data.size(), " bytes)")
	
	if points_data.size() < 4:
		_clear_all_neurons()
		return
	
	# Decode number of points (first 4 bytes, little endian uint32)
	var point_count = points_data.decode_u32(0)
	
	if point_count == 0:
		_clear_all_neurons()
		return
	
	# Limit points for performance
	var actual_point_count = min(point_count, _max_neurons)
	if actual_point_count != point_count:
		print("   ⚠️ DPR: Limiting to ", actual_point_count, " voxels for performance (received ", point_count, ")")
	
	# Each point is 16 bytes: x(4), y(4), z(4), potential(4) as float32
	var expected_data_size = 4 + (actual_point_count * 16)
	if points_data.size() < expected_data_size:
		print("   ❌ DPR: Insufficient data - expected ", expected_data_size, " bytes, got ", points_data.size())
		_clear_all_neurons()
		return
	
	# Update MultiMesh instance count
	_multi_mesh.instance_count = actual_point_count
	_current_neuron_count = actual_point_count
	
	# Process each neuron point
	var data_offset = 4  # Skip the point count
	for i in range(actual_point_count):
		# Extract point data (x, y, z, potential as float32)
		var x = points_data.decode_float(data_offset)
		var y = points_data.decode_float(data_offset + 4)
		var z = points_data.decode_float(data_offset + 8)
		var potential = points_data.decode_float(data_offset + 12)
		
		# Convert FEAGI coordinates to Godot space
		var godot_pos = Vector3(x, y, _dimensions.z - z - 1)  # Flip Z axis for Godot
		
		# Create transform for this neuron instance
		var transform = Transform3D()
		transform.origin = godot_pos
		
		# Scale based on potential (0.5 to 1.5 scale range)
		var scale_factor = 0.5 + (potential * 1.0)
		scale_factor = clamp(scale_factor, 0.1, 2.0)
		transform = transform.scaled(Vector3.ONE * scale_factor)
		
		# Set instance transform
		_multi_mesh.set_instance_transform(i, transform)
		
		# Set instance color based on potential
		var color = _potential_to_color(potential)
		_multi_mesh.set_instance_color(i, color)
		
		data_offset += 16
	
	print("   ✅ DPR: Rendered ", actual_point_count, " neuron voxels with direct point data")

func _potential_to_color(potential: float) -> Color:
	"""Convert neuron potential to visualization color"""
	# Clamp potential to reasonable range
	potential = clamp(potential, 0.0, 1.0)
	
	# Color gradient: Blue (low) -> Cyan -> Green -> Yellow -> Red (high)
	if potential < 0.25:
		# Blue to Cyan
		var t = potential / 0.25
		return Color.BLUE.lerp(Color.CYAN, t)
	elif potential < 0.5:
		# Cyan to Green
		var t = (potential - 0.25) / 0.25
		return Color.CYAN.lerp(Color.GREEN, t)
	elif potential < 0.75:
		# Green to Yellow
		var t = (potential - 0.5) / 0.25
		return Color.GREEN.lerp(Color.YELLOW, t)
	else:
		# Yellow to Red
		var t = (potential - 0.75) / 0.25
		return Color.YELLOW.lerp(Color.RED, t)

func _clear_all_neurons() -> void:
	"""Clear all neuron voxel instances"""
	_multi_mesh.instance_count = 0
	_current_neuron_count = 0

func world_godot_position_to_neuron_coordinate(world_godot_position: Vector3) -> Vector3i:
	"""Convert world position to neuron coordinate"""
	const EPSILON: float = 1e-6
	world_godot_position -= _static_body.position
	world_godot_position += _static_body.scale / 2
	
	var neuron_coord = Vector3i(
		floori(world_godot_position.x - EPSILON),
		floori(world_godot_position.y - EPSILON), 
		floori(world_godot_position.z - EPSILON)
	)
	
	# Flip Z axis and clamp to dimensions
	neuron_coord.z = _dimensions.z - neuron_coord.z - 1
	neuron_coord = Vector3i(
		clampi(neuron_coord.x, 0, _dimensions.x - 1),
		clampi(neuron_coord.y, 0, _dimensions.y - 1),
		clampi(neuron_coord.z, 0, _dimensions.z - 1)
	)
	
	return neuron_coord

func does_world_position_map_to_neuron_coordinate(world_position: Vector3) -> bool:
	"""Check if world position is within the cortical area bounds"""
	var local_pos = world_position - _static_body.position
	var half_scale = _static_body.scale / 2
	
	return (local_pos.x >= -half_scale.x and local_pos.x <= half_scale.x and
			local_pos.y >= -half_scale.y and local_pos.y <= half_scale.y and
			local_pos.z >= -half_scale.z and local_pos.z <= half_scale.z)

func set_cortical_area_mouse_over_highlighting(is_highlighted: bool) -> void:
	_is_hovered_over = is_highlighted
	_update_cortical_area_outline()

func set_cortical_area_selection(is_selected: bool) -> void:
	_is_selected = is_selected
	_update_cortical_area_outline()

func set_highlighted_neurons(neuron_coordinates: Array[Vector3i]) -> void:
	_highlighted_neurons = neuron_coordinates.duplicate()
	_update_neuron_highlighting()

func set_neuron_selections(neuron_coordinates: Array[Vector3i]) -> void:
	_selected_neurons = neuron_coordinates.duplicate()
	_update_neuron_selection()

func clear_all_neuron_highlighting() -> void:
	_highlighted_neurons.clear()
	_update_neuron_highlighting()

func clear_all_neuron_selection() -> void:
	_selected_neurons.clear()
	_update_neuron_selection()

func _update_cortical_area_outline() -> void:
	"""Update the cortical area outline visibility and color"""
	var show_outline = _is_hovered_over or _is_selected
	_outline_mesh_instance.visible = show_outline
	
	if not show_outline:
		return
	
	var color: Color
	var alpha: float
	
	if _is_hovered_over and _is_selected:
		color = cortical_area_outline_both_color
		alpha = cortical_area_outline_both_alpha
	elif _is_hovered_over:
		color = cortical_area_outline_mouse_over_color
		alpha = cortical_area_outline_mouse_over_alpha
	else:
		color = cortical_area_outline_select_color
		alpha = cortical_area_outline_select_alpha
	
	_outline_mat.set_shader_parameter("outline_color", Vector4(color.r, color.g, color.b, alpha))

func _update_neuron_highlighting() -> void:
	"""Update highlighting for specific neurons"""
	# TODO: Implement neuron-specific highlighting
	# For now, this would require modifying the MultiMesh instance colors
	# Could be implemented by tracking highlighted neurons and updating their colors
	pass

func _update_neuron_selection() -> void:
	"""Update selection for specific neurons"""
	# TODO: Implement neuron-specific selection
	# Similar to highlighting, would modify MultiMesh instance properties
	pass 
