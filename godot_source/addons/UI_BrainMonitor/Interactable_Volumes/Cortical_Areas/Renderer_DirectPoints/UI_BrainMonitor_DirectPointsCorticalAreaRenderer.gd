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
const MEMORY_JELLO_MAT_PATH: StringName = "res://addons/UI_BrainMonitor/Interactable_Volumes/Cortical_Areas/Renderer_DirectPoints/MemoryJelloMaterial.tres"
const POWER_NEON_MAT_PATH: StringName = "res://addons/UI_BrainMonitor/Interactable_Volumes/Cortical_Areas/Renderer_DirectPoints/PowerNeonMaterial.tres"
const TESLA_COIL_MAT_PATH: StringName = "res://addons/UI_BrainMonitor/Interactable_Volumes/Cortical_Areas/Renderer_DirectPoints/TeslaCoilMaterial.tres"

# Rendering components
var _static_body: StaticBody3D
var _multi_mesh_instance: MultiMeshInstance3D
var _multi_mesh: MultiMesh
var _outline_mesh_instance: MeshInstance3D
var _outline_mat: ShaderMaterial
var _friendly_name_label: Label3D

# Cortical area properties
var _cortical_area_type: AbstractCorticalArea.CORTICAL_AREA_TYPE
var _cortical_area_id: String

# State tracking
var _is_hovered_over: bool = false
var _is_selected: bool = false
var _current_neuron_count: int = 0
var _max_neurons: int = 10000  # Performance limit

# Highlight and selection tracking
var _highlighted_neurons: Array[Vector3i] = []
var _selected_neurons: Array[Vector3i] = []

# Timer for neuron firing visibility timeout
var _visibility_timer: Timer
var _neuron_display_start_time: float = 0.0

# Power cone firing animation
var _power_material: ShaderMaterial
var _firing_tween: Tween

# Tesla coil electrical spikes for power cone hover effect
var _tesla_coil_spikes: Array[MeshInstance3D] = []
var _tesla_coil_material: ShaderMaterial
var _is_tesla_coil_active: bool = false
var _tesla_coil_tweens: Array[Tween] = []  # Store active tweens to stop them later

func setup(area: AbstractCorticalArea) -> void:
	# Store cortical area properties for later use
	_cortical_area_type = area.cortical_type
	_cortical_area_id = area.cortical_ID
	
	# Create static body for collision detection
	_static_body = StaticBody3D.new()
	_static_body.name = "DirectPointsBody"
	add_child(_static_body)
	
	# Create collision shape for the cortical area volume
	var collision_shape = CollisionShape3D.new()
	if area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY:
		var sphere_shape = SphereShape3D.new()
		sphere_shape.radius = 1.5  # Match the 3x larger visual sphere
		collision_shape.shape = sphere_shape
		print("   🔮 Created 3x larger sphere collision for memory cortical area")
	elif area.cortical_ID == "_power":
		var cylinder_shape = CylinderShape3D.new()
		cylinder_shape.height = 6.0  # 3x larger cone height
		cylinder_shape.radius = 3.0  # 3x larger base radius
		collision_shape.shape = cylinder_shape
		print("   ⚡ Created 3x larger cylinder collision for power cortical area")
	elif area.cortical_ID == "_death" or _should_use_png_icon(area):
		var box_shape = BoxShape3D.new()
		box_shape.size = Vector3(3.0, 3.0, 1.0)  # Larger depth for better click detection
		collision_shape.shape = box_shape
		print("   🖼️ Created billboard collision for PNG icon cortical area: ", area.cortical_ID)
		print("   📏 Collision size: ", box_shape.size)
	else:
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
	# For power areas, we don't want individual neuron cubes since the cone shows firing animation
	if area.cortical_ID == "_power":
		# Use a very small invisible mesh for power areas (firing animation is on the cone itself)
		var invisible_mesh = BoxMesh.new()
		invisible_mesh.size = Vector3(0.01, 0.01, 0.01)  # Tiny invisible voxels
		_multi_mesh.mesh = invisible_mesh
		print("   ⚡ Power area uses invisible neuron voxels - firing shown on cone!")
	else:
		var voxel_mesh = BoxMesh.new()
		voxel_mesh.size = Vector3(0.8, 0.8, 0.8)  # Slightly smaller than 1.0 to show individual voxels
		_multi_mesh.mesh = voxel_mesh
		print("   📦 Standard area uses visible neuron cube voxels")
	
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
	
	# Create outline mesh for cortical area hover/selection
	_outline_mesh_instance = MeshInstance3D.new()
	_outline_mesh_instance.name = "CorticalAreaOutline"
	
	# Use different meshes based on cortical area type/ID
	if area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY:
		var sphere_mesh = SphereMesh.new()
		sphere_mesh.radius = 1.5  # 3x larger: 0.5 * 3 = 1.5
		sphere_mesh.height = 3.0  # 3x larger: 1.0 * 3 = 3.0
		sphere_mesh.radial_segments = 16  # Good balance of quality vs performance
		sphere_mesh.rings = 8
		_outline_mesh_instance.mesh = sphere_mesh
		print("   🔮 Created 3x larger sphere outline for memory cortical area")
	elif area.cortical_ID == "_power":
		var cone_mesh = CylinderMesh.new()
		cone_mesh.top_radius = 0.0  # Point at the top for cone shape
		cone_mesh.bottom_radius = 3.0  # 3x larger: 1.0 * 3 = 3.0
		cone_mesh.height = 6.0  # 3x larger: 2.0 * 3 = 6.0
		cone_mesh.radial_segments = 16  # Smoother cone for larger size
		cone_mesh.rings = 1  # Simple cone structure
		_outline_mesh_instance.mesh = cone_mesh
		print("   ⚡ Created 3x larger CONE outline for power cortical area - NO CUBE!")
	else:
		var box_mesh = BoxMesh.new()
		box_mesh.size = Vector3.ONE
		_outline_mesh_instance.mesh = box_mesh
		print("   📦 Created standard BOX outline for cortical area: ", area.cortical_ID)
	# Use different materials based on cortical area type/ID
	if area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY:
		# Use custom jello material for memory spheres
		var jello_mat = load(MEMORY_JELLO_MAT_PATH).duplicate()
		_outline_mesh_instance.material_override = jello_mat
		_outline_mesh_instance.visible = true  # Always visible for memory spheres
		_outline_mat = null  # Memory areas don't use the outline shader material
		print("   🔮 Memory sphere uses custom jello material, always visible")
	elif area.cortical_ID == "_power":
		# Use custom neon blue material for power cone
		_power_material = load(POWER_NEON_MAT_PATH).duplicate()
		_outline_mesh_instance.material_override = _power_material
		_outline_mesh_instance.visible = true  # Always visible for power cone
		_outline_mat = null  # Power areas don't use the outline shader material
		
		# Create tween for firing animation
		_firing_tween = create_tween()
		
		# Create tesla coil electrical spikes for hover effect
		_create_tesla_coil_spikes()
		
		print("   ⚡ Power cone uses custom red material with firing animation and tesla coil spikes, always visible")
	elif area.cortical_ID == "_death" or _should_use_png_icon(area):
		# Create PNG icon billboard for special cortical areas
		_create_png_icon_billboard(area)
		# Still need outline mesh for PNG areas (invisible but needed for structure)
		_outline_mesh_instance.mesh = BoxMesh.new()
		_outline_mesh_instance.visible = false  # Hidden for PNG areas
		print("   🖼️ PNG icon area setup complete for: ", area.cortical_ID)
	else:
		# Use standard outline material for other cortical areas
		_outline_mat = load(OUTLINE_MAT_PATH).duplicate()
		_outline_mesh_instance.material_override = _outline_mat
		_outline_mesh_instance.visible = false  # Hidden by default for other types
	
	_static_body.add_child(_outline_mesh_instance)
	
	# Create friendly name label
	_friendly_name_label = Label3D.new()
	_friendly_name_label.name = "AreaNameLabel"
	_friendly_name_label.font_size = 192
	_friendly_name_label.modulate = Color.WHITE
	# Memory, power, and PNG icon areas should show their label since they're primary renderers
	if area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY:
		_friendly_name_label.visible = true  # Show label for memory areas
		print("   🔮 Memory sphere label set to visible")
	elif area.cortical_ID == "_power":
		_friendly_name_label.visible = true  # Show label for power areas
		print("   ⚡ Power cone label set to visible")
	elif area.cortical_ID == "_death" or _should_use_png_icon(area):
		_friendly_name_label.visible = true  # Show label for PNG icon areas
		print("   🖼️ PNG icon area label set to visible for: ", area.cortical_ID)
		# Position label above the PNG icon (icon is at y=2.0, label should be at y=4.5 for proper separation)
		_friendly_name_label.position = Vector3(0.0, 4.5, 0.0)
		print("   📍 PNG icon label positioned at: ", _friendly_name_label.position)
	else:
		_friendly_name_label.visible = false  # Hidden when used as secondary renderer
	add_child(_friendly_name_label)

	# Set initial properties
	_position_FEAGI_space = area.coordinates_3D
	update_friendly_name(area.friendly_name)
	update_dimensions(area.dimensions_3D)
	
	# Connect to direct neural points signals - prioritize bulk processing for performance
	area.recieved_new_direct_neural_points_bulk.connect(_on_received_direct_neural_points_bulk)
	area.recieved_new_direct_neural_points.connect(_on_received_direct_neural_points)  # Legacy fallback
	
	# Connect to memory area stats updates for dynamic sizing
	if area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY:
		FeagiCore.feagi_local_cache.memory_area_stats_updated.connect(_on_memory_area_stats_updated)
		print("   🔮 Connected to memory area stats updates for dynamic sizing")
		
		# Apply initial sizing if stats are already available
		if FeagiCore.feagi_local_cache.memory_area_stats.has(_cortical_area_id):
			var area_stats = FeagiCore.feagi_local_cache.memory_area_stats[_cortical_area_id]
			if area_stats.has("neuron_count"):
				var neuron_count = int(area_stats["neuron_count"])
				print("   🔮 Applying initial memory sphere size: ", neuron_count, " neurons")
				_update_memory_sphere_size(neuron_count)
	
	# Setup visibility timer for neuron firing timeout
	_visibility_timer = Timer.new()
	_visibility_timer.name = "NeuronVisibilityTimer"
	_visibility_timer.one_shot = true
	_visibility_timer.timeout.connect(_on_visibility_timeout)
	add_child(_visibility_timer)
	
	print("DirectPoints voxel renderer setup completed for area: ", area.cortical_ID, " (optimized for bulk processing)")

func update_friendly_name(new_name: String) -> void:
	_friendly_name_label.text = new_name

func update_position_with_new_FEAGI_coordinate(new_FEAGI_coordinate_position: Vector3i) -> void:
	super(new_FEAGI_coordinate_position)
	_static_body.position = _position_godot_space
	_outline_mesh_instance.position = Vector3.ZERO  # Relative to static body
	
	# Update friendly name position (but not for PNG icon areas - they have custom positioning)
	if not _should_use_png_icon_by_id(_cortical_area_id):
		_friendly_name_label.position = _position_godot_space + Vector3(0.0, _static_body.scale.y / 2.0 + 1.5, 0.0)
	else:
		# PNG icon areas keep their custom label positioning (above the icon)
		_friendly_name_label.position = Vector3(0.0, 4.5, 0.0)
		print("   📍 Maintained PNG icon label position at: ", _friendly_name_label.position)

func update_dimensions(new_dimensions: Vector3i) -> void:
	super(new_dimensions)
	
	# Update static body scale and position
	_static_body.scale = _dimensions
	_static_body.position = _position_godot_space
	
	# Update collision shape size (but preserve custom sizes for special areas)
	var collision_shape = _static_body.get_child(0) as CollisionShape3D
	if collision_shape and collision_shape.shape is BoxShape3D:
		# PNG icon areas keep their custom collision size
		if _should_use_png_icon_by_id(_cortical_area_id):
			(collision_shape.shape as BoxShape3D).size = Vector3(3.0, 3.0, 1.0)  # Maintain PNG icon collision
			print("   📏 Maintained PNG icon collision size: ", (collision_shape.shape as BoxShape3D).size)
		else:
			(collision_shape.shape as BoxShape3D).size = Vector3.ONE  # Will be scaled by static_body
	
	# Update outline mesh size
	_outline_mesh_instance.scale = _dimensions
	
	# Update friendly name position (but not for PNG icon areas - they have custom positioning)
	if not _should_use_png_icon_by_id(_cortical_area_id):
		_friendly_name_label.position = _position_godot_space + Vector3(0.0, _static_body.scale.y / 2.0 + 1.5, 0.0)
	else:
		# PNG icon areas keep their custom label positioning (above the icon)
		_friendly_name_label.position = Vector3(0.0, 4.5, 0.0)
		print("   📍 Maintained PNG icon label position at: ", _friendly_name_label.position)
	
	# Update outline material scaling (only for non-memory areas that use shader materials)
	if _outline_mat != null:
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
	# Received new neuron data - restarting timer
	
	# Trigger power cone firing animation if this is the power cortical area
	if point_count > 0:
		_trigger_power_firing_animation()
	
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
	
	# Start visibility timer to clear neurons after simulation_timestep
	_start_visibility_timer()
	
	# Make power cone use firing colors when neural activity occurs
	if _cortical_area_id == "_power" and _power_material:
		# print("   ⚡ Power cone becoming active - using firing colors")  # Suppressed to reduce log spam
		_power_material.set_shader_parameter("albedo_color", Color(1, 0.1, 0.1, 0.8))  # Bright red for firing
		_power_material.set_shader_parameter("emission_color", Color(1, 0.2, 0.2, 1))  # Bright red emission
		_power_material.set_shader_parameter("emission_energy", 1.5)  # Full glow

func _on_received_direct_neural_points(points_data: PackedByteArray) -> void:
	"""Handle legacy Type 11 format - DEPRECATED, use bulk processing instead"""
	print("DirectPoints: Received legacy format data (", points_data.size(), " bytes) - consider upgrading to bulk format")
	
	# Check if we have any data
	if points_data.size() == 0:
		_clear_all_neurons()
		return
	
	# Trigger power cone firing animation if this is the power cortical area
	_trigger_power_firing_animation()
	
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

func _start_visibility_timer() -> void:
	"""Start the visibility timer using simulation_timestep from cache"""
	if not FeagiCore or not FeagiCore.feagi_local_cache:
		print("🔥 DirectPoints: Cannot start timer - FeagiCore or cache not available")
		return
	
	var simulation_timestep = FeagiCore.feagi_local_cache.simulation_timestep
	# Starting visibility timer with cached simulation_timestep
	
	# Stop existing timer if running
	if _visibility_timer.time_left > 0:
		# Stopped existing timer
		_visibility_timer.stop()
	
	# Record when neurons started displaying (using engine ticks for precision)
	_neuron_display_start_time = Time.get_ticks_msec() / 1000.0
	# Neurons started displaying
	
	# Start timer with simulation_timestep duration
	_visibility_timer.wait_time = simulation_timestep
	_visibility_timer.start()
	# Timer started with simulation_timestep duration

func _on_visibility_timeout() -> void:
	"""Called when the visibility timer expires - clear all neurons"""
	var current_time = Time.get_ticks_msec() / 1000.0
	var actual_duration = current_time - _neuron_display_start_time
	
	# Visibility timer expired - clearing neurons via timeout
	_clear_all_neurons()
	
	# Make power cone use default cortical mesh color when no neural activity
	if _cortical_area_id == "_power" and _power_material:
		# print("   ⚡ Power cone becoming inactive - using default cortical mesh color")  # Suppressed to reduce log spam
		_power_material.set_shader_parameter("albedo_color", Color(0.172451, 0.315246, 0.861982, 0.8))  # Light blue like cortical meshes
		_power_material.set_shader_parameter("emission_color", Color(0.172451, 0.315246, 0.861982, 1.0))  # Light blue emission
		_power_material.set_shader_parameter("emission_energy", 0.3)  # Subtle glow

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
	print("   🔍 DEBUG: set_cortical_area_mouse_over_highlighting called with is_highlighted=", is_highlighted, " for area: ", _cortical_area_id)
	_is_hovered_over = is_highlighted
	_update_cortical_area_outline()
	
	# Activate tesla coil effect for power areas on hover
	if _cortical_area_id == "_power":
		print("   🔍 DEBUG: Power area detected, calling _set_tesla_coil_active")
		_set_tesla_coil_active(is_highlighted)

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
	# Memory and power areas should always stay visible, others handled by DDA renderer
	if _cortical_area_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY:
		_outline_mesh_instance.visible = true  # Always visible for memory spheres
	elif _cortical_area_id == "_power":
		_outline_mesh_instance.visible = true  # Always visible for power cone
	else:
		_outline_mesh_instance.visible = false  # Outline handled by DDA renderer for others

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

func _trigger_power_firing_animation() -> void:
	"""Trigger the red glow animation from bottom to tip of power cone"""
	if _cortical_area_id != "_power" or _power_material == null:
		return
	
	# print("   ⚡ Triggering power cone firing animation!")  # Suppressed to reduce log spam
	
	# Make power cone use firing colors when firing animation starts
	_power_material.set_shader_parameter("albedo_color", Color(1, 0.1, 0.1, 0.8))  # Bright red for firing
	_power_material.set_shader_parameter("emission_color", Color(1, 0.2, 0.2, 1))  # Bright red emission
	_power_material.set_shader_parameter("emission_energy", 1.5)  # Full glow
	
	# Create a new tween for this animation
	_firing_tween = create_tween()
	
	# Reset firing progress to 0
	_power_material.set_shader_parameter("firing_progress", 0.0)
	
	# Animate firing progress from 0.0 to 1.0 over 0.5 seconds
	_firing_tween.tween_method(
		func(progress: float): _power_material.set_shader_parameter("firing_progress", progress),
		0.0,
		1.0,
		0.5
	)
	
	# After animation completes, fade out the effect
	_firing_tween.tween_method(
		func(progress: float): _power_material.set_shader_parameter("firing_progress", progress),
		1.0,
		0.0,
		0.3
	)

func _create_tesla_coil_spikes() -> void:
	"""Create electrical spikes that emanate from the power cone tip"""
	if _cortical_area_id != "_power":
		return
	
	print("   ⚡ Creating tesla coil electrical spikes for power cone!")
	
	# Load tesla coil material
	_tesla_coil_material = load(TESLA_COIL_MAT_PATH).duplicate()
	
	# Create multiple electrical spikes around the cone tip
	var spike_count = 8  # Number of electrical spikes
	var cone_height = 6.0  # Match the cone height
	var tip_position = Vector3(0, cone_height * 0.45, 0)  # Much closer to actual tip (90% up the cone)
	
	for i in range(spike_count):
		var spike = MeshInstance3D.new()
		spike.name = "TeslaSpike_" + str(i)
		
		# Create lightning-like electrical spark
		var spike_mesh = CylinderMesh.new()
		spike_mesh.top_radius = 0.01  # Very thin at tip (lightning end)
		spike_mesh.bottom_radius = 0.08  # Thicker at base (near cone tip)
		spike_mesh.height = randf_range(1.5, 3.5)  # Random lengths for variety
		spike_mesh.radial_segments = 6
		spike_mesh.rings = 3  # More rings for better lightning shape
		
		spike.mesh = spike_mesh
		
		# Create electrical lightning material
		var lightning_material = StandardMaterial3D.new()
		lightning_material.albedo_color = Color(0.8, 0.9, 1.0, 0.9)  # Blue-white electrical color
		lightning_material.emission_enabled = true
		lightning_material.emission_color = Color(0.9, 0.95, 1.0)  # Bright electrical glow
		lightning_material.emission_energy = 3.0  # Very bright
		lightning_material.flags_unshaded = true
		lightning_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		lightning_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD  # Additive for glow effect
		spike.material_override = lightning_material
		
		# Position lightning sparks shooting out from cone tip in random directions
		var base_angle = (i / float(spike_count)) * TAU  # Evenly distribute around tip
		var random_angle_offset = randf_range(-1.0, 1.0)  # Increased randomness for more spread
		var final_angle = base_angle + random_angle_offset
		
		# Random direction with some upward bias (like real tesla coil) - SPREAD OUT MORE
		var horizontal_radius = randf_range(1.5, 3.0)  # Increased from 0.8-1.5 to 1.5-3.0
		var vertical_offset = randf_range(-0.8, 1.8)  # Increased from -0.3-1.2 to -0.8-1.8
		
		var spark_direction = Vector3(
			cos(final_angle) * horizontal_radius,
			vertical_offset,
			sin(final_angle) * horizontal_radius
		).normalized()
		
		# Position spark so convergence point is at bottom third (thick end near cone tip)
		var spark_length = spike_mesh.height
		var convergence_offset = spark_length * 0.33  # Move out by 1/3 of length
		var offset_position = spark_direction.normalized() * convergence_offset
		
		spike.position = tip_position + offset_position
		spike.look_at(tip_position + spark_direction * 2.0, Vector3.UP)
		
		# Add more random rotation for wider spread and natural lightning look
		spike.rotation_degrees += Vector3(
			randf_range(-30, 30),  # Increased from -15,15
			randf_range(-45, 45),  # Increased from -30,30
			randf_range(-30, 30)   # Increased from -15,15
		)
		
		print("   🔍 DEBUG: Created spike ", i, " at position: ", spike.position, " with height: ", spike_mesh.height)
		
		# Start invisible - only show on hover
		spike.visible = false
		
		_tesla_coil_spikes.append(spike)
		_static_body.add_child(spike)
	
	print("   ⚡ Created ", spike_count, " tesla coil spikes!")

## Check if a cortical area should use PNG icon rendering
func _should_use_png_icon(area: AbstractCorticalArea) -> bool:
	# Add more cortical area IDs here that should use PNG icons
	var png_icon_areas = ["_death", "_health", "_energy", "_status"]  # Expandable list
	return area.cortical_ID in png_icon_areas

## Check if a cortical area ID should use PNG icon rendering (helper for when we only have ID)
func _should_use_png_icon_by_id(cortical_id: StringName) -> bool:
	var png_icon_areas = ["_death", "_health", "_energy", "_status"]  # Expandable list
	return cortical_id in png_icon_areas

## Create PNG icon billboard for special cortical areas
func _create_png_icon_billboard(area: AbstractCorticalArea) -> void:
	print("   🖼️ Creating PNG icon billboard for: ", area.cortical_ID)
	
	# Create a billboard mesh instance for the PNG icon
	var icon_mesh_instance = MeshInstance3D.new()
	icon_mesh_instance.name = "IconBillboard"
	
	# Create a quad mesh for the billboard
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(3.0, 3.0)  # 3x3 units billboard
	icon_mesh_instance.mesh = quad_mesh
	
	# Load PNG icon texture (with placeholder fallback)
	var icon_texture = _load_png_icon_texture(area.cortical_ID)
	
	# Create material for the billboard
	var icon_material = StandardMaterial3D.new()
	icon_material.albedo_texture = icon_texture
	icon_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	icon_material.flags_unshaded = true
	icon_material.flags_do_not_use_vertex_lighting = true
	icon_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED  # Always face camera
	icon_material.no_depth_test = true  # Always visible
	icon_material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Visible from both sides
	icon_material.albedo_color = Color.WHITE  # Ensure full color visibility
	
	print("   🎨 Created billboard material with transparency and billboard mode")
	
	# Add glow effect for special areas
	if area.cortical_ID == "_death":
		icon_material.emission_enabled = true
		icon_material.emission_color = Color(1.0, 0.2, 0.2)  # Red glow for death
		icon_material.emission_energy = 0.5
	
	icon_mesh_instance.material_override = icon_material
	icon_mesh_instance.visible = true  # Always visible
	
	# Position slightly above the cortical area center
	icon_mesh_instance.position = Vector3(0, 2.0, 0)
	
	_static_body.add_child(icon_mesh_instance)
	
	print("   ✅ PNG icon billboard created:")
	print("     📍 Position: ", icon_mesh_instance.position)
	print("     📏 Quad size: ", quad_mesh.size)
	print("     🖼️ Texture: ", icon_texture.resource_path if icon_texture else "placeholder")
	print("     👁️ Visible: ", icon_mesh_instance.visible)
	print("     🎨 Material: ", icon_material != null)

## Load PNG icon texture for cortical area
func _load_png_icon_texture(cortical_id: StringName) -> Texture2D:
	print("   🔍 Loading PNG icon for: ", cortical_id)
	
	# Try different loading approaches for better compatibility
	var texture: Texture2D = null
	var icon_path = "res://godot_source/addons/UI_BrainMonitor/Interactable_Volumes/Cortical_Areas/Renderer_DirectPoints/Icons/" + cortical_id + ".png"
	
	print("   📂 Checking path: ", icon_path)
	
	# Method 1: Try ResourceLoader.load with full error checking
	if ResourceLoader.exists(icon_path):
		print("   ✅ File exists, attempting to load...")
		var resource = ResourceLoader.load(icon_path)
		if resource != null:
			texture = resource as Texture2D
			if texture != null:
				print("   🎉 Successfully loaded PNG as Texture2D!")
				print("   📏 Texture size: ", texture.get_size())
				return texture
			else:
				print("   ❌ Resource loaded but not a Texture2D: ", typeof(resource))
		else:
			print("   ❌ ResourceLoader.load returned null")
	else:
		print("   ❌ File does not exist at path: ", icon_path)
	
	# Method 2: Try alternative path format
	var alt_path = "res://godot_source/addons/UI_BrainMonitor/Interactable_Volumes/Cortical_Areas/Renderer_DirectPoints/Icons/" + cortical_id + ".png"
	print("   🔄 Trying alternative loading method...")
	
	# Method 3: For _death specifically, try multiple path variations
	if cortical_id == "_death":
		print("   💀 Attempting _death icon load with multiple methods...")
		
		# Try different path formats (including the path from import file)
		var test_paths = [
			"res://godot_source/addons/UI_BrainMonitor/Interactable_Volumes/Cortical_Areas/Renderer_DirectPoints/Icons/_death.png",
			"res://addons/UI_BrainMonitor/Interactable_Volumes/Cortical_Areas/Renderer_DirectPoints/Icons/_death.png",  # Path from import file
			"res://.godot/imported/_death.png-ddb253cf3ef212e1e0fdb39499230091.ctex",  # Direct imported path
			"res://godot_source/addons/UI_BrainMonitor/Interactable_Volumes/Cortical_Areas/Renderer_DirectPoints/Icons/death.png"
		]
		
		for test_path in test_paths:
			print("   🔍 Testing path: ", test_path)
			if ResourceLoader.exists(test_path):
				print("   ✅ Path exists!")
				var test_resource = ResourceLoader.load(test_path)
				if test_resource != null:
					print("   📦 Resource loaded, type: ", test_resource.get_class())
					if test_resource is Texture2D:
						print("   🎉 Found working Texture2D!")
						return test_resource
				else:
					print("   ❌ Resource load returned null")
			else:
				print("   ❌ Path does not exist")
		
		# Try using preload (compile-time loading)
		print("   🔄 Attempting preload method...")
		# Note: This might cause an error if file doesn't exist, but we'll catch it
	
	print("   ❌ All loading methods failed, creating placeholder")
	return _create_placeholder_icon_texture(cortical_id)

## Create placeholder texture for cortical areas without custom icons
func _create_placeholder_icon_texture(cortical_id: StringName) -> Texture2D:
	print("   🎨 Creating placeholder texture for: ", cortical_id)
	
	# Create a simple colored image as placeholder
	var image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	
	# Choose placeholder color based on cortical area
	var placeholder_color: Color
	match cortical_id:
		"_death":
			placeholder_color = Color(1.0, 0.0, 0.0, 1.0)  # Bright red for death
		"_health":
			placeholder_color = Color(0.0, 1.0, 0.0, 1.0)  # Bright green for health
		"_energy":
			placeholder_color = Color(1.0, 1.0, 0.0, 1.0)  # Bright yellow for energy
		"_status":
			placeholder_color = Color(0.0, 0.0, 1.0, 1.0)  # Bright blue for status
		_:
			placeholder_color = Color(1.0, 0.0, 1.0, 1.0)  # Bright magenta for unknown
	
	# Fill the image with the placeholder color
	image.fill(placeholder_color)
	
	# Add a simple border
	for x in range(128):
		for y in range(128):
			if x < 4 or x >= 124 or y < 4 or y >= 124:
				image.set_pixel(x, y, Color.WHITE)
	
	# Add text indication (skull-like pattern for death, cross for others)
	if cortical_id == "_death":
		# Create a simple skull pattern
		# Eyes
		for x in range(45, 55):
			for y in range(45, 55):
				image.set_pixel(x, y, Color.BLACK)
		for x in range(75, 85):
			for y in range(45, 55):
				image.set_pixel(x, y, Color.BLACK)
		# Mouth
		for x in range(55, 75):
			for y in range(75, 85):
				image.set_pixel(x, y, Color.BLACK)
	else:
		# Simple cross pattern for other types
		for i in range(20, 108):
			image.set_pixel(64, i, Color.WHITE)  # Vertical line
			image.set_pixel(i, 64, Color.WHITE)  # Horizontal line
	
	# Create texture from image
	var texture = ImageTexture.new()
	texture.set_image(image)
	
	print("   ✅ Created placeholder texture with color: ", placeholder_color)
	return texture

func _on_memory_area_stats_updated(stats: Dictionary) -> void:
	"""Handle memory area stats updates from health check"""
	if _cortical_area_type != AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY:
		return
	
	# Check if this memory area has stats
	if _cortical_area_id not in stats:
		print("   🔮 No stats found for memory area: ", _cortical_area_id)
		return
	
	var area_stats = stats[_cortical_area_id]
	if not area_stats.has("neuron_count"):
		print("   🔮 No neuron_count in stats for memory area: ", _cortical_area_id)
		return
	
	var neuron_count = int(area_stats["neuron_count"])
	print("   🔮 Updating memory sphere size for ", _cortical_area_id, " with neuron count: ", neuron_count)
	
	# Update the sphere size based on neuron count
	_update_memory_sphere_size(neuron_count)

func _update_memory_sphere_size(neuron_count: int) -> void:
	"""Update memory sphere size based on neuron count"""
	if _cortical_area_type != AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY:
		return
	
	# Calculate size based on neuron count
	# Base size: 1.0 (normal cortical area size)
	# Scale factor: logarithmic scaling to prevent huge spheres
	var base_size = 1.0
	var scale_factor = 1.0
	
	if neuron_count > 0:
		# Logarithmic scaling: log10(neuron_count + 1) + 1
		# This gives: 0 neurons = 1.0x, 10 neurons = 2.0x, 100 neurons = 3.0x, etc.
		scale_factor = log(neuron_count + 1) / log(10) + 1.0
		# Cap the maximum size to prevent overly large spheres
		scale_factor = min(scale_factor, 5.0)  # Max 5x size
	
	var sphere_radius = base_size * scale_factor * 0.5  # 0.5 is the base radius
	var sphere_height = base_size * scale_factor * 1.0  # 1.0 is the base height
	
	print("   🔮 Memory sphere sizing: ", neuron_count, " neurons -> ", scale_factor, "x scale -> radius:", sphere_radius, " height:", sphere_height)
	
	# Update the sphere mesh
	if _outline_mesh_instance and _outline_mesh_instance.mesh is SphereMesh:
		var sphere_mesh = _outline_mesh_instance.mesh as SphereMesh
		sphere_mesh.radius = sphere_radius
		sphere_mesh.height = sphere_height
		print("   🔮 Updated memory sphere mesh size")
	
	# Update the collision shape
	if _static_body:
		var collision_shape = _static_body.get_child(0) as CollisionShape3D
		if collision_shape and collision_shape.shape is SphereShape3D:
			var sphere_shape = collision_shape.shape as SphereShape3D
			sphere_shape.radius = sphere_radius
			print("   🔮 Updated memory sphere collision size")

func _set_tesla_coil_active(active: bool) -> void:
	"""Activate or deactivate the tesla coil electrical spikes"""
	print("   🔍 DEBUG: _set_tesla_coil_active called with active=", active)
	print("   🔍 DEBUG: _cortical_area_id=", _cortical_area_id)
	print("   🔍 DEBUG: _tesla_coil_spikes.size()=", _tesla_coil_spikes.size())
	
	if _cortical_area_id != "_power":
		print("   ❌ Not a power area, skipping tesla coil")
		return
		
	if _tesla_coil_spikes.is_empty():
		print("   ❌ No tesla coil spikes created, skipping")
		return
	
	_is_tesla_coil_active = active
	
	if active:
		print("   ⚡ ACTIVATING tesla coil spikes - electrical arcs ON!")
		
		# Clear any existing tweens first
		_tesla_coil_tweens.clear()
		
		# Calculate tip position (same as in _create_tesla_coil_spikes)
		var cone_height = 6.0  # Same as the cone height
		var tip_position = Vector3(0, cone_height * 0.45, 0)  # Much closer to actual tip (90% up the cone)
		
		# Show all spikes with electrical flickering animation
		for i in range(_tesla_coil_spikes.size()):
			var spike = _tesla_coil_spikes[i]
			spike.visible = true
			
			# Create electrical flickering effect
			var flicker_tween = create_tween()
			flicker_tween.set_loops()  # Infinite flickering
			_tesla_coil_tweens.append(flicker_tween)  # Store for later cleanup
			
			# Random flickering pattern - on/off with varying intensity
			var flicker_speed = randf_range(0.05, 0.15)  # Fast flickering
			var random_freq = randf_range(20, 40)  # Capture random frequency
			flicker_tween.tween_method(
				func(intensity: float): 
					var material = spike.material_override as StandardMaterial3D
					if material:
						# Flicker between full brightness and dim
						var time_value = Time.get_ticks_msec() / 1000.0  # Convert to seconds
						var flicker_value = sin(time_value * random_freq) * 0.5 + 0.5
						material.emission_energy = 1.0 + flicker_value * 3.0
						# Occasionally make it invisible for crackling effect
						spike.visible = randf() > 0.1,  # 90% visible, 10% invisible for crackling
				0.0,
				1.0,
				flicker_speed
			)
			
			# Add subtle random movement for electrical instability
			var movement_tween = create_tween()
			movement_tween.set_loops()
			_tesla_coil_tweens.append(movement_tween)  # Store for later cleanup
			var movement_speed = randf_range(0.3, 0.8)
			var base_position = tip_position  # Capture tip_position in local scope
			var spike_index = i  # Capture loop index
			movement_tween.tween_method(
				func(t: float):
					var noise_offset = Vector3(
						sin(t * 10 + spike_index) * 0.1,
						cos(t * 8 + spike_index) * 0.05,
						sin(t * 12 + spike_index) * 0.1
					)
					spike.position = base_position + noise_offset,
				0.0,
				TAU,
				movement_speed
			)
	else:
		print("   ⚡ DEACTIVATING tesla coil spikes - electrical arcs OFF!")
		
		# Stop all active tweens to prevent infinite animation
		for tween in _tesla_coil_tweens:
			if tween != null and tween.is_valid():
				tween.kill()
		_tesla_coil_tweens.clear()
		
		# Hide all spikes
		for spike in _tesla_coil_spikes:
			spike.visible = false 
