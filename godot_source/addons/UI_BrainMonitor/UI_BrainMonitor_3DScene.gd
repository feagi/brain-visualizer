extends SubViewportContainer
class_name UI_BrainMonitor_3DScene
## Handles running the scene of Brain monitor, which shows a single instance of a brain region
# Force re-parse to fix Godot parsing issues
const SCENE_BRAIN_MONITOR_PATH: StringName = "res://addons/UI_BrainMonitor/BrainMonitor.tscn"

@export var multi_select_key: Key = KEY_SHIFT

signal clicked_cortical_area(area: AbstractCorticalArea) ## Clicked cortical area (regardless of context)
signal cortical_area_selected_neurons_changed(area: AbstractCorticalArea, selected_neuron_coordinates: Array[Vector3i])
signal cortical_area_selected_neurons_changed_delta(area: AbstractCorticalArea, selected_neuron_coordinate: Vector3i, is_added: bool)
signal requesting_to_fire_selected_neurons(area_IDs_and_neuron_coordinates: Dictionary[StringName, Array]) # NOTE: Array is of type Array[Vector3i]
signal requesting_to_clear_all_selected_neurons()

var representing_region: BrainRegion:
	get: return _representing_region

var _node_3D_root: Node3D
var _pancake_cam: UI_BrainMonitor_PancakeCamera
var _UI_layer_for_BM: UI_BrainMonitor_Overlay = null
var _combo: BrainObjectsCombo = null
var _should_show_combo_buttons: bool = true


var _representing_region: BrainRegion
var _world_3D: World3D # used for physics stuff
var _cortical_visualizations_by_ID: Dictionary[StringName, UI_BrainMonitor_CorticalArea]
var _brain_region_visualizations_by_ID: Dictionary  # Dictionary[StringName, UI_BrainMonitor_BrainRegion3D]
var _active_previews: Array[UI_BrainMonitor_InteractivePreview] = []
var _restrict_neuron_selection_to: AbstractCorticalArea = null

# Quick Connect: live guide curve state
var _qc_guide_active: bool = false
var _qc_guide_node: Node3D = null
var _qc_guide_start: Vector3 = Vector3.ZERO
var _qc_guide_material: StandardMaterial3D = null
var _qc_guide_radius_thin: float = 0.10
var _qc_guide_radius_thick: float = 0.25
var _qc_guide_current_radius: float = 0.10
var _qc_guide_max_distance: float = 300.0
var _qc_guide_min_distance: float = 0.05
var _qc_guide_max_arc_height: float = 60.0
var _qc_guide_max_distance_off_target: float = 80.0
var _qc_guide_max_distance_on_target: float = 300.0
var _qc_guide_off_target_depth: float = 60.0

var _previously_moused_over_volumes: Array[UI_BrainMonitor_CorticalArea] = []
var _previously_moused_over_cortical_area_neurons: Dictionary[UI_BrainMonitor_CorticalArea, Array] = {} # where Array is an Array of Vector3i representing Neuron Coordinates



## Startup camera intro configuration and state
@export var enable_startup_camera_intro: bool = true ## If true, plays a brief drop-and-zoom on first scene init
@export var auto_frame_k_height: float = 1.4
@export var auto_frame_k_width: float = 1.5
@export var auto_frame_min_dist: float = 45.0
var _startup_intro_animating: bool = false
var _startup_intro_center: Vector3 = Vector3.ZERO
var _startup_tween: Tween = null
var _startup_prev_cam_mode: UI_BrainMonitor_PancakeCamera.MODE = UI_BrainMonitor_PancakeCamera.MODE.TANK
var _intro_start_pos: Vector3
var _intro_control_pos: Vector3
var _intro_final_pos: Vector3
var _intro_start_fov: float
var _intro_final_fov: float
var _intro_start_rot: Quaternion
var _intro_target_rot: Quaternion
var _active_preview_indicators: Array[Node3D] = []
var _last_scene_center: Vector3 = Vector3.ZERO

## Spawns an non-setup Brain Visualizer Scene. # WARNING be sure to add it to the scene tree before running setup on it!
static func create_uninitialized_brain_monitor() -> UI_BrainMonitor_3DScene:
	return load(SCENE_BRAIN_MONITOR_PATH).instantiate()

func _ready() -> void:
	_node_3D_root = $SubViewport/Center
	_UI_layer_for_BM = $SubViewport/BM_UI
	
	# TODO check mode (PC)
	_pancake_cam = $SubViewport/Center/PancakeCam
	if _pancake_cam:
		_pancake_cam.BM_input_events.connect(_process_user_input)
		# Log camera and scene bounds when user moves camera (debounced)
		if not _pancake_cam.camera_user_moved.is_connected(_on_user_camera_moved):
			_pancake_cam.camera_user_moved.connect(_on_user_camera_moved)
		# Use new auto-frame formula when user presses R
		if not _pancake_cam.camera_reset_requested.is_connected(_on_user_camera_reset_requested):
			_pancake_cam.camera_reset_requested.connect(_on_user_camera_reset_requested)
		# Track mouse enter/exit on this container so keyboard actions (R) are scoped to hovered tab/viewport
		if not mouse_entered.is_connected(_on_container_mouse_entered):
			mouse_entered.connect(_on_container_mouse_entered)
		if not mouse_exited.is_connected(_on_container_mouse_exited):
			mouse_exited.connect(_on_container_mouse_exited)
		
		# Ensure SubViewport has a World3D with proper environment
		var subviewport = $SubViewport as SubViewport
		if subviewport.world_3d == null:
			# Tab brain monitors need SEPARATE World3D to avoid seeing main content
			if BV.UI.temp_root_bm and BV.UI.temp_root_bm != self:
				var main_viewport = BV.UI.temp_root_bm.get_child(0) as SubViewport
				if main_viewport.world_3d != null:
					subviewport.world_3d = _create_world3d_with_environment()
				else:
					var shared_world = _create_world3d_with_environment()
					subviewport.world_3d = shared_world
					main_viewport.world_3d = shared_world
			else:
				subviewport.world_3d = _create_world3d_with_environment()
		
		_world_3D = _pancake_cam.get_world_3d()



## Public accessor to the Pancake camera to avoid external access to private members
func get_pancake_camera() -> UI_BrainMonitor_PancakeCamera:
	return _pancake_cam

func setup(region: BrainRegion, show_combo_buttons: bool = true) -> void:
	_should_show_combo_buttons = show_combo_buttons
	_representing_region = region
	name = "BM_" + region.region_ID
	
	print("BrainMonitor 3D Scene: SETUP STARTED for region: %s" % region.friendly_name)
	
	# Add the context-aware brain objects combo to the overlay top-left
	if _UI_layer_for_BM and _should_show_combo_buttons:
		# Ensure a top row exists (so we can keep Bottom_Row at bottom)
		var top_row: HBoxContainer = null
		if _UI_layer_for_BM.has_node("Top_Row"):
			top_row = _UI_layer_for_BM.get_node("Top_Row") as HBoxContainer
		else:
			top_row = HBoxContainer.new()
			top_row.name = "Top_Row"
			top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			top_row.mouse_filter = Control.MOUSE_FILTER_PASS
			_UI_layer_for_BM.add_child(top_row)
			# Add a spacer to push Bottom_Row to bottom if not present
			if not _UI_layer_for_BM.has_node("Spacer_V"):
				var spacer := Control.new()
				spacer.name = "Spacer_V"
				spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
				spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_UI_layer_for_BM.add_child(spacer)
			# Ensure Bottom_Row stays last so it's at the bottom
			if _UI_layer_for_BM.has_node("Bottom_Row"):
				var bottom_row := _UI_layer_for_BM.get_node("Bottom_Row")
				_UI_layer_for_BM.move_child(bottom_row, _UI_layer_for_BM.get_child_count() - 1)
		# Instantiate combo into top row if not already present
		if not top_row.has_node("BrainObjectsCombo"):
			var combo_scene: PackedScene = load("res://BrainVisualizer/UI/GenericElements/BrainObjectsCombo/BrainObjectsCombo.tscn")
			_combo = combo_scene.instantiate()
			_combo.name = "BrainObjectsCombo"
			top_row.add_child(_combo)
			_combo.mouse_filter = Control.MOUSE_FILTER_STOP
			_combo.set_3d_context(self, _representing_region)
	

	

	
	# Create cortical areas from target region
	for area in _representing_region.contained_cortical_areas:
		_add_cortical_area(area)
	
	# Check cortical areas in child regions that might be I/O areas
	for child_region in _representing_region.contained_regions:
		for area in child_region.contained_cortical_areas:
			var is_io = _is_area_input_output_of_specific_child_region(area, child_region)
			if is_io:
				_add_cortical_area(area)
	
	# Create child brain region frames
	for child_region in _representing_region.contained_regions:
		_add_brain_region_frame(child_region)
	


	




	# Connect to region signals for dynamic updates
	_representing_region.cortical_area_added_to_region.connect(_add_cortical_area)
	_representing_region.cortical_area_removed_from_region.connect(_remove_cortical_area)
	_representing_region.subregion_added_to_region.connect(_add_brain_region_frame)
	_representing_region.subregion_removed_from_region.connect(_remove_brain_region_frame)

	# Connect to cache reload events ONCE (guarded) to refresh cortical connections
	if FeagiCore.feagi_local_cache:
		var cache = FeagiCore.feagi_local_cache
		if not cache.cache_reloaded.is_connected(_on_cache_reloaded_refresh_all_connections):
			cache.cache_reloaded.connect(_on_cache_reloaded_refresh_all_connections)

	# Position camera to frame all 3D objects in this scene
	if _pancake_cam and region.contained_cortical_areas.size() > 0:
		await _auto_frame_camera_to_objects()
		# Optionally play startup intro (drop from sky + gentle zoom) on first setup
		if enable_startup_camera_intro:
			_startup_intro_center = _last_scene_center
			_play_startup_camera_intro()

## Plays a brief camera intro that drops from above and gently zooms into the scene
## The camera ends exactly at its current transform, which is assumed to be the intended initial view
func _play_startup_camera_intro() -> void:
	if _pancake_cam == null:
		return
	if _startup_intro_animating:
		return
	
	# Capture final transform (already positioned and oriented to look at center)
	var final_pos: Vector3 = _pancake_cam.position
	var final_rot: Vector3 = _pancake_cam.rotation
	var final_fov: float = _pancake_cam.fov
	
	# Compute a start transform: slightly higher in Y and farther back along view direction (lowered overall height)
	var drop_height: float = 40.0
	var zoom_back_distance: float = 240.0
	var dir_to_center: Vector3 = (_startup_intro_center - final_pos).normalized()
	var start_pos: Vector3 = final_pos - (dir_to_center * zoom_back_distance) + Vector3(0.0, drop_height, 0.0)
	
	# Temporarily lock camera control to animation
	_startup_prev_cam_mode = _pancake_cam.movement_mode
	_pancake_cam.movement_mode = UI_BrainMonitor_PancakeCamera.MODE.ANIMATION
	_pancake_cam.allow_user_control = false
	_startup_intro_animating = true
	
	# Apply start transform and widened FOV, keep looking at the center during motion
	_pancake_cam.position = start_pos
	_pancake_cam.look_at(_startup_intro_center, Vector3.UP)
	var start_fov: float = clamp(final_fov * 1.25, 20.0, 90.0)
	_pancake_cam.fov = start_fov
	
	# Do not modify final_pos; intro should finish exactly at the framed position
	_intro_start_rot = _pancake_cam.quaternion
	# Compute a level (horizontal) final orientation that faces the center in XZ only
	var horizontal_dir: Vector3 = Vector3(_startup_intro_center.x, final_pos.y, _startup_intro_center.z) - final_pos
	if horizontal_dir.length() < 0.001:
		# Fallback: use current forward flattened
		horizontal_dir = (-_pancake_cam.global_transform.basis.z)
		horizontal_dir.y = 0.0
	if horizontal_dir.length() > 0.001:
		horizontal_dir = horizontal_dir.normalized()
	var target_basis: Basis = Basis().looking_at(horizontal_dir, Vector3.UP)
	_intro_target_rot = target_basis.get_rotation_quaternion()
	
	# Create tween for smooth curved motion and FOV change (single stage)
	if _startup_tween != null:
		_startup_tween.kill()
	_startup_tween = create_tween()
	_startup_tween.set_trans(Tween.TRANS_SINE)
	_startup_tween.set_ease(Tween.EASE_OUT)
	var duration: float = 1.8 * 1.8 # a bit slower than before
	
	# Define a quadratic Bézier control point to create a descending curve
	_intro_start_pos = start_pos
	_intro_final_pos = final_pos
	_intro_start_fov = start_fov
	_intro_final_fov = final_fov
	_intro_control_pos = Vector3(
		lerp(start_pos.x, final_pos.x, 0.55),
		lerp(start_pos.y, final_pos.y, 0.25), # keep higher Y early, descend smoothly
		lerp(start_pos.z, final_pos.z, 0.55)
	)
	
	# Drive the animation via a single tweened method from t=0..1
	_startup_tween.tween_method(Callable(self, "_update_startup_camera_bezier"), 0.0, 1.0, duration)
	
	# Cleanup when finished
	_startup_tween.finished.connect(func():
		_startup_intro_animating = false
		_pancake_cam.position = final_pos
		_pancake_cam.quaternion = _intro_target_rot
		_pancake_cam.fov = final_fov
		_pancake_cam.movement_mode = _startup_prev_cam_mode
		_pancake_cam.allow_user_control = true
	)

## Updates camera along a quadratic Bézier curve and eases FOV
func _update_startup_camera_bezier(t: float) -> void:
	# Quadratic Bézier interpolation
	var a: Vector3 = _intro_start_pos.lerp(_intro_control_pos, t)
	var b: Vector3 = _intro_control_pos.lerp(_intro_final_pos, t)
	var bezier_pos: Vector3 = a.lerp(b, t)
	_pancake_cam.position = bezier_pos
	# Smoothly slerp rotation toward horizontal orientation
	_pancake_cam.quaternion = _intro_start_rot.slerp(_intro_target_rot, t)
	# Smooth FOV easing in sync
	_pancake_cam.fov = lerp(_intro_start_fov, _intro_final_fov, t)

## Spawns a pulsing, glowing red downward arrow at a world position for 3 seconds
func _spawn_preview_indicator(world_center_xz: Vector3, tip_y: float) -> void:
	var indicator: Node3D = Node3D.new()
	indicator.name = "PreviewIndicator"
	_node_3D_root.add_child(indicator)
	# Our arrow is oriented downward (180 deg on X). The cone tip should be at indicator origin, so position indicator at tip
	indicator.global_position = Vector3(world_center_xz.x, tip_y, world_center_xz.z)

	# Build a simple arrow using MeshInstance3D primitives (cone for the head, cylinder for the shaft)
	var shaft := MeshInstance3D.new()
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.1
	shaft_mesh.bottom_radius = 0.1
	shaft_mesh.height = 1.8
	shaft.mesh = shaft_mesh
	# With the tip at the indicator origin (y=0) and arrow pointing down (rot 180°), place shaft below tip
	shaft.position = Vector3(0, -shaft_mesh.height / 2.0, 0)
	indicator.add_child(shaft)

	var head := MeshInstance3D.new()
	var head_mesh := CylinderMesh.new() # Use cylinder with top_radius 0 to simulate cone
	head_mesh.top_radius = 0.0
	head_mesh.bottom_radius = 0.35
	head_mesh.height = 0.9
	head.mesh = head_mesh
	# Place the cone so its tip sits at the indicator origin (y=0)
	head.position = Vector3(0, -head_mesh.height / 2.0, 0)
	indicator.add_child(head)

	# Orient arrow downward
	indicator.rotation_degrees = Vector3(180, 0, 0)

	# Material: emissive red
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0, 0, 1)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.2, 0.2, 1)
	mat.emission_energy_multiplier = 1.5
	shaft.material_override = mat
	head.material_override = mat

	# Scale by camera distance to ensure visibility
	var cam: Camera3D = _pancake_cam
	if cam:
		var dist: float = cam.global_position.distance_to(indicator.global_position)
		var scale_factor: float = clamp(dist * 0.02, 0.75, 6.0)
		indicator.scale = Vector3.ONE * scale_factor

	# Pulse tween (scale and emission) for 3 seconds, then free
	var pulse_tween := create_tween()
	pulse_tween.set_trans(Tween.TRANS_SINE)
	pulse_tween.set_ease(Tween.EASE_IN_OUT)
	var life: float = 5.0
	# Pulse scale subtly
	pulse_tween.tween_property(indicator, "scale", indicator.scale * 1.2, life * 0.5)
	pulse_tween.tween_property(indicator, "scale", indicator.scale, life * 0.5)
	# Pulse emission energy (simulate glow)
	var emissive_up := create_tween()
	emissive_up.set_trans(Tween.TRANS_SINE)
	emissive_up.set_ease(Tween.EASE_IN_OUT)
	emissive_up.tween_property(mat, "emission_energy_multiplier", 3.5, life * 0.5)
	emissive_up.tween_property(mat, "emission_energy_multiplier", 1.5, life * 0.5)

	# Bounce animation: gently bob the arrow up and down to draw attention
	var start_y: float = indicator.position.y
	var bounce_amp: float = clamp(indicator.scale.y * 0.3, 0.4, 3.0)
	var bounce_period: float = 0.6
	var bounce_loops: int = int(ceil(life / bounce_period))
	var bounce_tween := create_tween()
	bounce_tween.set_trans(Tween.TRANS_SINE)
	bounce_tween.set_ease(Tween.EASE_IN_OUT)
	bounce_tween.set_loops(bounce_loops)
	# Up then back to base, total time per loop = bounce_period
	bounce_tween.tween_property(indicator, "position:y", start_y + bounce_amp, bounce_period * 0.5)
	bounce_tween.tween_property(indicator, "position:y", start_y, bounce_period * 0.5)

	_active_preview_indicators.append(indicator)
	get_tree().create_timer(life).timeout.connect(func():
		if indicator:
			indicator.queue_free()
		_active_preview_indicators.erase(indicator)
	)

## Defers indicator spawning until transforms are updated, then places it at true world center
func _spawn_indicator_for_node_center(node: Node) -> void:
	# Wait 2 frames to ensure the preview's MeshInstance3D children are instantiated and transformed
	await get_tree().process_frame
	await get_tree().process_frame
	if node == null:
		return
	var aabb := _compute_world_aabb(node)
	var center := aabb.position + (aabb.size / 2.0)
	var world_center := Vector3(center.x, center.y, center.z)
	_spawn_preview_indicator(world_center, world_center.y)

## Computes a world-space AABB for a Node3D by aggregating all MeshInstance3D children
func _compute_world_aabb(node: Node) -> AABB:
	var have: bool = false
	var aabb: AABB = AABB()
	# If this node is a mesh, include its transformed bounds
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi.mesh != null:
			var local := mi.mesh.get_aabb()
			var p := local.position
			var s := local.size
			var corners := [
				Vector3(p.x, p.y, p.z),
				Vector3(p.x + s.x, p.y, p.z),
				Vector3(p.x, p.y + s.y, p.z),
				Vector3(p.x, p.y, p.z + s.z),
				Vector3(p.x + s.x, p.y + s.y, p.z + s.z),
				Vector3(p.x + s.x, p.y + s.y, p.z),
				Vector3(p.x + s.x, p.y, p.z + s.z),
				Vector3(p.x, p.y + s.y, p.z + s.z)
			]
			for c in corners:
				var wp: Vector3 = mi.global_transform * c
				if !have:
					aabb = AABB(wp, Vector3.ZERO)
					have = true
				else:
					aabb = aabb.expand(wp)
	# Recurse into children
	for child in node.get_children():
		if child is Node:
			var caabb := _compute_world_aabb(child as Node)
			if caabb.size != Vector3.ZERO or !caabb.position.is_equal_approx(Vector3.ZERO):
				if !have:
					aabb = caabb
					have = true
				else:
					aabb = aabb.merge(caabb)
	# Fallback to node position if nothing else was found
	if !have:
		if node is Node3D:
			return AABB((node as Node3D).global_position, Vector3.ZERO)
		else:
			return AABB(Vector3.ZERO, Vector3.ZERO)
	return aabb

## While the intro is running, keep the camera aimed at the scene center as it moves
func _process(delta: float) -> void:
	if _startup_intro_animating and _pancake_cam != null:
		_pancake_cam.look_at(_startup_intro_center, Vector3.UP)
	
	
	# Update combo context after setup has region
	if _combo:
		_combo.set_3d_context(self, _representing_region)

func _on_container_mouse_entered() -> void:
	if _pancake_cam:
		_pancake_cam.set_mouse_hover_state(true)

func _on_container_mouse_exited() -> void:
	if _pancake_cam:
		_pancake_cam.set_mouse_hover_state(false)

func _create_world3d_with_environment() -> World3D:
	var new_world = World3D.new()
	
	# Try to copy environment from the main scene's viewport
	var main_viewport = get_viewport()
	if main_viewport and main_viewport.world_3d and main_viewport.world_3d.environment:
		new_world.environment = main_viewport.world_3d.environment
		return new_world
	
	# Fallback: Create basic environment if can't copy
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.0951993, 0.544281, 0.999948, 1)  # Sky blue
	new_world.environment = environment
	
	return new_world


## Computes scene bounds and positions camera so all objects fit in view with sensible padding
func _auto_frame_camera_to_objects() -> void:
	# Ensure transforms are current
	await get_tree().process_frame
	await get_tree().process_frame
	# Prefer tight bounds from cortical area data (ignores huge placeholder frames)
	var aabb := _compute_cortical_data_aabb()
	# Always include any active previews so framing contains in-progress placements
	var previews_aabb := _compute_previews_aabb()
	if previews_aabb.size != Vector3.ZERO or !previews_aabb.position.is_equal_approx(Vector3.ZERO):
		aabb = previews_aabb if aabb.size == Vector3.ZERO else aabb.merge(previews_aabb)
	if aabb.size == Vector3.ZERO:
		# Fallback to visual bounds
		aabb = _compute_scene_aabb()
	# Retry a few frames until bounds become valid
	var tries := 0
	while (aabb.size == Vector3.ZERO or (aabb.size.x + aabb.size.y + aabb.size.z) < 0.01) and tries < 8:
		await get_tree().process_frame
		aabb = _compute_scene_aabb()
		tries += 1
	if aabb.size == Vector3.ZERO or (aabb.size.x + aabb.size.y + aabb.size.z) < 0.01:
		# Fallback to legacy heuristic using FEAGI coordinates
		if _representing_region and _representing_region.contained_cortical_areas.size() > 0:
			var center_pos := Vector3.ZERO
			for area in _representing_region.contained_cortical_areas:
				center_pos += Vector3(area.coordinates_3D)
			center_pos /= _representing_region.contained_cortical_areas.size()
			_last_scene_center = center_pos
			var legacy_cam := center_pos + Vector3(0, 50, 100)
			_pancake_cam.global_position = legacy_cam
			_pancake_cam.look_at(center_pos, Vector3.UP)
			_pancake_cam.current = true
			_pancake_cam.near = 0.05
			_log_objects_relative_to_camera("fallback_legacy")
		return
	var center := aabb.position + (aabb.size / 2.0)
	_last_scene_center = center
	# Choose a straight-on view along +Z, level (no pitch), so we face the circuit
	var up := Vector3.UP
	var dir_hint := Vector3(0, 0, 1) # camera behind +Z looking toward -Z at center
	# Compute FOVs (guard bad/zero FOV)
	var fov_used: float = _pancake_cam.fov
	if fov_used < 5.0:
		fov_used = 70.0
	var vfov_rad: float = deg_to_rad(fov_used)
	var vp_size := _pancake_cam.get_viewport().get_visible_rect().size
	var aspect: float = vp_size.x / max(1.0, vp_size.y)
	var hfov_rad: float = 2.0 * atan(tan(vfov_rad * 0.5) * aspect)
	# Half extents
	var half_w: float = max(0.01, aabb.size.x * 0.5)
	var half_h: float = max(0.01, aabb.size.y * 0.5)
	var half_d: float = max(0.01, aabb.size.z * 0.5)
	# Required distances to fit width and height
	var dist_by_h: float = half_h / max(0.001, tan(vfov_rad * 0.5))
	var dist_by_w: float = half_w / max(0.001, tan(hfov_rad * 0.5))
	# Apply learned multipliers from your samples
	var distance: float = max(auto_frame_k_height * dist_by_h, auto_frame_k_width * dist_by_w)
	# No extra depth margin needed for straight-on framing
	# distance unchanged
	# Padding and clamps (very tight framing with a tiny margin)
	# Enforce minimum and relative caps
	var min_dist: float = auto_frame_min_dist
	var max_dist: float = 3000.0
	# Also cap distance relative to scene size to avoid overly far framing
	var diag: float = aabb.size.length()
	var rel_cap: float = diag * 1.5
	distance = clamp(distance, min_dist, min(max_dist, rel_cap))
	# Set camera position and orientation (level, centered in Y)
	var cam_pos := center + (dir_hint * distance)
	cam_pos.y = center.y
	_pancake_cam.global_position = cam_pos
	_pancake_cam.look_at(Vector3(center.x, center.y, center.z), up)
	_pancake_cam.current = true
	_pancake_cam.near = 0.05
	print("[CAMERA_FRAME] vfov=", fov_used, " distance=", distance, " center=", center, " aabb.size=", aabb.size)
	_log_objects_relative_to_camera("after_auto_frame")

## Computes AABB only over cortical and brain region visualizations for reliable framing
func _compute_scene_aabb() -> AABB:
	var have: bool = false
	var merged := AABB()
	# Merge cortical area visualizations
	for viz in _cortical_visualizations_by_ID.values():
		if viz is Node:
			var a := _compute_world_aabb(viz)
			if a.size != Vector3.ZERO or !a.position.is_equal_approx(Vector3.ZERO):
				merged = a if !have else merged.merge(a)
				have = true
	# Merge brain region frames
	for viz in _brain_region_visualizations_by_ID.values():
		if viz is Node:
			var a := _compute_world_aabb(viz)
			if a.size != Vector3.ZERO or !a.position.is_equal_approx(Vector3.ZERO):
				merged = a if !have else merged.merge(a)
				have = true
	# Fallback to entire 3D root
	if !have:
		return _compute_world_aabb(_node_3D_root)
	return merged

## Computes tight AABB from cortical area data only (FEAGI coords + dimensions -> Godot space)
func _compute_cortical_data_aabb() -> AABB:
	var have := false
	var merged := AABB()
	for viz in _cortical_visualizations_by_ID.values():
		if viz == null:
			continue
		var ca = viz.get("cortical_area")
		if ca == null:
			continue
		var dims = ca.get("dimensions_3D")
		var coords = ca.get("coordinates_3D")
		if dims == null or coords == null:
			continue
		var dimv: Vector3 = Vector3(dims)
		var coordv: Vector3 = Vector3(coords)
		# FEAGI LLF -> Godot min/max
		var min_g: Vector3 = Vector3(coordv.x, coordv.y, -(coordv.z + dimv.z))
		var max_g: Vector3 = Vector3(coordv.x + dimv.x, coordv.y + dimv.y, -coordv.z)
		var a := AABB(min_g, max_g - min_g)
		merged = a if !have else merged.merge(a)
		have = true
	return merged if have else AABB()

## Computes AABB over active previews (interactive and brain-region previews)
func _compute_previews_aabb() -> AABB:
	var have := false
	var merged := AABB()
	# Interactive previews tracked in _active_previews
	for p in _active_previews:
		if p == null:
			continue
		var a := _compute_world_aabb(p)
		if a.size != Vector3.ZERO or !a.position.is_equal_approx(Vector3.ZERO):
			merged = a if !have else merged.merge(a)
			have = true
	# Brain region previews are added as children but not tracked; include any matching class
	for child in _node_3D_root.get_children():
		if child is UI_BrainMonitor_BrainRegionPreview:
			var a2 := _compute_world_aabb(child)
			if a2.size != Vector3.ZERO or !a2.position.is_equal_approx(Vector3.ZERO):
				merged = a2 if !have else merged.merge(a2)
				have = true
	return merged if have else AABB()

## Debug helper: logs which major objects are in front of vs behind the camera based on dot product with camera forward
func _log_objects_relative_to_camera(context: String = "") -> void:
	if _pancake_cam == null:
		return
	var cam_pos: Vector3 = _pancake_cam.global_position
	var cam_fwd: Vector3 = -_pancake_cam.global_transform.basis.z
	var in_front: Array[String] = []
	var behind: Array[String] = []

	# Collect cortical area viz
	for viz in _cortical_visualizations_by_ID.values():
		if viz is Node:
			var a := _compute_world_aabb(viz)
			var center := a.position + (a.size / 2.0)
			var v := center - cam_pos
			var d: float = v.length()
			var dotv: float = v.normalized().dot(cam_fwd)
			var name_str: String = (str(viz.name) if viz != null else "unknown")
			var label: String = name_str + " d=" + str(snapped(d, 0.01))
			if dotv >= 0.0:
				in_front.append(label)
			else:
				behind.append(label)

	# Collect brain region frames
	for viz in _brain_region_visualizations_by_ID.values():
		if viz is Node:
			var a := _compute_world_aabb(viz)
			var center := a.position + (a.size / 2.0)
			var v := center - cam_pos
			var d: float = v.length()
			var dotv: float = v.normalized().dot(cam_fwd)
			var name_str2: String = (str(viz.name) if viz != null else "unknown")
			var label: String = name_str2 + " d=" + str(snapped(d, 0.01))
			if dotv >= 0.0:
				in_front.append(label)
			else:
				behind.append(label)

	print("[CAMERA_VIS] ", context, " in_front=", in_front.size(), " behind=", behind.size())
	if in_front.size() > 0:
		print("[CAMERA_VIS] front samples: ", ", ".join(in_front.slice(0, min(5, in_front.size()))))
	if behind.size() > 0:
		print("[CAMERA_VIS] behind samples: ", ", ".join(behind.slice(0, min(5, behind.size()))))

## User moved camera - print detailed framing diagnostics for learning desired heuristics
func _on_user_camera_moved() -> void:
	if _pancake_cam == null:
		return
	var aabb := _compute_scene_aabb()
	var center := aabb.position + (aabb.size / 2.0)
	var cam_pos := _pancake_cam.global_position
	var cam_fwd := -_pancake_cam.global_transform.basis.z
	var vfov := _pancake_cam.fov
	var vp := _pancake_cam.get_viewport().get_visible_rect().size
	var aspect: float = vp.x / max(1.0, vp.y)
	var dist := cam_pos.distance_to(center)
	print("[CAMERA_SAMPLES] pos=", cam_pos, " look_at=", center, " dist=", snapped(dist, 0.01), " vfov=", vfov, " aspect=", snapped(aspect, 0.001), " aabb_pos=", aabb.position, " aabb_size=", aabb.size)

## Handle user pressing R to reset camera using auto-frame logic
func _on_user_camera_reset_requested() -> void:
	await _auto_frame_camera_to_objects()


func _update_tab_title_after_setup() -> void:
	if _representing_region and get_parent() is TabContainer:
		var tab_container = get_parent() as TabContainer
		var tab_index = tab_container.get_tab_idx_from_control(self)
		if tab_index >= 0:
			tab_container.set_tab_title(tab_index, _representing_region.friendly_name)


func _process_user_input(bm_input_events: Array[UI_BrainMonitor_InputEvent_Abstract]) -> void:
	var current_space: PhysicsDirectSpaceState3D = _world_3D.direct_space_state
	var currently_moused_over_volumes: Array[UI_BrainMonitor_CorticalArea] = []
	var currently_mousing_over_neurons: Dictionary[UI_BrainMonitor_CorticalArea, Array] = {} # where Array is an Array of Vector3i representing Neuron Coordinates
	
	for bm_input_event in bm_input_events: # multiple events can happen at once
		
		if bm_input_event is UI_BrainMonitor_InputEvent_Hover:
			var hit: Dictionary = current_space.intersect_ray(bm_input_event.get_ray_query())
			# Quick Connect: while active, update guide end position to current mouse tip world point
			if _qc_guide_active:
				var end_point: Vector3
				var is_over_cortical: bool = false
				if hit.is_empty():
					# Fallback: keep at the mouse tip but limit depth (Z) relative to camera
					var rq: PhysicsRayQueryParameters3D = bm_input_event.get_ray_query()
					var ray_from: Vector3 = rq.from
					var ray_to: Vector3 = rq.to
					var cam: Camera3D = _pancake_cam
					var forward: Vector3 = (-cam.global_transform.basis.z).normalized()
					var from_to: Vector3 = ray_to - ray_from
					# project vector onto camera forward to get depth along view, clamp depth
					var depth_along_view: float = from_to.dot(forward)
					var clamped_depth: float = clamp(depth_along_view, 0.0, _qc_guide_off_target_depth)
					# recompute endpoint along the ray direction but with limited depth component
					var ray_dir: Vector3 = from_to.normalized()
					# Find scale such that ray_dir's projection on forward equals clamped_depth
					var proj_on_fwd: float = max(0.0001, ray_dir.dot(forward))
					var scale: float = clamped_depth / proj_on_fwd
					end_point = ray_from + ray_dir * scale
				else:
					end_point = hit[&"position"]
					var collider_parent = (hit[&"collider"] as Node).get_parent()
					is_over_cortical = collider_parent is UI_BrainMonitor_AbstractCorticalAreaRenderer
					# Cap distance when over cortical as well (using a larger cap)
					var vec2: Vector3 = end_point - _qc_guide_start
					var d2: float = vec2.length()
					if d2 > _qc_guide_max_distance_on_target:
						end_point = _qc_guide_start + vec2.normalized() * _qc_guide_max_distance_on_target
				_set_quick_connect_guide_color(is_over_cortical)
				update_quick_connect_guide(end_point)
			if hit.is_empty():
				# Mousing over nothing right now
				
				_UI_layer_for_BM.clear() # temp!
				
				continue
				
			var hit_body: StaticBody3D = hit[&"collider"]
			
			# PRIORITY: Plate click areas first so we don't short-circuit on region frame parent
			if hit_body.name == "InputPlateClickArea" or hit_body.name == "OutputPlateClickArea" or hit_body.name == "ConflictPlateClickArea":
				var region_frame = hit_body.get_parent()
				if region_frame and _UI_layer_for_BM:
					var plate_kind := ""
					match hit_body.name:
						"InputPlateClickArea": plate_kind = "Input plate"
						"OutputPlateClickArea": plate_kind = "Output plate"
						"ConflictPlateClickArea": plate_kind = "Conflict plate"
						_:
							plate_kind = "Plate"
					var region_name: String = "Region"
					if region_frame and region_frame.get("representing_region") != null:
						var rep = region_frame.get("representing_region")
						var fname = rep.get("friendly_name") if rep != null else null
						if fname != null:
							region_name = str(fname)
					_UI_layer_for_BM.show_plate_hover(region_name, plate_kind)
			# Check if we hit a cortical area renderer
			elif hit_body.get_parent() is UI_BrainMonitor_AbstractCorticalAreaRenderer:
				var hit_parent: UI_BrainMonitor_AbstractCorticalAreaRenderer = hit_body.get_parent()
				if not hit_parent:
					continue # this shouldn't be possible
				var hit_world_location: Vector3 = hit["position"]
				var hit_parent_parent: UI_BrainMonitor_CorticalArea = hit_parent.get_parent_BM_abstraction()
				var neuron_coordinate_mousing_over: Vector3i = hit_parent.world_godot_position_to_neuron_coordinate(hit_world_location)
				if not hit_parent_parent:
					continue # this shouldnt be possible
				
				currently_moused_over_volumes.append(hit_parent_parent)
				if hit_parent_parent in currently_mousing_over_neurons:
					if neuron_coordinate_mousing_over not in currently_mousing_over_neurons[hit_parent_parent]:
						currently_mousing_over_neurons[hit_parent_parent].append(neuron_coordinate_mousing_over)
				else:
					var typed_arr: Array[Vector3i] = [neuron_coordinate_mousing_over]
					currently_mousing_over_neurons[hit_parent_parent] = typed_arr
				
				_UI_layer_for_BM.mouse_over_single_cortical_area(hit_parent_parent.cortical_area, neuron_coordinate_mousing_over)# temp!
			
			# Check if we hit a brain region frame (by checking script global name)
			elif hit_body.get_parent() and hit_body.get_parent().get_script() and hit_body.get_parent().get_script().get_global_name() == "UI_BrainMonitor_BrainRegion3D":
				var region_frame = hit_body.get_parent()  # UI_BrainMonitor_BrainRegion3D
				if region_frame:
					region_frame.set_hover_state(true)
					print("🧠 Hovering over red line wireframe brain region: %s" % region_frame.representing_region.friendly_name)
					# Fallback plate detection by hit position against plate meshes (in case plate colliders weren't hit)
					if _UI_layer_for_BM:
						var hit_pos: Vector3 = hit["position"]
						var plate_map := {
							"Input plate": "RegionAssembly/InputPlate",
							"Output plate": "RegionAssembly/OutputPlate",
							"Conflict plate": "RegionAssembly/ConflictPlate"
						}
						var plate_wire_map := {
							"Input plate": "RegionAssembly/InputPlate_Wireframe",
							"Output plate": "RegionAssembly/OutputPlate_Wireframe",
							"Conflict plate": "RegionAssembly/ConflictPlate_Wireframe"
						}
						for plate_label in plate_map.keys():
							if region_frame.has_node(plate_map[plate_label]) or region_frame.has_node(plate_wire_map[plate_label]):
								var plate_path = plate_map[plate_label] if region_frame.has_node(plate_map[plate_label]) else plate_wire_map[plate_label]
								var plate: MeshInstance3D = region_frame.get_node(plate_path)
								if plate.mesh is BoxMesh:
									var box: BoxMesh = plate.mesh as BoxMesh
									var half_x = box.size.x * 0.5
									var half_z = box.size.z * 0.5
									# Project the view ray onto the plate's Z level for precise Z matching
									var rq: PhysicsRayQueryParameters3D = bm_input_event.get_ray_query()
									var ray_from: Vector3 = rq.from
									var ray_to: Vector3 = rq.to
									var z_plate: float = plate.global_position.z
									var z_dir: float = ray_to.z - ray_from.z
									if abs(z_dir) < 0.0001:
										continue
									var t: float = (z_plate - ray_from.z) / z_dir
									if t < 0.0 or t > 1.0:
										continue
									var projected: Vector3 = ray_from.lerp(ray_to, t)
									var local: Vector3 = plate.global_transform.affine_inverse() * projected
									if abs(local.x) <= half_x and abs(local.z) <= half_z:
										_UI_layer_for_BM.show_plate_hover(region_frame.representing_region.friendly_name, plate_label)
										break
			# Check if we hit a plate click area (input/output/conflict)
			elif hit_body.name == "InputPlateClickArea" or hit_body.name == "OutputPlateClickArea" or hit_body.name == "ConflictPlateClickArea":
				var region_frame = hit_body.get_parent()
				if region_frame and _UI_layer_for_BM:
					var plate_kind := ""
					match hit_body.name:
						"InputPlateClickArea": plate_kind = "Input plate"
						"OutputPlateClickArea": plate_kind = "Output plate"
						"ConflictPlateClickArea": plate_kind = "Conflict plate"
						_:
							plate_kind = "Plate"
					var region_name := "Region"
					if region_frame.representing_region:
						region_name = region_frame.representing_region.friendly_name
					_UI_layer_for_BM.show_plate_hover(region_name, plate_kind)
			
		elif bm_input_event is UI_BrainMonitor_InputEvent_Click:
			
			# special cases for actions
			if bm_input_event.button == UI_BrainMonitor_InputEvent_Abstract.CLICK_BUTTON.FIRE_SELECTED_NEURONS && bm_input_event.button_pressed: # special case when firing neurons
				# Process FIRE_SELECTED_NEURONS event
				var dict: Dictionary[StringName, Array] = {}
				for BM_cortical_area in _cortical_visualizations_by_ID.values():
					# Check if the cortical area object is still valid before accessing it
					if not is_instance_valid(BM_cortical_area) or not BM_cortical_area.cortical_area:
						continue
					var selected_neurons: Array[Vector3i] = BM_cortical_area.get_neuron_selection_states()
					if !selected_neurons.is_empty():
						dict[BM_cortical_area.cortical_area.cortical_ID] = selected_neurons
				# Emit signal to fire selected neurons
				requesting_to_fire_selected_neurons.emit(dict)
				return
			if bm_input_event.button == UI_BrainMonitor_InputEvent_Abstract.CLICK_BUTTON.CLEAR_ALL_SELECTED_NEURONS && bm_input_event.button_pressed: # special case when clearing all neurons
				for bm_cortical_area in _cortical_visualizations_by_ID.values():
					# Check if the cortical area object is still valid before accessing it
					if not is_instance_valid(bm_cortical_area):
						continue
					bm_cortical_area.clear_all_neuron_selection_states() # slow but I dont care right now
			
			
			
			var hit: Dictionary = current_space.intersect_ray(bm_input_event.get_ray_query())
			if hit.is_empty():
				# Clicking over nothing
				# Clear plate hover label if we click on empty space
				if _UI_layer_for_BM:
					_UI_layer_for_BM.clear_plate_hover()
				continue
				
			var hit_body: StaticBody3D = hit[&"collider"]
			
			# Check if we hit a cortical area renderer
			if hit_body.get_parent() is UI_BrainMonitor_AbstractCorticalAreaRenderer:
				var hit_parent: UI_BrainMonitor_AbstractCorticalAreaRenderer = hit_body.get_parent()
				if not hit_parent:
					continue # this shouldn't be possible
				var hit_world_location: Vector3 = hit["position"]
				var hit_parent_parent: UI_BrainMonitor_CorticalArea = hit_parent.get_parent_BM_abstraction()
				var neuron_coordinate_clicked: Vector3i = hit_parent.world_godot_position_to_neuron_coordinate(hit_world_location)
				if hit_parent_parent:
					currently_moused_over_volumes.append(hit_parent_parent)
					var arr_test: Array[GenomeObject] = [hit_parent_parent.cortical_area]
					if bm_input_event.button_pressed:
						if UI_BrainMonitor_InputEvent_Abstract.CLICK_BUTTON.HOLD_TO_SELECT_NEURONS in bm_input_event.all_buttons_being_held:
							# Additional safety check - object might have been freed between initial check and method calls
							if not is_instance_valid(hit_parent_parent) or not hit_parent_parent.cortical_area:
								continue
							var is_neuron_selected: bool = hit_parent_parent.toggle_neuron_selection_state(neuron_coordinate_clicked)
							cortical_area_selected_neurons_changed.emit(hit_parent_parent.cortical_area, hit_parent_parent.get_neuron_selection_states())
							cortical_area_selected_neurons_changed_delta.emit(hit_parent_parent.cortical_area, neuron_coordinate_clicked, is_neuron_selected)
						else:
							if bm_input_event.button == UI_BrainMonitor_InputEvent_Abstract.CLICK_BUTTON.MAIN:
								# Additional safety check - object might have been freed
								if not is_instance_valid(hit_parent_parent) or not hit_parent_parent.cortical_area:
									continue
								BV.UI.selection_system.select_objects(SelectionSystem.SOURCE_CONTEXT.UNKNOWN, arr_test)
								BV.UI.selection_system.cortical_area_voxel_clicked(hit_parent_parent.cortical_area, neuron_coordinate_clicked)
								#BV.UI.window_manager.spawn_quick_cortical_menu(arr_test)
								#clicked_cortical_area.emit(hit_parent_parent.cortical_area)
			
			# Check if we hit a brain region frame (by checking script global name)
			elif hit_body.get_parent() and hit_body.get_parent().get_script() and hit_body.get_parent().get_script().get_global_name() == "UI_BrainMonitor_BrainRegion3D":
				var region_frame = hit_body.get_parent()  # UI_BrainMonitor_BrainRegion3D
				if region_frame and bm_input_event.button_pressed:
					if bm_input_event.button == UI_BrainMonitor_InputEvent_Abstract.CLICK_BUTTON.MAIN:
						# Single click on brain region - select it
						BV.UI.selection_system.clear_all_highlighted()
						BV.UI.selection_system.add_to_highlighted(region_frame.representing_region)
						BV.UI.selection_system.select_objects(SelectionSystem.SOURCE_CONTEXT.UNKNOWN)
						print("🧠 Clicked brain region frame: %s" % region_frame.representing_region.friendly_name)
						
						# Check for double-click (simple implementation)
						region_frame.handle_double_click()
			# If clicking on a plate, clear the label on mouse up (we only show on hover)
			elif hit_body.name == "InputPlateClickArea" or hit_body.name == "OutputPlateClickArea" or hit_body.name == "ConflictPlateClickArea":
				if _UI_layer_for_BM and not bm_input_event.button_pressed:
					_UI_layer_for_BM.clear_plate_hover()
			
	
	# Higlight what has been moused over (and unhighlight what hasnt) (this is slow but not really a problem right now)
	for previously_moused_over_volume in _previously_moused_over_volumes:
		if previously_moused_over_volume not in currently_moused_over_volumes:
			previously_moused_over_volume.set_hover_over_volume_state(false)
	for currently_moused_over_volume in currently_moused_over_volumes:
		if currently_moused_over_volume not in _previously_moused_over_volumes:
			currently_moused_over_volume.set_hover_over_volume_state(true)
	_previously_moused_over_volumes = currently_moused_over_volumes
	
	# highlight neurons that are moused over (and unhighlight what wasnt)
	currently_mousing_over_neurons.merge(_previously_moused_over_cortical_area_neurons, false)
	for cortical_area in currently_mousing_over_neurons.keys():
		var typed_arr: Array[UI_BrainMonitor_CorticalArea] = []
		if len(currently_mousing_over_neurons[cortical_area]) == 0:
			# Cortical area has nothing hovering over it, tell the renderer to clear it
			cortical_area.clear_hover_state_for_all_neurons()
			currently_mousing_over_neurons.erase(cortical_area)
		else:
			# cortical area has things hovering over it, tell renderer to show it
			cortical_area.set_highlighted_neurons(currently_mousing_over_neurons[cortical_area])
		currently_mousing_over_neurons[cortical_area] = typed_arr
	_previously_moused_over_cortical_area_neurons = currently_mousing_over_neurons

#region Interaction

func clear_all_selected_cortical_area_neurons() -> void:
	for area: UI_BrainMonitor_CorticalArea in _cortical_visualizations_by_ID.values():
		area.clear_all_neuron_selection_states()

func set_further_neuron_selection_restriction_to_cortical_area(restrict_to: AbstractCorticalArea) -> void:
	if restrict_to.cortical_ID in _cortical_visualizations_by_ID:
		_restrict_neuron_selection_to = restrict_to

func remove_neuron_cortical_are_selection_restrictions() -> void:
	_restrict_neuron_selection_to = null

## Allows any external element to create a 3D preview in this BM that it can edit and free as needed
func create_preview(initial_FEAGI_position: Vector3i, initial_dimensions: Vector3i, show_voxels: bool, cortical_area_type: AbstractCorticalArea.CORTICAL_AREA_TYPE = AbstractCorticalArea.CORTICAL_AREA_TYPE.UNKNOWN, existing_cortical_area: AbstractCorticalArea = null) -> UI_BrainMonitor_InteractivePreview:
	var preview: UI_BrainMonitor_InteractivePreview = UI_BrainMonitor_InteractivePreview.new()
	_node_3D_root.add_child(preview)  # CRITICAL FIX: Add to 3D scene root, not brain monitor container
	preview.setup(initial_FEAGI_position, initial_dimensions, show_voxels, cortical_area_type, existing_cortical_area)
	_active_previews.append(preview)
	preview.tree_exiting.connect(_preview_closing)
	# Defer indicator spawn to ensure preview children are initialized and transforms updated
	_spawn_indicator_for_node_center(preview)
	# Keep camera framing valid while preview is added or moved/resized by user
	preview.user_moved_preview.connect(func(_pos: Vector3i):
		# Debounce: schedule after one frame
		get_tree().create_timer(0.0).timeout.connect(func(): _auto_frame_camera_to_objects())
	)
	preview.user_resized_preview.connect(func(_dim: Vector3i):
		get_tree().create_timer(0.0).timeout.connect(func(): _auto_frame_camera_to_objects())
	)
	# Immediately frame to include this new preview (deferred by one frame)
	get_tree().create_timer(0.0).timeout.connect(func(): _auto_frame_camera_to_objects())
	return preview

## Allows external elements to create a brain region preview showing dual plates
func create_brain_region_preview(brain_region: BrainRegion, initial_FEAGI_position: Vector3i) -> UI_BrainMonitor_BrainRegionPreview:
	var preview: UI_BrainMonitor_BrainRegionPreview = UI_BrainMonitor_BrainRegionPreview.new()
	_node_3D_root.add_child(preview)  # Add to 3D scene root
	preview.setup(brain_region, initial_FEAGI_position)
	preview.tree_exiting.connect(_brain_region_preview_closing)
	print("🔮 Created brain region preview for: %s" % brain_region.friendly_name)
	# Defer indicator spawn to ensure preview children are initialized and transforms updated
	_spawn_indicator_for_node_center(preview)
	# Reframe when brain-region preview is created or moved (defer by one frame)
	get_tree().create_timer(0.0).timeout.connect(func(): _auto_frame_camera_to_objects())
	if not preview.user_moved_preview.is_connected(func(_p): pass):
		preview.user_moved_preview.connect(func(_pos: Vector3i):
			get_tree().create_timer(0.0).timeout.connect(func(): _auto_frame_camera_to_objects())
		)
	return preview

## Closes all currently active previews
func clear_all_open_previews() -> void:
	var previews_duplicated: Array[UI_BrainMonitor_InteractivePreview] = _active_previews.duplicate()
	for active_preview in previews_duplicated:
		if active_preview:
			active_preview.queue_free()
	_active_previews = []

## Called when the preview is about to be free'd for any reason
func _preview_closing(preview: UI_BrainMonitor_InteractivePreview):
	_active_previews.erase(preview)

## Called when a brain region preview is about to be freed
func _brain_region_preview_closing():
	pass  # Preview cleanup is handled automatically when the node is freed


#endregion


#region Quick Connect Guide Curve
## Starts a live curved guide from a source cortical area's center to the mouse pointer
func start_quick_connect_guide(source_area: AbstractCorticalArea) -> void:
	"""
	Start rendering a 3D curved guide line from the given source cortical area's center.
	The guide's end will follow the mouse tip using world ray hits while active.
	"""
	if source_area == null:
		return
	# Resolve the cortical area's visualization in this brain monitor
	var viz: UI_BrainMonitor_CorticalArea = get_cortical_area_visualization(source_area.cortical_ID)
	if viz == null:
		return
	# Compute world-space start at the cortical area's center
	var start_pos: Vector3 = viz._get_cortical_area_center_position()
	if start_pos == Vector3.ZERO:
		return
	# Reset any previous guide
	stop_quick_connect_guide()
	_qc_guide_start = start_pos
	_qc_guide_node = Node3D.new()
	_qc_guide_node.name = "QC_Guide"
	_node_3D_root.add_child(_qc_guide_node)
	# Create (once) a neutral, bright material similar to our connection visuals
	if _qc_guide_material == null:
		_qc_guide_material = _create_qc_guide_material()
	_qc_guide_active = true
	# Initialize with a tiny segment to avoid a frame of emptiness
	update_quick_connect_guide(_qc_guide_start)

## Updates the live guide's end position; call on hover world hit updates
func update_quick_connect_guide(end_pos: Vector3) -> void:
	"""
	Update the guide curve end point. No-ops if guide is not active.
	"""
	if not _qc_guide_active or _qc_guide_node == null:
		return
	_rebuild_qc_guide_curve(_qc_guide_start, end_pos)

## Stops and clears the live guide curve if present
func stop_quick_connect_guide() -> void:
	"""
	Stop rendering the guide and free any guide nodes.
	"""
	if _qc_guide_node != null:
		_qc_guide_node.queue_free()
		_qc_guide_node = null
	_qc_guide_active = false

## Internal: rebuilds the guide from start to end as a Bézier arc using thin cylinder segments
func _rebuild_qc_guide_curve(start_pos: Vector3, end_pos: Vector3) -> void:
	# Clear old segments
	for child in _qc_guide_node.get_children():
		child.queue_free()
	# Compute a pleasing upward arc
	var raw_direction := (end_pos - start_pos)
	var distance := clamp(raw_direction.length(), _qc_guide_min_distance, _qc_guide_max_distance)
	# Clamp end point to max distance to avoid runaway curves
	var direction := raw_direction
	if raw_direction.length() > distance:
		direction = raw_direction.normalized() * distance
		end_pos = start_pos + direction
	var mid := (start_pos + end_pos) / 2.0
	# Limit arc height and keep proportional for near distances
	var arc_height := clamp(distance * 0.35, 0.5, _qc_guide_max_arc_height)
	var control := mid + Vector3(0.0, arc_height, 0.0)
	# Create segments along a quadratic Bézier
	var num_segments := 12
	for i in range(num_segments):
		var t1 := float(i) / float(num_segments)
		var t2 := float(i + 1) / float(num_segments)
		var p1 := _quadratic_bezier(start_pos, control, end_pos, t1)
		var p2 := _quadratic_bezier(start_pos, control, end_pos, t2)
		var seg := _create_qc_guide_segment(p1, p2, i)
		_qc_guide_node.add_child(seg)

## Internal: create a thin cylinder segment aligned between two points
func _create_qc_guide_segment(start_pos: Vector3, end_pos: Vector3, idx: int) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "QC_GuideSegment_" + str(idx)
	var direction := (end_pos - start_pos)
	var seg_len := max(0.001, direction.length())
	var center := (start_pos + end_pos) / 2.0
	var cyl := CylinderMesh.new()
	cyl.top_radius = _qc_guide_current_radius
	cyl.bottom_radius = _qc_guide_current_radius
	cyl.height = seg_len
	cyl.radial_segments = 6
	cyl.rings = 1
	mesh_instance.mesh = cyl
	mesh_instance.position = center
	# Align cylinder Y axis with direction
	if direction.length() > 0.001:
		var n := direction.normalized()
		var up := Vector3.UP
		if abs(n.dot(Vector3.UP)) > 0.9:
			up = Vector3.FORWARD
		var right := up.cross(n).normalized()
		var corrected_up := n.cross(right).normalized()
		mesh_instance.basis = Basis(right, n, corrected_up)
	mesh_instance.material_override = _qc_guide_material
	return mesh_instance

## Internal: material for the guide (neutral bright, semi-transparent)
func _create_qc_guide_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 1.0, 1.0, 0.9)
	m.emission_color = Color(0.9, 0.9, 0.9)
	m.emission_enabled = true
	m.emission_energy = 2.4
	m.flags_unshaded = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

## Internal: set color of guide based on hover validity (green on cortical, red otherwise)
func _set_quick_connect_guide_color(is_valid_target: bool) -> void:
	if _qc_guide_material == null:
		return
	# Adjust thickness instead of color to avoid confusion with conn. semantics
	_qc_guide_current_radius = _qc_guide_radius_thick if is_valid_target else _qc_guide_radius_thin
	# Optionally add a subtle emission change for feedback without semantic color
	_qc_guide_material.emission_energy = 3.0 if is_valid_target else 2.2

## Internal: quadratic Bézier interpolation used for the arc
func _quadratic_bezier(p0: Vector3, p1: Vector3, p2: Vector3, t: float) -> Vector3:
	# Guard against out-of-range t values due to float inaccuracy
	var tt: float = float(clamp(t, 0.0, 1.0))
	var u: float = 1.0 - tt
	return u * u * p0 + 2.0 * u * tt * p1 + tt * tt * p2
#endregion


#region Cache Responses

# NOTE: Cortical area movements, resizes, and renames are handled by the [UI_BrainMonitor_CorticalArea]s themselves!

func _add_cortical_area(area: AbstractCorticalArea) -> UI_BrainMonitor_CorticalArea:
	# print("🚨 _add_cortical_area() CALLED for area: %s in brain monitor instance %d (region: %s)" % [area.cortical_ID, get_instance_id(), _representing_region.friendly_name])  # Suppressed - causes output overflow
	
	# Show call stack to find who's calling this - SUPPRESSED DUE TO OUTPUT OVERFLOW
	# print("🚨 CALL STACK for _add_cortical_area:")
	# var stack = get_stack()
	# stack.reverse()
	# for i in range(min(3, stack.size())):
	# 	var frame = stack[i]
	# 	print("  %d. %s:%s in %s()" % [i, frame.source, frame.line, frame.function])
	if area.cortical_ID in _cortical_visualizations_by_ID:
		push_warning("Unable to add to BM already existing cortical area of ID %s!" % area.cortical_ID)
		return null
	
	# Check if this area should be created
	var is_directly_in_root = _representing_region.is_cortical_area_in_region_directly(area)
	var is_io_of_child_region = _is_area_input_output_of_child_region(area)
	
	
	# Only create if the area is directly in this region OR it's needed as I/O for a child region
	if not is_directly_in_root and not is_io_of_child_region:
		return null
	# print("  🎯 CRITICAL: Adding %s to 3D scene of brain monitor for region %s" % [area.cortical_ID, _representing_region.friendly_name])  # Suppressed - too verbose
	# print("  🎯 INSTANCE: Adding to brain monitor instance %d" % get_instance_id())  # Suppressed - too verbose
	# print("  🎯 INSTANCE: Adding to 3D root %s (instance %d)" % [_node_3D_root, _node_3D_root.get_instance_id()])  # Suppressed - too verbose
	
	var rendering_area: UI_BrainMonitor_CorticalArea = UI_BrainMonitor_CorticalArea.new()
	_node_3D_root.add_child(rendering_area)
	# print("  🎯 ADDED: Cortical area %s added as child to 3D root instance %d" % [area.cortical_ID, _node_3D_root.get_instance_id()])  # Suppressed - too verbose
	rendering_area.setup(area)
	_cortical_visualizations_by_ID[area.cortical_ID] = rendering_area
	
	# print("  📍 Area coordinates: %s" % area.coordinates_3D)  # Suppressed - too frequent
	# print("  🎯 Total areas in this brain monitor: %d" % _cortical_visualizations_by_ID.size())  # Suppressed - too frequent
	
	area.about_to_be_deleted.connect(_remove_cortical_area.bind(area))
	area.coordinates_3D_updated.connect(rendering_area.set_new_position)
	
	# If this area is I/O of a child region, it will be moved later by the brain region component
	# For now, position it normally - it will be repositioned when brain regions populate
	pass  # I/O areas will be repositioned by brain region wireframes
	
	return rendering_area

## Gets an existing cortical area visualization by ID (used by brain region frames)
func get_cortical_area_visualization(cortical_id: String) -> UI_BrainMonitor_CorticalArea:
	return _cortical_visualizations_by_ID.get(cortical_id, null)

## Check if this brain monitor is currently visualizing a specific cortical area
func has_cortical_area_visualization(cortical_id: String) -> bool:
	return cortical_id in _cortical_visualizations_by_ID

func _remove_cortical_area(area: AbstractCorticalArea) -> void:
	if area.cortical_ID not in _cortical_visualizations_by_ID:
		push_warning("Unable to remove from BM nonexistant cortical area of ID %s!" % area.cortical_ID)
		return
	var rendering_area: UI_BrainMonitor_CorticalArea = _cortical_visualizations_by_ID[area.cortical_ID]
	_previously_moused_over_volumes.erase(rendering_area)
	_previously_moused_over_cortical_area_neurons.erase(rendering_area)
	rendering_area.queue_free()
	_cortical_visualizations_by_ID.erase(area.cortical_ID)

func _add_brain_region_frame(brain_region: BrainRegion):  # -> UI_BrainMonitor_BrainRegion3D
	# print("🚨🚨🚨 DEBUG: _add_brain_region_frame called for: %s" % brain_region.friendly_name)  # Suppressed - causes output overflow
	if brain_region.region_ID in _brain_region_visualizations_by_ID:
		push_warning("Unable to add to BM already existing brain region of ID %s!" % brain_region.region_ID)
		return null
	
	var brain_region_script = load("res://addons/UI_BrainMonitor/UI_BrainMonitor_BrainRegion3D.gd")
	var region_frame = brain_region_script.new()  # UI_BrainMonitor_BrainRegion3D
	_node_3D_root.add_child(region_frame)
	region_frame.setup(brain_region)
	_brain_region_visualizations_by_ID[brain_region.region_ID] = region_frame
	
	# Connect region frame signals
	region_frame.region_double_clicked.connect(_on_brain_region_double_clicked)
	region_frame.region_hover_changed.connect(_on_brain_region_hover_changed)
	brain_region.about_to_be_deleted.connect(_remove_brain_region_frame.bind(brain_region))
	
	return region_frame

func _remove_brain_region_frame(brain_region: BrainRegion) -> void:
	if brain_region.region_ID not in _brain_region_visualizations_by_ID:
		push_warning("Unable to remove from BM nonexistant brain region of ID %s!" % brain_region.region_ID)
		return
	var region_frame = _brain_region_visualizations_by_ID[brain_region.region_ID]  # UI_BrainMonitor_BrainRegion3D
	region_frame.queue_free()
	_brain_region_visualizations_by_ID.erase(brain_region.region_ID)

func _on_brain_region_double_clicked(brain_region: BrainRegion) -> void:
	# TODO: Implement navigation/diving into brain region (future tab system)
	pass
	
func _on_brain_region_hover_changed(brain_region: BrainRegion, is_hovered: bool) -> void:
	pass

## Checks if a cortical area is I/O of a specific child region (using same logic as brain region)
func _is_area_input_output_of_specific_child_region(area: AbstractCorticalArea, child_region: BrainRegion) -> bool:
	# Checking if area is I/O of specific child region - debug output suppressed
	
	# Method 1: Check connection chain links first
	# Checking input chain links - debug output suppressed
	for link: ConnectionChainLink in child_region.input_open_chain_links:
		if link.destination == area:
			print("        ✅ Found as INPUT via chain link!")
			return true
	
	# print("        📤 Checking %d output_open_chain_links..." % child_region.output_open_chain_links.size())  # Suppressed - too spammy
	for link: ConnectionChainLink in child_region.output_open_chain_links:
		if link.source == area:
			return true
	
	# Method 2: Check partial mappings (from FEAGI direct inputs/outputs arrays) - CRITICAL FIX!
	for partial_mapping in child_region.partial_mappings:
		if partial_mapping.internal_target_cortical_area == area:
			return true
	
	# Method 3: Check IPU/OPU types
	if area in child_region.contained_cortical_areas:
		if area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU:
			return true
		elif area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU:
			return true
	
	# Method 4: TEMPORARY aggressive naming heuristics (for debugging - will restore conservative logic after)
	if child_region.input_open_chain_links.size() == 0 and child_region.output_open_chain_links.size() == 0:
		if area in child_region.contained_cortical_areas and child_region.contained_cortical_areas.size() == 2:
			var area_id = area.cortical_ID.to_lower()
			# Check for input patterns  
			if "lef" in area_id or "left" in area_id or "input" in area_id or "in" in area_id:
				return true
			# Check for output patterns (c__rig should be output per FEAGI data)
			if "rig" in area_id or "right" in area_id or "output" in area_id or "out" in area_id:
				return true
	
	# print("        ❌ Area %s is NOT I/O of child region '%s'" % [area.cortical_ID, child_region.friendly_name])  # Suppressed - too spammy
	return false

## Checks if a cortical area is used as input/output by any child brain regions (using same logic as specific method)
func _is_area_input_output_of_child_region(area: AbstractCorticalArea) -> bool:
	# Check all child brain regions to see if this area is their I/O
	# print("    🔍 Checking if area %s is I/O of any child region..." % area.cortical_ID)  # Suppressed - too spammy
	
	for child_region: BrainRegion in _representing_region.contained_regions:
		# print("      🏗️ Checking child region: %s" % child_region.friendly_name)  # Suppressed - too spammy
		
		# Use the SAME logic as _is_area_input_output_of_specific_child_region
		if _is_area_input_output_of_specific_child_region(area, child_region):
			return true
	
	# print("    ❌ Area %s is NOT I/O of any child region" % area.cortical_ID)  # Suppressed - too spammy
	return false

## Cache reload event handler - refreshes all cortical area connections AND creates new brain regions
func _on_cache_reloaded_refresh_all_connections() -> void:
	# CRITICAL: Check for new brain regions that need visualization after cloning
	_create_missing_brain_region_visualizations()
	
	# Force refresh connections for all currently hovered cortical areas
	for cortical_viz in _cortical_visualizations_by_ID.values():
		if cortical_viz._is_volume_moused_over:
			cortical_viz._hide_neural_connections()
			cortical_viz._show_neural_connections()

## Creates visualizations for any new brain regions that don't have them yet (e.g., after cloning)
func _create_missing_brain_region_visualizations() -> void:
	print("🔍 DEBUG: _create_missing_brain_region_visualizations() called")
	
	if not FeagiCore.feagi_local_cache or not FeagiCore.feagi_local_cache.brain_regions:
		print("❌ DEBUG: No cache or brain_regions available")
		return
	
	var all_regions = FeagiCore.feagi_local_cache.brain_regions.available_brain_regions
	var root_region = FeagiCore.feagi_local_cache.brain_regions.get_root_region()
	var new_regions_created = 0
	
	
	for region_id in all_regions.keys():
		var region = all_regions[region_id]
		# Skip if visualization already exists
		if region_id in _brain_region_visualizations_by_ID:
			continue
		
		# CRITICAL: Skip root region - it should NEVER have a plate visualization
		if region == root_region:
			continue
		
		# Skip if this region is not a child of our representing region
		if _representing_region != null and region != _representing_region:
			var is_child = false
			for child_region in _representing_region.contained_regions:
				if child_region.region_ID == region_id:
					is_child = true
					break
			if not is_child:
				continue
		
		# Create visualization for this new region
		_add_brain_region_frame(region)
		new_regions_created += 1
	

## Manual force refresh of all cortical area connections (for debugging/troubleshooting)
func force_refresh_all_cortical_connections() -> void:
	print("BrainMonitor 3D Scene: 🔧 MANUAL REFRESH - Force refreshing all cortical area connections")

## Manual trigger for creating missing brain region visualizations (for debugging)
func force_create_missing_regions() -> void:
	print("BrainMonitor 3D Scene: 🔧 MANUAL TRIGGER - Force creating missing brain region visualizations")
	_create_missing_brain_region_visualizations()
	
	var refreshed_count = 0
	for cortical_viz in _cortical_visualizations_by_ID.values():
		# Hide any existing connections
		cortical_viz._hide_neural_connections()
		
		# If this area is currently hovered, show refreshed connections
		if cortical_viz._is_volume_moused_over:
			cortical_viz._show_neural_connections()
			refreshed_count += 1
	
	print("BrainMonitor 3D Scene: ✅ Manual refresh completed for ", refreshed_count, " areas")

#endregion
