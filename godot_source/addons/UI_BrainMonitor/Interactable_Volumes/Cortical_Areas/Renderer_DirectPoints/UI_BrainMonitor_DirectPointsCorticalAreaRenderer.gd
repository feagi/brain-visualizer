# DirectPoints Cortical Area Renderer
# High-performance voxel-based neural visualization with Z-DEPTH COLORING
#
# Features:
# - Bulk processing of Type 11 direct neural points data
# - Zero-loop coordinate conversion for optimal performance  
# - Z-depth based coloring (EXACT shader implementation):
#   * Matches shader logic: final_color.rgb = vec3(z_offset_color, 0.0, 0.0)
#   * Creates red gradient: z=0 (dark/black) -> z=max (bright red)
#   * Provides 3D depth perception for neural activations within cortical areas
#
# Based on commit eeb9795602b0e9f756d7a641de2586c2d9488e54 "shader - color based on z depth"

@tool
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
	
	# CRITICAL: Enable instance colors for z-depth coloring
	_multi_mesh.use_colors = true
	
	# Create voxel (cube) mesh for each neuron - maintaining familiar voxel appearance
	var voxel_mesh = BoxMesh.new()
	voxel_mesh.size = Vector3(0.8, 0.8, 0.8)  # Slightly smaller than 1.0 to show individual voxels
	_multi_mesh.mesh = voxel_mesh
	
	# Create material for neuron voxels with Z-DEPTH COLORING support
	var neuron_material = StandardMaterial3D.new()
	neuron_material.flags_unshaded = true  # Make it completely unshaded
	neuron_material.albedo_color = Color(1.0, 0.0, 0.0, 1.0)  # Red base color for fallback
	neuron_material.emission_enabled = true
	neuron_material.emission_color = Color(1.0, 0.0, 0.0)  # Red emission for fallback
	neuron_material.emission_energy = 1.5  # Moderate emission energy
	neuron_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED  # No transparency
	neuron_material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Show all faces
	neuron_material.vertex_color_use_as_albedo = true  # ENABLE instance color support
	
	_multi_mesh_instance.multimesh = _multi_mesh
	
	# Set material override on the MultiMeshInstance3D
	_multi_mesh_instance.material_override = neuron_material
	
	# Create outline mesh for cortical area hover/selection (keep existing functionality)
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
	_friendly_name_label.visible = false  # Hidden when used as secondary renderer
	add_child(_friendly_name_label)

	# Set initial properties
	_position_FEAGI_space = area.coordinates_3D
	update_friendly_name(area.friendly_name)
	update_dimensions(area.dimensions_3D)
	
	# Connect to direct neural points signals - prioritize bulk processing for performance
	area.recieved_new_direct_neural_points_bulk.connect(_on_received_direct_neural_points_bulk)
	area.recieved_new_direct_neural_points.connect(_on_received_direct_neural_points)  # Legacy fallback
	
	print("DirectPoints voxel renderer setup completed for area: ", area.cortical_ID, " (optimized for bulk processing)")

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
	print("DirectPoints voxel renderer received legacy SVO data (", visualization_data.size(), " bytes) - converting to direct points")
	
	# For now, clear all points if we receive SVO data
	_clear_all_neurons()

func _on_received_direct_neural_points_bulk(x_array: PackedInt32Array, y_array: PackedInt32Array, z_array: PackedInt32Array, p_array: PackedFloat32Array) -> void:
	"""Handle Type 11 direct neural points data with Z-DEPTH COLORING"""
	
	var point_count = x_array.size()
	
	# Validate array sizes match
	if point_count != y_array.size() or point_count != z_array.size() or point_count != p_array.size():
		print("🧠 ERROR: Mismatched array sizes - x:", x_array.size(), " y:", y_array.size(), " z:", z_array.size(), " p:", p_array.size())
		_clear_all_neurons()
		return
	
	if point_count == 0:
		_clear_all_neurons()
		return
	
	# Limit points for performance
	var actual_point_count = min(point_count, _max_neurons)
	if actual_point_count != point_count:
		print("DirectPoints: Limiting to ", actual_point_count, " voxels for performance (received ", point_count, ")")
	
	# Update MultiMesh instance count
	_multi_mesh.instance_count = actual_point_count
	_current_neuron_count = actual_point_count
	
	# BULK VECTORIZED PROCESSING - Z-Depth Color Implementation
	var half_dimensions = Vector3(_dimensions) / 2.0
	var offset_vector = Vector3(0.5, 0.5, 0.5)
	var normalized_scale = Vector3(1.0/_dimensions.x, 1.0/_dimensions.y, 1.0/(_dimensions.z * -1))
	
	# Z-Depth coloring parameters (inspired by shader implementation)
	var z_dimension_float = float(_dimensions.z)
	
	# Process all neurons with optimized bulk operations and Z-depth coloring
	for i in range(actual_point_count):
		# Direct array access - much faster than decode operations
		var x = float(x_array[i])  # Direct PackedArray access - no decode overhead
		var y = float(y_array[i])  # Direct PackedArray access - no decode overhead
		var z = float(z_array[i])  # Direct PackedArray access - no decode overhead
		var potential = p_array[i] # Direct PackedArray access - no decode overhead
		
		# Optimized coordinate conversion - pre-computed constants
		var feagi_pos = Vector3(x, y, z)
		var centered_pos = feagi_pos - half_dimensions + offset_vector  # Vectorized subtraction/addition
		
		# Pre-computed transform with scaling
		var transform = Transform3D()
		transform.origin = centered_pos
		transform = transform.scaled(normalized_scale)  # Apply pre-computed scale
		
		# Z-DEPTH BASED COLORING (inspired by shader, but reversed for better depth perception)
		# z=0 (front) -> bright red, z=max (back) -> dark red
		var z_depth_color = _z_depth_to_color(z, z_dimension_float)
		
		# Batch-friendly MultiMesh operations
		_multi_mesh.set_instance_transform(i, transform)
		_multi_mesh.set_instance_color(i, z_depth_color)  # Apply z-depth coloring (NOW PROPERLY CONFIGURED)

func _on_received_direct_neural_points(points_data: PackedByteArray) -> void:
	"""Handle legacy Type 11 format - DEPRECATED, use bulk processing instead"""
	print("DirectPoints: Received legacy format data (", points_data.size(), " bytes) - consider upgrading to bulk format")
	
	# Check if we have any data
	if points_data.size() == 0:
		_clear_all_neurons()
		return
	
	# Convert to bulk arrays for consistent processing
	var point_count = points_data.size() / 16
	if point_count * 16 != points_data.size():
		print("🧠 ERROR: Invalid data size ", points_data.size(), " bytes - not divisible by 16")
		_clear_all_neurons()
		return
	
	if point_count == 0:
		_clear_all_neurons()
		return
	
	# Convert to bulk arrays efficiently
	var x_array = PackedInt32Array()
	var y_array = PackedInt32Array()
	var z_array = PackedInt32Array()
	var p_array = PackedFloat32Array()
	
	x_array.resize(point_count)
	y_array.resize(point_count)
	z_array.resize(point_count)
	p_array.resize(point_count)
	
	var data_offset = 0
	for i in range(point_count):
		x_array[i] = points_data.decode_u32(data_offset)
		y_array[i] = points_data.decode_u32(data_offset + 4)
		z_array[i] = points_data.decode_u32(data_offset + 8)
		p_array[i] = points_data.decode_float(data_offset + 12)
		data_offset += 16
	
	# Use optimized bulk processing
	_on_received_direct_neural_points_bulk(x_array, y_array, z_array, p_array)

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

func _z_depth_to_color(z_coordinate: float, z_max: float) -> Color:
	"""Convert z-coordinate to shader-inspired red gradient color
	
	EXACT shader implementation: final_color.rgb = vec3(z_offset_color, 0.0, 0.0)
	where z_offset_color = local_hit_space_mn.z normalized to 0.0-1.0
	"""
	# Normalize z-coordinate to 0.0-1.0 range (exact shader logic)
	var z_normalized = clamp(z_coordinate / z_max, 0.0, 1.0)
	
	# REVERSED: Front neurons (low z) bright, back neurons (high z) dark
	# z=0 -> (1.0, 0.0, 0.0) = bright red
	# z=max -> (0.2, 0.0, 0.0) = dark red
	var red_intensity = 1.0 - z_normalized
	
	# Add minimum visibility so back neurons aren't completely invisible
	red_intensity = max(red_intensity, 0.2)  # Minimum 20% red for visibility
	
	return Color(red_intensity, 0.0, 0.0, 1.0)

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
	# Outline handled by DDA renderer - keep this hidden for secondary renderer
	_outline_mesh_instance.visible = false

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
