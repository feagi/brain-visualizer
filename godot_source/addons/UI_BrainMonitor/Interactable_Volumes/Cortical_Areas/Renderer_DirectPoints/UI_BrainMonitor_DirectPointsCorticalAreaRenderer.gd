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

# Visual scale for voxel meshes (world units). Matches existing individual-voxel sizing.
const _VOXEL_VISUAL_SCALE: float = 0.8

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
var _cortical_area: AbstractCorticalArea = null  # Reference to area for accessing visualization_voxel_granularity

# Aggregated rendering mode
var _is_aggregated_mode: bool = false
var _visualization_voxel_granularity: Vector3i = Vector3i(1, 1, 1)  # Default is 1x1x1

# State tracking
var _is_hovered_over: bool = false
var _is_selected: bool = false
var _current_neuron_count: int = 0
var _warning_threshold: int = 50000  # Warn if exceeding this many neurons

# Rust processing (required - no fallback!)
var _rust_processor: Object = null  # FeagiDataDeserializer instance

# Performance settings
var _visualization_settings: VisualizationSettings = null

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

# Memory area materials for state switching
var _memory_jello_material: ShaderMaterial  # Active firing state material
var _memory_transparent_material: ShaderMaterial  # Inactive transparent state material
var _memory_activity_tween: Tween  # Smooth fade between inactive/active states

# Cached parameter targets for smooth transitions
var _memory_active_albedo: Color
var _memory_active_emission: Color
var _memory_active_emission_energy: float
var _memory_active_rim_intensity: float
var _memory_active_jello_strength: float

var _memory_inactive_albedo: Color
var _memory_inactive_emission: Color
var _memory_inactive_emission_energy: float
var _memory_inactive_rim_intensity: float
var _memory_inactive_jello_strength: float

func setup(area: AbstractCorticalArea) -> void:
	print("🧠 DIRECTPOINTS RENDERER SETUP for cortical area: %s" % area.cortical_ID)
	# Store cortical area properties for later use
	_cortical_area_type = area.cortical_type
	_cortical_area_id = area.cortical_ID
	_cortical_area = area  # Store reference for accessing visualization_voxel_granularity
	
	# Check if this area uses aggregated rendering mode
	_visualization_voxel_granularity = area.visualization_voxel_granularity
	_is_aggregated_mode = _visualization_voxel_granularity != Vector3i(1, 1, 1)
	if _is_aggregated_mode:
		print("   🔥 [%s] AGGREGATED RENDERING MODE enabled - granularity: %s" % [_cortical_area_id, _visualization_voxel_granularity])
	
	# Load visualization settings (create default if not exists)
	if ResourceLoader.exists("res://BrainVisualizer/Configs/visualization_settings.tres"):
		_visualization_settings = load("res://BrainVisualizer/Configs/visualization_settings.tres")
	else:
		_visualization_settings = VisualizationSettings.new()
	
	# Initialize Rust processor - REQUIRED, no fallback!
	if not ClassDB.class_exists("FeagiDataDeserializer"):
		push_error("🦀 CRITICAL: Rust deserializer not found! Build with: cd rust_extensions/feagi_data_deserializer && ./build.sh")
		return
	
	_rust_processor = ClassDB.instantiate("FeagiDataDeserializer")
	_warning_threshold = _visualization_settings.performance_warning_threshold
	
	print("   🦀 [%s] Rust processor initialized - unlimited neurons, warning threshold: %d" % [_cortical_area_id, _warning_threshold])
	
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
	elif AbstractCorticalArea.is_power_area(area.cortical_ID):
		var cylinder_shape = CylinderShape3D.new()
		cylinder_shape.height = 6.0  # 3x larger cone height
		cylinder_shape.radius = 3.0  # 3x larger base radius
		collision_shape.shape = cylinder_shape
		print("   ⚡ Created 3x larger cylinder collision for power cortical area")
	elif AbstractCorticalArea.is_death_area(area.cortical_ID) or _should_use_png_icon(area):
		var box_shape = BoxShape3D.new()
		box_shape.size = Vector3(3.0, 3.0, 1.0)  # Match PNG quad size; depth generous for ray hits
		collision_shape.shape = box_shape
		# Align collider center with billboard icon center (icon_mesh_instance.position.y = 2.0)
		collision_shape.position = Vector3(0.0, 2.0, 0.0)
		print("   🖼️ Created billboard collision for PNG icon cortical area: ", area.cortical_ID)
		print("   📏 Collision size: ", box_shape.size, " at offset ", collision_shape.position)
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
	# For power and memory areas, we don't want individual neuron cubes since the shape itself shows firing
	# For aggregated rendering mode, use granularity-sized boxes instead of small voxels
	if AbstractCorticalArea.is_power_area(area.cortical_ID):
		# Use a very small invisible mesh for power areas (firing animation is on the cone itself)
		var invisible_mesh = BoxMesh.new()
		invisible_mesh.size = Vector3(0.01, 0.01, 0.01)  # Tiny invisible voxels
		_multi_mesh.mesh = invisible_mesh
	elif area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY:
		# Use invisible mesh for memory areas (firing animation is on the sphere itself)
		var invisible_mesh = BoxMesh.new()
		invisible_mesh.size = Vector3(0.01, 0.01, 0.01)  # Tiny invisible voxels
		_multi_mesh.mesh = invisible_mesh
	elif _is_aggregated_mode:
		# Aggregated rendering mode: use granularity-sized boxes to represent aggregated activity
		# IMPORTANT: Rust sets instance transform scale to (1 / dimensions) and the parent _static_body scales by (dimensions),
		# so the mesh `size` here is effectively in world units. Keep it consistent with the normal voxel size.
		_apply_multimesh_mesh_for_current_granularity()
	else:
		var voxel_mesh = BoxMesh.new()
		voxel_mesh.size = Vector3(_VOXEL_VISUAL_SCALE, _VOXEL_VISUAL_SCALE, _VOXEL_VISUAL_SCALE)  # Slightly smaller than 1.0 to show individual voxels
		_multi_mesh.mesh = voxel_mesh
	
	# Create material for neuron voxels with Z-DEPTH COLORING support
	var neuron_material = StandardMaterial3D.new()
	neuron_material.flags_unshaded = true  # Make it completely unshaded
	neuron_material.albedo_color = Color(1.0, 0.0, 0.0, 1.0)  # Red base color for fallback
	neuron_material.emission_enabled = true
	neuron_material.emission = Color(1.0, 0.0, 0.0)  # Red emission for fallback
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
	elif AbstractCorticalArea.is_power_area(area.cortical_ID):
		var cone_mesh = CylinderMesh.new()
		cone_mesh.top_radius = 0.0  # Point at the top for cone shape
		cone_mesh.bottom_radius = 3.0  # 3x larger: 1.0 * 3 = 3.0
		cone_mesh.height = 6.0  # 3x larger: 2.0 * 3 = 6.0
		cone_mesh.radial_segments = 16  # Smoother cone for larger size
		cone_mesh.rings = 1  # Simple cone structure
		_outline_mesh_instance.mesh = cone_mesh
	else:
		var box_mesh = BoxMesh.new()
		box_mesh.size = Vector3.ONE
		_outline_mesh_instance.mesh = box_mesh
	# Use different materials based on cortical area type/ID
	if area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY:
		# Create both transparent and active materials for memory spheres
		_memory_jello_material = load(MEMORY_JELLO_MAT_PATH).duplicate() as ShaderMaterial
		_memory_transparent_material = _create_transparent_memory_material()
		
		# Cache active/inactive parameter targets and start in inactive state with smooth fades.
		_init_memory_material_targets()
		_apply_memory_material_inactive_state()
		_outline_mesh_instance.material_override = _memory_jello_material
		_outline_mesh_instance.visible = true  # Always visible with light blue cortical color
		_outline_mat = null  # Memory areas don't use the outline shader material
	elif AbstractCorticalArea.is_power_area(area.cortical_ID):
		# Use custom neon blue material for power cone
		_power_material = load(POWER_NEON_MAT_PATH).duplicate()
		_outline_mesh_instance.material_override = _power_material
		_outline_mesh_instance.visible = true  # Always visible for power cone
		_outline_mat = null  # Power areas don't use the outline shader material
		
		# Tween will be created when needed in animate_power_firing()
		_firing_tween = null
		
		# Create tesla coil electrical spikes for hover effect
		_create_tesla_coil_spikes()
		
		print("   ⚡ Power cone uses custom red material with firing animation and tesla coil spikes, always visible")
	elif AbstractCorticalArea.is_death_area(area.cortical_ID) or _should_use_png_icon(area):
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
	
	# Create individual plate if needed
	_create_individual_plate_if_needed(area)
	
	# Create friendly name label with high-quality MSDF rendering
	_friendly_name_label = Label3D.new()
	_friendly_name_label.name = "AreaNameLabel"
	_friendly_name_label.font_size = 512  # High resolution for crisp text at distance
	_friendly_name_label.font = load("res://BrainVisualizer/UI/GenericResources/RobotoCondensed-Bold.ttf")
	_friendly_name_label.modulate = Color.WHITE
	_friendly_name_label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_friendly_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED  # Always face camera
	_friendly_name_label.alpha_scissor_threshold = 0.5  # Clean edges
	_friendly_name_label.no_depth_test = false  # Respect depth for proper occlusion
	_friendly_name_label.render_priority = 1  # Render after most objects
	# Memory, power, and PNG icon areas should show their label since they're primary renderers
	if area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY:
		_friendly_name_label.visible = true  # Show label for memory areas
		print("   🔮 Memory sphere label set to visible")
	elif AbstractCorticalArea.is_power_area(area.cortical_ID):
		_friendly_name_label.visible = true  # Show label for power areas
		print("   ⚡ Power cone label set to visible")
	elif AbstractCorticalArea.is_death_area(area.cortical_ID) or _should_use_png_icon(area):
		_friendly_name_label.visible = true  # Show label for PNG icon areas
		print("   🖼️ PNG icon area label set to visible for: ", area.cortical_ID)
		# Position label above the PNG icon (icon is at y=2.0, label should be at y=4.5 for proper separation)
		_friendly_name_label.position = Vector3(0.0, 4.5, 0.0)
		print("   📍 PNG icon label positioned at: ", _friendly_name_label.position)
	else:
		_friendly_name_label.visible = false  # Hidden when used as secondary renderer
	# Attach label to follow movement correctly:
	# - For PNG icon areas (e.g., _death), parent to _static_body so it inherits movement
	# - For others, keep as child of this renderer and use absolute positioning updates
	if area.cortical_ID == "_death" or _should_use_png_icon(area):
		_static_body.add_child(_friendly_name_label)
	else:
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
	
	# Connect to delay_between_bursts changes to update timer duration dynamically
	# This is the authoritative source (updated from FEAGI API), not the health check cache
	if FeagiCore:
		FeagiCore.delay_between_bursts_updated.connect(_on_delay_between_bursts_changed)
		print("   ⏱️  Connected to delay_between_bursts_updated signal for dynamic updates")
	
	# Setup visibility timer for neuron firing timeout
	_visibility_timer = Timer.new()
	_visibility_timer.name = "NeuronVisibilityTimer"
	_visibility_timer.one_shot = true
	_visibility_timer.timeout.connect(_on_visibility_timeout)
	add_child(_visibility_timer)

	# Desktop WS Type11 fast-path registration:
	# UI_BrainMonitor_CorticalArea also tries to register, but we self-register here to guarantee
	# memory/power areas are registered even if scene timing/signal wiring changes.
	# This is required for:
	# - `_refresh_bv_fastpath_cache_if_needed()` (MultiMesh + dims lookup)
	# - `BV_notify_directpoints_activity()` (memory jelly animation)
	var mm := bv_get_multimesh()
	var dims := bv_get_dimensions()
	area.BV_register_directpoints_renderer(self, mm, dims)
	

func update_friendly_name(new_name: String) -> void:
	_friendly_name_label.text = new_name

func update_position_with_new_FEAGI_coordinate(new_FEAGI_coordinate_position: Vector3i) -> void:
	super(new_FEAGI_coordinate_position)
	_static_body.position = _position_godot_space
	_outline_mesh_instance.position = Vector3.ZERO  # Relative to static body
	
	# Update friendly name position (but not for PNG icon areas - they have custom positioning)
	if not _should_use_png_icon_by_id(_cortical_area_id):
		bv_update_friendly_name_label_position()
	else:
		# PNG icon areas keep their custom label positioning (above the icon)
		_friendly_name_label.position = Vector3(0.0, 4.5, 0.0)
		print("   📍 Maintained PNG icon label position at: ", _friendly_name_label.position)

func update_dimensions(new_dimensions: Vector3i) -> void:
	# Memory areas are conceptually 1x1x1 (all activity maps to (0,0,0)).
	# Force non-zero dimensions so desktop WS Type11 fast-path does not treat this as uninitialized.
	if _cortical_area_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY:
		new_dimensions = Vector3i.ONE
	super(new_dimensions)
	
	# Refresh visualization_voxel_granularity from cache and update mesh if needed.
	# (BV allows editing this at runtime; don't rely on dimension changes to refresh mesh.)
	_refresh_visualization_voxel_granularity_from_cache()
	
	# Update static body scale and position
	_static_body.scale = _dimensions
	_static_body.position = _position_godot_space
	
	# Update collision shape size (but preserve custom sizes for special areas)
	var collision_shape = _static_body.get_child(0) as CollisionShape3D
	if collision_shape and collision_shape.shape is BoxShape3D:
		# PNG icon areas keep their custom collision size
		if _should_use_png_icon_by_id(_cortical_area_id):
			(collision_shape.shape as BoxShape3D).size = Vector3(3.0, 3.0, 1.0)  # Maintain PNG icon collision
			# Keep collider centered with the icon (icon at y=2.0)
			collision_shape.position = Vector3(0.0, 2.0, 0.0)
			print("   📏 Maintained PNG icon collision size: ", (collision_shape.shape as BoxShape3D).size, " at offset ", collision_shape.position)
		else:
			(collision_shape.shape as BoxShape3D).size = Vector3.ONE  # Will be scaled by static_body
	
	# Update outline mesh size
	_outline_mesh_instance.scale = _dimensions
	
	# Update friendly name position (but not for PNG icon areas - they have custom positioning)
	if not _should_use_png_icon_by_id(_cortical_area_id):
		bv_update_friendly_name_label_position()
	else:
		# PNG icon areas keep their custom label positioning (above the icon)
		_friendly_name_label.position = Vector3(0.0, 4.5, 0.0)
		print("   📍 Maintained PNG icon label position at: ", _friendly_name_label.position)
	
	# Update outline material scaling (only for non-memory areas that use shader materials)
	if _outline_mat != null:
		_outline_mat.set_shader_parameter("thickness_scaling", Vector3(1.0, 1.0, 1.0) / _static_body.scale)
	
	# print("DirectPoints voxel renderer dimensions updated: ", new_dimensions)  # Suppressed - called too frequently

## Keeps the friendly-name label below the cortical area, but snaps its Z to the camera-facing edge
## (avoids the label sitting at the center of the cortical depth).
func bv_update_friendly_name_label_position() -> void:
	if _static_body == null or _friendly_name_label == null:
		return
	if _should_use_png_icon_by_id(_cortical_area_id):
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var cam := viewport.get_camera_3d()
	if cam == null:
		return
	
	var y_offset: float = -(_static_body.scale.y / 2.0 + 2.0)
	# Renderer base class extends Node (not Node3D), so compute camera relation in the StaticBody3D's space.
	var cam_in_body_local: Vector3 = _static_body.to_local(cam.global_position)
	var z_sign: float = -1.0 if cam_in_body_local.z < 0.0 else 1.0
	var z_edge: float = _static_body.position.z + z_sign * (_static_body.scale.z / 2.0)
	
	_friendly_name_label.position = Vector3(_static_body.position.x, _static_body.position.y + y_offset, z_edge)

func update_visualization_data(visualization_data: PackedByteArray) -> void:
	# This method handles legacy SVO data for backward compatibility
	# The main rendering now uses _on_received_direct_neural_points
	print("DirectPoints voxel renderer received legacy SVO data (", visualization_data.size(), " bytes) - converting to direct points")
	
	# For now, clear all points if we receive SVO data
	_clear_all_neurons()

## Brain Visualizer desktop WS fast-path: expose MultiMesh for direct Rust updates.
func bv_get_multimesh() -> MultiMesh:
	# Be robust: if _multi_mesh wasn't assigned for any reason, return the instance's multimesh.
	if _multi_mesh != null:
		return _multi_mesh
	if _multi_mesh_instance != null:
		return _multi_mesh_instance.multimesh
	return null

## Brain Visualizer desktop WS fast-path: expose current dimensions (Vector3) for transform/color calculations.
func bv_get_dimensions() -> Vector3:
	return Vector3(_dimensions.x, _dimensions.y, _dimensions.z)

## Brain Visualizer desktop WS fast-path: keep behavior parity (timers/animations/material changes)
## while rendering is applied directly to MultiMesh by Rust.
func bv_notify_activity(point_count: int) -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Track update time (used by existing debug/diagnostics)
	if not has_meta("_last_update_time"):
		set_meta("_last_update_time", 0.0)
	set_meta("_last_update_time", current_time)
	
	if point_count > 0:
		_trigger_power_firing_animation()
		set_meta("_last_fire_time", current_time)
		_start_visibility_timer()
		
		# Make power cone use firing colors when neural activity occurs
		if AbstractCorticalArea.is_power_area(_cortical_area_id) and _power_material:
			_power_material.set_shader_parameter("albedo_color", Color(1, 0.1, 0.1, 0.8))
			_power_material.set_shader_parameter("emission_color", Color(1, 0.2, 0.2, 1))
			_power_material.set_shader_parameter("emission_energy", 1.5)
		
		# Make memory sphere fade into active state when neural activity occurs
		if _cortical_area_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY and _memory_jello_material:
			_set_memory_activity_state(true)
	else:
		# No neurons firing - don't clear immediately, let timer handle it
		if _visibility_timer.time_left <= 0.0:
			_clear_all_neurons()

func _on_received_direct_neural_points_bulk(x_array: PackedInt32Array, y_array: PackedInt32Array, z_array: PackedInt32Array, p_array: PackedFloat32Array) -> void:
	"""Handle Type 11 direct neural points data - Rust-accelerated processing"""
	# Granularity can be changed by the user at runtime; ensure mesh sizing/mode is updated
	# before applying new instance transforms.
	_refresh_visualization_voxel_granularity_from_cache()
	
	var point_count = x_array.size()
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# TIMING DEBUG: Track last update time for this area
	if not has_meta("_last_update_time"):
		set_meta("_last_update_time", 0.0)
	if not has_meta("_last_fire_time"):
		set_meta("_last_fire_time", 0.0)
	if not has_meta("_last_clear_time"):
		set_meta("_last_clear_time", 0.0)
	
	var last_update_time = get_meta("_last_update_time")
	var time_since_last_update = current_time - last_update_time if last_update_time > 0 else 0.0
	set_meta("_last_update_time", current_time)
	
	# Trigger power cone firing animation if this is the power cortical area
	if point_count > 0:
		_trigger_power_firing_animation()
		# Memory areas don't display individual neuron voxels (MultiMesh uses an invisible mesh).
		# Their "firing" is the sphere material transitioning into an active jello state.
		# This must be triggered on the bulk (signal) path as well as the desktop WS fast-path.
		if _cortical_area_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY and _memory_jello_material:
			_set_memory_activity_state(true)
	
	# Validate array sizes match
	if point_count != y_array.size() or point_count != z_array.size() or point_count != p_array.size():
		print("🧠 ERROR: Mismatched array sizes - x:", x_array.size(), " y:", y_array.size(), " z:", z_array.size(), " p:", p_array.size())
		_clear_all_neurons()
		return
	
	# Process neurons - replace old data with new data
	if point_count > 0:
		var last_fire_time = get_meta("_last_fire_time")
		var _time_since_last_fire = current_time - last_fire_time if last_fire_time > 0 else 0.0
		set_meta("_last_fire_time", current_time)
		
		# TEMP DEBUG: Check if (0,0,0) is firing
		var has_origin = false
		for i in range(point_count):
			if x_array[i] == 0 and y_array[i] == 0 and z_array[i] == 0:
				has_origin = true
				break
		if has_origin:
			var area_id = _cortical_area_id.substr(0, 6) if _cortical_area_id.length() >= 6 else _cortical_area_id
			var timestamp = _get_timestamp_with_ms()
			
			# Calculate interval since last fire
			var interval_ms = ""
			if has_meta("_last_origin_fire_ms"):
				var last_fire_ms = get_meta("_last_origin_fire_ms")
				var delta_ms = Time.get_ticks_msec() - last_fire_ms
				interval_ms = " [Δ%dms]" % delta_ms
			set_meta("_last_origin_fire_ms", Time.get_ticks_msec())
			
			set_meta("_last_had_origin", true)
		else:
			# Not firing this frame but had neurons
			if has_meta("_last_had_origin") and get_meta("_last_had_origin"):
				set_meta("_last_had_origin", false)
		
		_process_neurons_with_rust(x_array, y_array, z_array)
		# Keep neurons/chunks visible for the configured timestep window.
		_start_visibility_timer()
	else:
		# No neurons firing in this update - don't clear immediately.
		# Let the visibility timer handle clearing after the timestep expires.
		if _visibility_timer.time_left <= 0.0:
			_clear_all_neurons()

func _refresh_visualization_voxel_granularity_from_cache() -> void:
	"""Refresh visualization_voxel_granularity from cache and update the MultiMesh mesh if it changed.
	
	This must be fast and safe to call frequently (called during Type11 updates).
	"""
	# Special areas don't use voxel meshes for visualization.
	if AbstractCorticalArea.is_power_area(_cortical_area_id) or _cortical_area_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY:
		return
	if _multi_mesh == null:
		return
	
	var area_to_check = _cortical_area
	if area_to_check == null and FeagiCore and FeagiCore.feagi_local_cache:
		if _cortical_area_id in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas:
			area_to_check = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas[_cortical_area_id]
			_cortical_area = area_to_check
	
	if area_to_check == null:
		return
	
	var new_granularity: Vector3i = area_to_check.visualization_voxel_granularity
	if new_granularity == _visualization_voxel_granularity:
		return
	
	_visualization_voxel_granularity = new_granularity
	_is_aggregated_mode = _visualization_voxel_granularity != Vector3i(1, 1, 1)
	_apply_multimesh_mesh_for_current_granularity()

func _apply_multimesh_mesh_for_current_granularity() -> void:
	"""Apply the MultiMesh mesh based on current granularity.
	
	- Normal mode: fixed voxel size.
	- Aggregated mode: voxel size scales linearly with granularity so it stays proportional to the cortical volume.
	"""
	if _multi_mesh == null:
		return
	
	if _is_aggregated_mode:
		var chunk_mesh := BoxMesh.new()
		# IMPORTANT:
		# - For axes with granularity > 1, chunks should tile without gaps across the cortical volume.
		# - For axes with granularity == 1, keep the same voxel thickness (0.8) to match normal mode visuals.
		var size_x: float = float(_visualization_voxel_granularity.x) if _visualization_voxel_granularity.x > 1 else _VOXEL_VISUAL_SCALE
		var size_y: float = float(_visualization_voxel_granularity.y) if _visualization_voxel_granularity.y > 1 else _VOXEL_VISUAL_SCALE
		var size_z: float = float(_visualization_voxel_granularity.z) if _visualization_voxel_granularity.z > 1 else _VOXEL_VISUAL_SCALE
		var chunk_size_godot := Vector3(size_x, size_y, size_z)
		chunk_mesh.size = chunk_size_godot
		_multi_mesh.mesh = chunk_mesh
	else:
		var voxel_mesh := BoxMesh.new()
		voxel_mesh.size = Vector3(_VOXEL_VISUAL_SCALE, _VOXEL_VISUAL_SCALE, _VOXEL_VISUAL_SCALE)
		_multi_mesh.mesh = voxel_mesh

func _process_neurons_with_rust(x_array: PackedInt32Array, y_array: PackedInt32Array, z_array: PackedInt32Array) -> void:
	"""Process neurons using Rust - applies directly to MultiMesh (FASTEST!)
	
	For aggregated rendering mode:
	- Coordinates are granularity centers (already aggregated by backend)
	- Mesh size is set to granularity dimensions in setup()
	- Rust processor converts chunk center coordinates to Godot space correctly
	"""
	
	var point_count = x_array.size()
	
	# Warn if exceeding threshold (but not for aggregated rendering mode - fewer chunks expected)
	if point_count > _warning_threshold and not _is_aggregated_mode:
		print("   ⚠️  [%s] Processing %d neurons (exceeds warning threshold of %d) - monitoring performance" % [_cortical_area_id, point_count, _warning_threshold])
	elif _is_aggregated_mode and point_count > 0:
		# Log aggregated rendering processing (chunks, not neurons)
		if point_count % 100 == 0 or point_count <= 10:
			print("   🔥 [%s] Processing %d aggregated rendering chunks" % [_cortical_area_id, point_count])
	
	# Call Rust to apply directly to MultiMesh - NO GDScript LOOP!
	# NOTE: For aggregated rendering mode, coordinates are granularity centers, mesh size is granularity dimensions
	# Rust processor will correctly position chunk boxes in Godot space
	var result = _rust_processor.apply_arrays_to_multimesh(
		_multi_mesh,
		x_array,
		y_array,
		z_array,
		_dimensions
	)
	
	if not result.success:
		print("🦀 ERROR: Rust processing failed")
		_clear_all_neurons()
		return
	
	_current_neuron_count = result.neuron_count

func _on_received_direct_neural_points(points_data: PackedByteArray) -> void:
	"""Handle legacy Type 11 format - DEPRECATED, use bulk processing instead"""
	print("DirectPoints: Received legacy format data (", points_data.size(), " bytes) - consider upgrading to bulk format")
	
	# Check if we have any data
	if points_data.size() == 0:
		# No neurons firing - don't clear immediately, let timer handle it
		if _visibility_timer.time_left <= 0.0:
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
		# No neurons firing - don't clear immediately, let timer handle it
		if _visibility_timer.time_left <= 0.0:
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
	# TEMP DEBUG: Log when clearing happens
	if _current_neuron_count > 0:
		var area_id = _cortical_area_id.substr(0, 6) if _cortical_area_id.length() >= 6 else _cortical_area_id
		var timestamp = _get_timestamp_with_ms()
		var time_visible = 0.0
		if has_meta("_last_fire_time"):
			var current_time = Time.get_ticks_msec() / 1000.0
			time_visible = (current_time - get_meta("_last_fire_time")) * 1000.0  # Convert to ms
		# print("[%s] 🧹 [%s] CLEARING %d neurons (visible for %.0fms)" % [timestamp, area_id, _current_neuron_count, time_visible])  # Spam log - disabled
	
	_multi_mesh.instance_count = 0
	_current_neuron_count = 0
	
	# Fade memory sphere back to inactive state when neurons are cleared
	if _cortical_area_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY and _memory_jello_material:
		_set_memory_activity_state(false)

func _start_visibility_timer() -> void:
	"""Start the visibility timer with buffer for smooth updates"""
	if not FeagiCore:
		print("🔥 DirectPoints: Cannot start timer - FeagiCore not available")
		return
	
	# Use delay_between_bursts from FeagiCore (authoritative source from FEAGI API)
	# This is the same value TOPBAR uses and is updated when FEAGI changes simulation_timestep
	var delay_between_bursts = FeagiCore.delay_between_bursts
	
	# Fallback to cache if delay_between_bursts is 0 (not yet initialized)
	if delay_between_bursts <= 0.0 and FeagiCore.feagi_local_cache:
		delay_between_bursts = FeagiCore.feagi_local_cache.simulation_timestep
		if delay_between_bursts > 0.0:
			print("   ⚠️  Using fallback simulation_timestep from cache: %.3f seconds" % delay_between_bursts)
	
	if delay_between_bursts <= 0.0:
		print("🔥 DirectPoints: Cannot start timer - delay_between_bursts is 0 or invalid")
		return
	
	# Stop existing timer if running
	if _visibility_timer.time_left > 0:
		_visibility_timer.stop()
	
	# Record when neurons started displaying
	_neuron_display_start_time = Time.get_ticks_msec() / 1000.0
	
	# CRITICAL: Neurons should stay visible for exactly one simulation timestep
	# This matches the FEAGI simulation cycle duration
	var timeout = delay_between_bursts
	
	_visibility_timer.wait_time = timeout
	_visibility_timer.start()

func _on_delay_between_bursts_changed(new_delay: float) -> void:
	"""Called when FEAGI delay_between_bursts changes - update any active timers"""
	# If timer is currently running, update it with new delay
	if _visibility_timer.time_left > 0 and new_delay > 0.0:
		var remaining_time = _visibility_timer.time_left
		var new_timeout = new_delay
		
		# If we're more than halfway through, just use the new delay
		# Otherwise, preserve remaining time proportionally
		if remaining_time < new_delay * 0.5:
			_visibility_timer.wait_time = new_timeout
			_visibility_timer.start()

func _on_visibility_timeout() -> void:
	"""Called when the visibility timer expires - clear all neurons"""
	# TEMP DEBUG: Log timer expiration
	if _current_neuron_count > 0:
		var area_id = _cortical_area_id.substr(0, 6) if _cortical_area_id.length() >= 6 else _cortical_area_id
		var timestamp = _get_timestamp_with_ms()
		# print("[%s] ⏱️  [%s] Timer expired - clearing neurons" % [timestamp, area_id])  # Spam log - disabled
	
	# Visibility timer expired - clearing neurons via timeout
	_clear_all_neurons()
	
	# Make power cone use default cortical mesh color when no neural activity
	if AbstractCorticalArea.is_power_area(_cortical_area_id) and _power_material:
		# print("   ⚡ Power cone becoming inactive - using default cortical mesh color")  # Suppressed to reduce log spam
		_power_material.set_shader_parameter("albedo_color", Color(0.172451, 0.315246, 0.861982, 0.8))  # Light blue like cortical meshes
		_power_material.set_shader_parameter("emission_color", Color(0.172451, 0.315246, 0.861982, 1.0))  # Light blue emission
		_power_material.set_shader_parameter("emission_energy", 0.3)  # Subtle glow
	
	# Make memory sphere return to transparent state when no neural activity
	if _cortical_area_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY and _memory_jello_material:
		# print("   🔮 Memory sphere becoming inactive - fading to inactive state")  # Suppressed to reduce log spam
		_set_memory_activity_state(false)

func _get_timestamp_with_ms() -> String:
	"""Get timestamp with millisecond precision for debug logging"""
	# Get current system time
	var datetime = Time.get_datetime_dict_from_system()
	var ms = Time.get_ticks_msec() % 1000
	
	return "%04d-%02d-%02dT%02d:%02d:%02d.%03d" % [
		datetime.year, datetime.month, datetime.day,
		datetime.hour, datetime.minute, datetime.second,
		ms
	]

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
	
	# Activate tesla coil effect for power areas on hover
	if AbstractCorticalArea.is_power_area(_cortical_area_id):
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
	elif AbstractCorticalArea.is_power_area(_cortical_area_id):
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
	if not AbstractCorticalArea.is_power_area(_cortical_area_id) or _power_material == null:
		return
	
	# Get delay_between_bursts for animation duration (same as visibility timer)
	var delay_between_bursts = 0.8  # Default fallback
	if FeagiCore:
		delay_between_bursts = FeagiCore.delay_between_bursts
		# Fallback to cache if not yet initialized
		if delay_between_bursts <= 0.0 and FeagiCore.feagi_local_cache:
			delay_between_bursts = FeagiCore.feagi_local_cache.simulation_timestep
	
	# Use fallback if still invalid
	if delay_between_bursts <= 0.0:
		delay_between_bursts = 0.8
	
	var simulation_timestep = delay_between_bursts
	
	# print("   ⚡ Triggering power cone firing animation!")  # Suppressed to reduce log spam
	
	# Make power cone use firing colors when firing animation starts
	_power_material.set_shader_parameter("albedo_color", Color(1, 0.1, 0.1, 0.8))  # Bright red for firing
	_power_material.set_shader_parameter("emission_color", Color(1, 0.2, 0.2, 1))  # Bright red emission
	_power_material.set_shader_parameter("emission_energy", 1.5)  # Full glow
	
	# Create a new tween for this animation
	_firing_tween = create_tween()
	
	# Reset firing progress to 0
	_power_material.set_shader_parameter("firing_progress", 0.0)
	
	# Animate firing progress from 0.0 to 1.0 over simulation_timestep
	# Maintain same proportions as before (62.5% up, 37.5% down)
	var up_duration = simulation_timestep * 0.625
	var down_duration = simulation_timestep * 0.375
	
	_firing_tween.tween_method(
		Callable(self, "_set_power_firing_progress"),
		0.0,
		1.0,
		up_duration
	)
	
	# After animation completes, fade out the effect
	_firing_tween.tween_method(
		Callable(self, "_set_power_firing_progress"),
		1.0,
		0.0,
		down_duration
	)

func _set_power_firing_progress(progress: float) -> void:
	"""Tween callback to update power cone firing progress deterministically (no lambdas)."""
	if _power_material == null:
		return
	_power_material.set_shader_parameter("firing_progress", progress)

func _create_tesla_coil_spikes() -> void:
	"""Create electrical spikes that emanate from the power cone tip"""
	if not AbstractCorticalArea.is_power_area(_cortical_area_id):
		return
	
	
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
		lightning_material.emission = Color(0.9, 0.95, 1.0)  # Bright electrical glow
		lightning_material.emission_energy_multiplier = 3.0  # Very bright
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
		
		# Manually set rotation to look toward target (avoids look_at issues before adding to tree)
		var look_target = tip_position + spark_direction * 2.0
		var direction_to_target = (look_target - spike.position).normalized()
		if direction_to_target.length() > 0.001:
			var up = Vector3.UP
			if abs(direction_to_target.dot(Vector3.UP)) > 0.9:
				up = Vector3.FORWARD
			var right = up.cross(direction_to_target).normalized()
			var corrected_up = direction_to_target.cross(right).normalized()
			spike.basis = Basis(right, direction_to_target, corrected_up)
		
		# Add more random rotation for wider spread and natural lightning look
		spike.rotation_degrees += Vector3(
			randf_range(-30, 30),  # Increased from -15,15
			randf_range(-45, 45),  # Increased from -30,30
			randf_range(-30, 30)   # Increased from -15,15
		)
		
		
		# Start invisible - only show on hover
		spike.visible = false
		
		_tesla_coil_spikes.append(spike)
		_static_body.add_child(spike)
	

## Check if a cortical area should use PNG icon rendering
func _should_use_png_icon(area: AbstractCorticalArea) -> bool:
	# Check for special core areas (supports both old and new formats)
	if AbstractCorticalArea.is_death_area(area.cortical_ID):
		return true
	
	# Add more cortical area IDs here that should use PNG icons (using old format for now)
	var png_icon_areas = ["_health", "_energy", "_status"]  # Expandable list
	return area.cortical_ID in png_icon_areas

## Check if a cortical area ID should use PNG icon rendering (helper for when we only have ID)
func _should_use_png_icon_by_id(cortical_id: StringName) -> bool:
	# Check for special core areas (supports both old and new formats)
	if AbstractCorticalArea.is_death_area(cortical_id):
		return true
	
	# Add more cortical area IDs here that should use PNG icons (using old format for now)
	var png_icon_areas = ["_health", "_energy", "_status"]  # Expandable list
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
	if AbstractCorticalArea.is_death_area(area.cortical_ID):
		icon_material.emission_enabled = true
		icon_material.emission = Color(1.0, 0.2, 0.2)  # Red glow for death
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
	if AbstractCorticalArea.is_death_area(cortical_id):
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
	if AbstractCorticalArea.is_death_area(cortical_id):
		placeholder_color = Color(1.0, 0.0, 0.0, 1.0)  # Bright red for death
	else:
		match cortical_id:
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
	if AbstractCorticalArea.is_death_area(cortical_id):
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
		return
	
	var area_stats = stats[_cortical_area_id]
	if not area_stats.has("neuron_count"):
		return
	
	var neuron_count = int(area_stats["neuron_count"])
	
	# Update the sphere size based on neuron count
	_update_memory_sphere_size(neuron_count)

func _update_memory_sphere_size(neuron_count: int) -> void:
	"""Update memory sphere size based on neuron count"""
	if _cortical_area_type != AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY:
		return
	
	# Size the memory sphere by treating its volume as proportional to neuron_count.
	#
	# Requirement (per user): sphere volume == total memory neurons in the area.
	# For a sphere: V = (4/3) * PI * r^3  =>  r = cbrt((3 * V) / (4 * PI))
	var volume := float(neuron_count)
	var sphere_radius := pow((3.0 * volume) / (4.0 * PI), 1.0 / 3.0)
	var sphere_height := sphere_radius * 2.0
	
	
	# Update the sphere mesh
	if _outline_mesh_instance and _outline_mesh_instance.mesh is SphereMesh:
		var sphere_mesh = _outline_mesh_instance.mesh as SphereMesh
		sphere_mesh.radius = sphere_radius
		sphere_mesh.height = sphere_height
	
	# Update the collision shape
	if _static_body:
		var collision_shape = _static_body.get_child(0) as CollisionShape3D
		if collision_shape and collision_shape.shape is SphereShape3D:
			var sphere_shape = collision_shape.shape as SphereShape3D
			sphere_shape.radius = sphere_radius
	
	# If this memory area is positioned on a brain region plate, recalculate Y position
	# to keep the sphere bottom above the plate surface as it grows
	if _is_on_brain_region_plate() and _static_body != null:
		# Constants from UI_BrainMonitor_BrainRegion3D
		const PLATE_HEIGHT: float = 1.0
		const AREA_ABOVE_PLATE_GAP: float = 3.0
		
		# Find the parent brain region to get plate position
		var brain_region_viz = _find_parent_brain_region()
		if brain_region_viz != null:
			# Get the plate node to find its actual global Y position
			var plate_node = _find_plate_node(brain_region_viz)
			if plate_node != null:
				# Plate top is at plate center Y + PLATE_HEIGHT / 2.0
				var plate_center_y = plate_node.global_position.y
				var plate_top_y = plate_center_y + PLATE_HEIGHT / 2.0
				
				# Areas should have their bottom at AREA_ABOVE_PLATE_GAP above the plate top
				# For a sphere, the center Y should be at: plate_top_y + AREA_ABOVE_PLATE_GAP + sphere_radius
				var sphere_bottom_y = plate_top_y + AREA_ABOVE_PLATE_GAP
				var sphere_center_y = sphere_bottom_y + sphere_radius
				
				# Update the static body's global Y position to keep sphere afloat
				var current_pos = _static_body.global_position
				_static_body.global_position = Vector3(current_pos.x, sphere_center_y, current_pos.z)
				
				# Also update the friendly name label position
				if _friendly_name_label != null:
					var label_y_offset = -(sphere_radius + 2.0)
					_friendly_name_label.global_position = Vector3(current_pos.x, sphere_center_y + label_y_offset, current_pos.z)

## Helper to find the parent brain region 3D visualization
func _find_parent_brain_region() -> UI_BrainMonitor_BrainRegion3D:
	var current := get_parent()
	while current != null:
		if current is UI_BrainMonitor_BrainRegion3D:
			return current as UI_BrainMonitor_BrainRegion3D
		current = current.get_parent()
	return null

## Helper to find the plate node (InputPlate, OutputPlate, or ConflictPlate) for this area
func _find_plate_node(brain_region_viz: UI_BrainMonitor_BrainRegion3D) -> Node3D:
	# Check which container this area is in to determine which plate to use
	var container = get_parent()
	while container != null and container != brain_region_viz:
		if container.name == "InputAreas":
			return brain_region_viz.get_node_or_null("RegionAssembly/InputPlate") as Node3D
		elif container.name == "OutputAreas":
			return brain_region_viz.get_node_or_null("RegionAssembly/OutputPlate") as Node3D
		elif container.name == "ConflictAreas":
			return brain_region_viz.get_node_or_null("RegionAssembly/ConflictPlate") as Node3D
		container = container.get_parent()
	
	# Fallback: try to find any plate
	return brain_region_viz.get_node_or_null("RegionAssembly/InputPlate") as Node3D

func _set_tesla_coil_active(active: bool) -> void:
	"""Activate or deactivate the tesla coil electrical spikes"""
	
	if not AbstractCorticalArea.is_power_area(_cortical_area_id):
		return
		
	if _tesla_coil_spikes.is_empty():
		return
	
	_is_tesla_coil_active = active
	
	if active:
		
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
				Callable(self, "_tesla_flicker_step").bind(spike, random_freq),
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
				Callable(self, "_tesla_move_step").bind(spike, base_position, spike_index),
				0.0,
				TAU,
				movement_speed
			)
	else:
		
		# Stop all active tweens to prevent infinite animation
		for tween in _tesla_coil_tweens:
			if tween != null and tween.is_valid():
				tween.kill()
		_tesla_coil_tweens.clear()
		
		# Hide all spikes
		for spike in _tesla_coil_spikes:
			spike.visible = false

func _tesla_flicker_step(_t: float, spike: MeshInstance3D, random_freq: float) -> void:
	"""Tween callback for tesla spike flicker (no lambdas; parser-safe)."""
	if spike == null:
		return
	var material := spike.material_override as StandardMaterial3D
	if material == null:
		return
	# Flicker between full brightness and dim
	var time_value = Time.get_ticks_msec() / 1000.0  # Convert to seconds
	var flicker_value = sin(time_value * random_freq) * 0.5 + 0.5
	material.emission_energy = 1.0 + flicker_value * 3.0
	# Occasionally make it invisible for crackling effect
	spike.visible = randf() > 0.1  # 90% visible, 10% invisible for crackling

func _tesla_move_step(t: float, spike: MeshInstance3D, base_position: Vector3, spike_index: int) -> void:
	"""Tween callback for tesla spike jitter motion (no lambdas; parser-safe)."""
	if spike == null:
		return
	var noise_offset = Vector3(
		sin(t * 10 + spike_index) * 0.1,
		cos(t * 8 + spike_index) * 0.05,
		sin(t * 12 + spike_index) * 0.1
	)
	spike.position = base_position + noise_offset

## Create inactive material for memory areas when not firing (light blue like cortical voxels)
func _create_transparent_memory_material() -> ShaderMaterial:
	"""Create a light blue cortical area colored version of the memory jello material for inactive state"""
	var inactive_material = load(MEMORY_JELLO_MAT_PATH).duplicate() as ShaderMaterial
	
	# Use the same light blue color as cortical area voxels (matching power cone inactive color)
	var cortical_blue = Color(0.172451, 0.315246, 0.861982, 0.8)  # Light blue like cortical meshes
	inactive_material.set_shader_parameter("albedo_color", cortical_blue)
	inactive_material.set_shader_parameter("emission_color", Color(0.172451, 0.315246, 0.861982, 1.0))  # Light blue emission
	inactive_material.set_shader_parameter("emission_energy", 0.3)  # Subtle glow like cortical areas
	inactive_material.set_shader_parameter("rim_intensity", 0.8)  # Moderate rim lighting
	
	return inactive_material 

func _init_memory_material_targets() -> void:
	"""Cache active/inactive shader parameters so we can tween between them for subtle flashing."""
	if _memory_jello_material == null or _memory_transparent_material == null:
		return
	
	_memory_active_albedo = _memory_jello_material.get_shader_parameter("albedo_color")
	_memory_active_emission = _memory_jello_material.get_shader_parameter("emission_color")
	_memory_active_emission_energy = float(_memory_jello_material.get_shader_parameter("emission_energy"))
	_memory_active_rim_intensity = float(_memory_jello_material.get_shader_parameter("rim_intensity"))
	_memory_active_jello_strength = float(_memory_jello_material.get_shader_parameter("jello_strength"))
	
	_memory_inactive_albedo = _memory_transparent_material.get_shader_parameter("albedo_color")
	_memory_inactive_emission = _memory_transparent_material.get_shader_parameter("emission_color")
	_memory_inactive_emission_energy = float(_memory_transparent_material.get_shader_parameter("emission_energy"))
	_memory_inactive_rim_intensity = float(_memory_transparent_material.get_shader_parameter("rim_intensity"))
	_memory_inactive_jello_strength = float(_memory_transparent_material.get_shader_parameter("jello_strength"))

func _apply_memory_material_inactive_state() -> void:
	"""Immediately apply inactive state to the active material (used at startup)."""
	if _memory_jello_material == null:
		return
	_memory_jello_material.set_shader_parameter("albedo_color", _memory_inactive_albedo)
	_memory_jello_material.set_shader_parameter("emission_color", _memory_inactive_emission)
	_memory_jello_material.set_shader_parameter("emission_energy", _memory_inactive_emission_energy)
	_memory_jello_material.set_shader_parameter("rim_intensity", _memory_inactive_rim_intensity)
	_memory_jello_material.set_shader_parameter("jello_strength", _memory_inactive_jello_strength)

func _set_memory_activity_state(is_active: bool) -> void:
	"""Smoothly fade memory sphere between inactive/active states by tweening shader parameters."""
	if _memory_jello_material == null:
		return
	
	# Avoid stacking tweens
	if _memory_activity_tween != null and _memory_activity_tween.is_valid():
		_memory_activity_tween.kill()
		_memory_activity_tween = null
	
	var from_albedo: Color = _memory_jello_material.get_shader_parameter("albedo_color")
	var from_emission: Color = _memory_jello_material.get_shader_parameter("emission_color")
	var from_emission_energy: float = float(_memory_jello_material.get_shader_parameter("emission_energy"))
	var from_rim_intensity: float = float(_memory_jello_material.get_shader_parameter("rim_intensity"))
	var from_jello_strength: float = float(_memory_jello_material.get_shader_parameter("jello_strength"))
	
	var to_albedo: Color = _memory_active_albedo if is_active else _memory_inactive_albedo
	var to_emission: Color = _memory_active_emission if is_active else _memory_inactive_emission
	var to_emission_energy: float = _memory_active_emission_energy if is_active else _memory_inactive_emission_energy
	var to_rim_intensity: float = _memory_active_rim_intensity if is_active else _memory_inactive_rim_intensity
	var to_jello_strength: float = _memory_active_jello_strength if is_active else _memory_inactive_jello_strength
	
	# Slightly quicker fade-in than fade-out for a softer "pulse" feel.
	var duration := 0.12 if is_active else 0.25
	
	_memory_activity_tween = create_tween()
	_memory_activity_tween.set_trans(Tween.TRANS_SINE)
	_memory_activity_tween.set_ease(Tween.EASE_OUT if is_active else Tween.EASE_IN_OUT)
	_memory_activity_tween.tween_method(
		Callable(self, "_memory_activity_step").bind(
			from_albedo,
			from_emission,
			from_emission_energy,
			from_rim_intensity,
			from_jello_strength,
			to_albedo,
			to_emission,
			to_emission_energy,
			to_rim_intensity,
			to_jello_strength
		),
		0.0,
		1.0,
		duration
	)

func _memory_activity_step(
	t: float,
	from_albedo: Color,
	from_emission: Color,
	from_emission_energy: float,
	from_rim_intensity: float,
	from_jello_strength: float,
	to_albedo: Color,
	to_emission: Color,
	to_emission_energy: float,
	to_rim_intensity: float,
	to_jello_strength: float
) -> void:
	"""Tween callback to fade memory visual state (no lambdas; parser-safe)."""
	if _memory_jello_material == null:
		return
	_memory_jello_material.set_shader_parameter("albedo_color", from_albedo.lerp(to_albedo, t))
	_memory_jello_material.set_shader_parameter("emission_color", from_emission.lerp(to_emission, t))
	_memory_jello_material.set_shader_parameter("emission_energy", lerpf(from_emission_energy, to_emission_energy, t))
	_memory_jello_material.set_shader_parameter("rim_intensity", lerpf(from_rim_intensity, to_rim_intensity, t))
	_memory_jello_material.set_shader_parameter("jello_strength", lerpf(from_jello_strength, to_jello_strength, t))

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

		# Input via chain links / partial mappings / IPU fallback
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

		# Output via chain links / partial mappings / OPU fallback
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
