extends Node
class_name UI_BrainMonitor_CorticalArea
## Class for rendering cortical areas in the Brain monitor
# NOTE: We will leave adding, removing, or changing parent region to the Brain Monitor itself, since those interactions affect multiple objects

var cortical_area: AbstractCorticalArea:
	get: return _representing_cortial_area

var renderer: UI_BrainMonitor_AbstractCorticalAreaRenderer:
	get: return _dda_renderer

var is_volume_moused_over: bool:
	get: return _is_volume_moused_over

var _representing_cortial_area: AbstractCorticalArea
var _dda_renderer: UI_BrainMonitor_AbstractCorticalAreaRenderer  # For translucent voxel structure
var _directpoints_renderer: UI_BrainMonitor_AbstractCorticalAreaRenderer  # For individual neuron firing

var _is_volume_moused_over: bool
var _hovered_neuron_coordinates: Array[Vector3i] = [] # wouldnt a dictionary be faster?
var _selected_neuron_coordinates: Array[Vector3i] = [] #TODO we should clear this and the hover on dimension changes!

# Neural connection visualization
var _connection_curves: Array[Node3D] = []  # Store all connection curve nodes
var _are_connections_visible: bool = false
var _pulse_tweens: Array[Tween] = []  # Store pulse animation tweens

# I/O direction indicator (magenta pulsing arrow above boundary areas)
var _io_direction_indicator: Node3D = null
var _io_direction_indicator_material: StandardMaterial3D = null
var _io_direction_indicator_mode: StringName = &"none" # "none" | "input" | "output" | "bidirectional"
var _io_direction_indicator_base_scale: Vector3 = Vector3.ONE
var _io_direction_indicator_label: Label3D = null

# Tunables for arrow look/feel
const IO_ARROW_COLOR: Color = Color(0.827, 0.706, 0.196, 0.85)  # Mustard yellow, semi-transparent
const IO_ARROW_EMISSION_COLOR: Color = Color(0.827, 0.706, 0.196, 1.0)
const IO_ARROW_PULSE_PERIOD_MS: float = 3000.0
const IO_ARROW_ALPHA_MIN: float = 0.15
const IO_ARROW_ALPHA_MAX: float = 0.75
const IO_ARROW_EMISSION_MIN: float = 1.2
const IO_ARROW_EMISSION_MAX: float = 3.2
const IO_ARROW_SIZE_MULTIPLIER: float = 3.0
const IO_ARROW_SIZE_MIN_RADIUS: float = 0.07
const IO_ARROW_SIZE_MAX_RADIUS: float = 0.22
const IO_ARROW_SIZE_MIN_SHAFT_H: float = 0.18
const IO_ARROW_SIZE_MAX_SHAFT_H: float = 0.85
const IO_ARROW_SIZE_MIN_HEAD_H: float = 0.12
const IO_ARROW_SIZE_MAX_HEAD_H: float = 0.55
const IO_ARROW_SHAFT_RADIUS_MULTIPLIER: float = 0.50
const IO_ARROW_LABEL_Y_GAP_MULT: float = 0.65  # Extra spacing above arrow head(s), in head-height units

# Distance-based scaling for pulse spheres (flow animation)
const PULSE_DISTANCE_SCALE_ENABLED: bool = true
const PULSE_DISTANCE_REF: float = 50.0
const PULSE_DISTANCE_MIN_SCALE: float = 0.7
const PULSE_DISTANCE_MAX_SCALE: float = 5.0

## Scale a pulse sphere based on distance to the active camera to keep visibility at range
func _apply_distance_scale_to_pulse(pulse_sphere: MeshInstance3D) -> void:
	if not PULSE_DISTANCE_SCALE_ENABLED or pulse_sphere == null:
		return
	# Check if the node is in the scene tree before accessing global_position
	if not pulse_sphere.is_inside_tree():
		# Node not in tree yet, use default scale and defer scaling until next frame when it should be in tree
		pulse_sphere.scale = Vector3(PULSE_DISTANCE_MIN_SCALE, PULSE_DISTANCE_MIN_SCALE, PULSE_DISTANCE_MIN_SCALE)
		call_deferred("_apply_distance_scale_to_pulse", pulse_sphere)
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var cam := viewport.get_camera_3d()
	if cam == null:
		return
	var dist: float = cam.global_position.distance_to(pulse_sphere.global_position)
	var s: float = clamp(dist / PULSE_DISTANCE_REF, PULSE_DISTANCE_MIN_SCALE, PULSE_DISTANCE_MAX_SCALE)
	pulse_sphere.scale = Vector3(s, s, s)


func setup(defined_cortical_area: AbstractCorticalArea) -> void:
	_representing_cortial_area = defined_cortical_area
	name = "CA_" + defined_cortical_area.cortical_ID
	
	# Create renderers based on cortical area type
	if (_representing_cortial_area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY or 
		AbstractCorticalArea.is_reserved_system_core_area(_representing_cortial_area.cortical_ID) or
		_should_use_png_icon(_representing_cortial_area)):
		# Memory, Power, Death, and PNG icon areas use only DirectPoints renderer (no DDA cube)
		_directpoints_renderer = UI_BrainMonitor_DirectPointsCorticalAreaRenderer.new()
		add_child(_directpoints_renderer)
		_directpoints_renderer.setup(_representing_cortial_area)
		# print("   🎯 Using ONLY DirectPoints renderer for: ", _representing_cortial_area.cortical_ID)  # Suppressed - causes output overflow
		# print("   🚫 NO DDA renderer created - should have no cube!")  # Suppressed - causes output overflow
	else:
		# Standard areas use DDA renderer for translucent voxel structure
		_dda_renderer = _create_renderer_depending_on_cortical_area_type(_representing_cortial_area)
		add_child(_dda_renderer)
		_dda_renderer.setup(_representing_cortial_area)
		
		# Create DirectPoints renderer for individual neuron firing
		_directpoints_renderer = UI_BrainMonitor_DirectPointsCorticalAreaRenderer.new()
		add_child(_directpoints_renderer)
		_directpoints_renderer.setup(_representing_cortial_area)
		# print("   🎯 Using BOTH DDA and DirectPoints renderers for: ", _representing_cortial_area.cortical_ID)  # Suppressed - causes output overflow
	
	# setup signals to update properties automatically for renderers
	if _dda_renderer != null:
		if not defined_cortical_area.friendly_name_updated.is_connected(_dda_renderer.update_friendly_name):
			defined_cortical_area.friendly_name_updated.connect(_dda_renderer.update_friendly_name)
		if not defined_cortical_area.coordinates_3D_updated.is_connected(_dda_renderer.update_position_with_new_FEAGI_coordinate):
			defined_cortical_area.coordinates_3D_updated.connect(_dda_renderer.update_position_with_new_FEAGI_coordinate)
		if not defined_cortical_area.dimensions_3D_updated.is_connected(_dda_renderer.update_dimensions):
			defined_cortical_area.dimensions_3D_updated.connect(_dda_renderer.update_dimensions)
	
	if _directpoints_renderer != null:
		if not defined_cortical_area.coordinates_3D_updated.is_connected(_directpoints_renderer.update_position_with_new_FEAGI_coordinate):
			defined_cortical_area.coordinates_3D_updated.connect(_directpoints_renderer.update_position_with_new_FEAGI_coordinate)
		if not defined_cortical_area.dimensions_3D_updated.is_connected(_directpoints_renderer.update_dimensions):
			defined_cortical_area.dimensions_3D_updated.connect(_directpoints_renderer.update_dimensions)
	
	# Mirror SelectionSystem highlight state to 3D renderer selection outline/highlight.
	if not defined_cortical_area.UI_highlighted_state_updated.is_connected(_on_ui_highlighted_state_updated):
		defined_cortical_area.UI_highlighted_state_updated.connect(_on_ui_highlighted_state_updated)
	_on_ui_highlighted_state_updated(defined_cortical_area.UI_is_highlighted)
	
	# Connect legacy SVO visualization data to DDA renderer (for translucent structure)
	if _dda_renderer != null:
		if not defined_cortical_area.recieved_new_neuron_activation_data.is_connected(_dda_renderer.update_visualization_data):
			defined_cortical_area.recieved_new_neuron_activation_data.connect(_dda_renderer.update_visualization_data)
	
	# Connect direct points data to DirectPoints renderer (for individual firing neurons)
	if _directpoints_renderer.has_method("_on_received_direct_neural_points"):
		if not defined_cortical_area.recieved_new_direct_neural_points.is_connected(_directpoints_renderer._on_received_direct_neural_points):
			defined_cortical_area.recieved_new_direct_neural_points.connect(_directpoints_renderer._on_received_direct_neural_points)
			# print("🔗 CONNECTED: Type 11 (Direct Neural Points) signal for DirectPoints renderer")  # Suppressed - causes output overflow
	
	# Connect bulk direct points data for optimized processing
	if _directpoints_renderer.has_method("_on_received_direct_neural_points_bulk"):
		if not defined_cortical_area.recieved_new_direct_neural_points_bulk.is_connected(_directpoints_renderer._on_received_direct_neural_points_bulk):
			defined_cortical_area.recieved_new_direct_neural_points_bulk.connect(_directpoints_renderer._on_received_direct_neural_points_bulk)
			# print("🚀 CONNECTED: Type 11 (Bulk Neural Points) signal for optimized DirectPoints rendering")  # Suppressed - causes output overflow

	# Register DirectPoints renderer resources for the desktop WS fast-path (Rust -> MultiMesh).
	# This does NOT change web export behavior (web uses WASM path).
	if _directpoints_renderer != null and _directpoints_renderer.has_method("bv_get_multimesh"):
		var mm := _directpoints_renderer.call("bv_get_multimesh") as MultiMesh
		var dims := _directpoints_renderer.call("bv_get_dimensions") as Vector3
		defined_cortical_area.BV_register_directpoints_renderer(_directpoints_renderer, mm, dims)
		
		# If renderer resources aren't ready yet (rare timing), retry registration on a deferred tick.
		# This is important for memory areas: desktop WS Type11 fast-path only updates areas with a registered MultiMesh.
		if mm == null or dims == Vector3.ZERO:
			_schedule_directpoints_fastpath_registration_retry(defined_cortical_area)
	
	# print("✅ DUAL RENDERER SETUP: DDA (translucent structure) + DirectPoints (individual neurons)")  # Suppressed - causes output overflow

	# Connect to cache reload events to refresh connection curves
	if FeagiCore.feagi_local_cache:
		if not FeagiCore.feagi_local_cache.cache_reloaded.is_connected(_on_cache_reloaded):
			FeagiCore.feagi_local_cache.cache_reloaded.connect(_on_cache_reloaded)
			# print("🔗 CONNECTED: Cache reload signal for connection curve refresh")  # Suppressed - causes output overflow
	
	# Connect to mapping change signals for real-time updates
	if defined_cortical_area:
		if not defined_cortical_area.afferent_input_cortical_area_added.is_connected(_on_mapping_changed):
			defined_cortical_area.afferent_input_cortical_area_added.connect(_on_mapping_changed)
		if not defined_cortical_area.afferent_input_cortical_area_removed.is_connected(_on_mapping_changed):
			defined_cortical_area.afferent_input_cortical_area_removed.connect(_on_mapping_changed)
		if not defined_cortical_area.efferent_input_cortical_area_added.is_connected(_on_mapping_changed):
			defined_cortical_area.efferent_input_cortical_area_added.connect(_on_mapping_changed)
		if not defined_cortical_area.efferent_input_cortical_area_removed.is_connected(_on_mapping_changed):
			defined_cortical_area.efferent_input_cortical_area_removed.connect(_on_mapping_changed)
		if not defined_cortical_area.recursive_cortical_area_added.is_connected(_on_mapping_changed):
			defined_cortical_area.recursive_cortical_area_added.connect(_on_mapping_changed)
		if not defined_cortical_area.recursive_cortical_area_removed.is_connected(_on_mapping_changed):
			defined_cortical_area.recursive_cortical_area_removed.connect(_on_mapping_changed)
		# print("🔗 CONNECTED: Mapping change signals for real-time curve updates")  # Suppressed - causes output overflow

	# Keep I/O direction indicator updated as the area moves/resizes (and after initial parenting settles).
	if defined_cortical_area:
		if not defined_cortical_area.coordinates_3D_updated.is_connected(_refresh_io_direction_indicator):
			defined_cortical_area.coordinates_3D_updated.connect(_refresh_io_direction_indicator)
		if not defined_cortical_area.dimensions_3D_updated.is_connected(_refresh_io_direction_indicator):
			defined_cortical_area.dimensions_3D_updated.connect(_refresh_io_direction_indicator)
	call_deferred("_refresh_io_direction_indicator")

	# Cache-level update signals (lightweight refreshes).
	if FeagiCore.feagi_local_cache:
		var cache = FeagiCore.feagi_local_cache
		if not cache.cache_reloaded.is_connected(_on_cache_reloaded):
			cache.cache_reloaded.connect(_on_cache_reloaded)
		if not cache.mappings_reloaded.is_connected(_on_cache_reloaded):
			cache.mappings_reloaded.connect(_on_cache_reloaded)
		if not cache.cortical_areas_reloaded.is_connected(_on_cache_reloaded):
			cache.cortical_areas_reloaded.connect(_on_cache_reloaded)
		if not cache.brain_regions_reloaded.is_connected(_on_cache_reloaded):
			cache.brain_regions_reloaded.connect(_on_cache_reloaded)

func _exit_tree() -> void:
	# Unregister desktop WS fast-path references only on actual teardown.
	#
	# IMPORTANT:
	# - This node is frequently re-parented (e.g. when brain-region plates "move" I/O areas onto plates).
	# - Re-parenting triggers `_exit_tree()` even though the node is not being destroyed.
	# - If we unregister on re-parent, FEAGI's desktop Type 11 fast-path no longer has a MultiMesh target,
	#   so neuron activity appears "missing" until a new BrainMonitor tab is opened and re-registers.
	#
	# `is_queued_for_deletion()` is true for real teardown (queue_free / scene shutdown), but false for re-parent.
	if _representing_cortial_area != null and is_queued_for_deletion():
		_representing_cortial_area.BV_unregister_directpoints_renderer(_directpoints_renderer)

func _process(_delta: float) -> void:
	# Pulse the I/O indicator (if present) without relying on Tweens (robust to re-parenting).
	if _io_direction_indicator_material == null or _io_direction_indicator == null:
		return
	if not is_instance_valid(_io_direction_indicator):
		_io_direction_indicator = null
		_io_direction_indicator_material = null
		_io_direction_indicator_base_scale = Vector3.ONE
		set_process(false)
		return
	var phase: float = float(Time.get_ticks_msec()) / IO_ARROW_PULSE_PERIOD_MS
	var s: float = 0.5 - 0.5 * cos(phase * TAU)  # 0..1 smooth pulse
	var c := _io_direction_indicator_material.albedo_color
	c.a = lerpf(IO_ARROW_ALPHA_MIN, IO_ARROW_ALPHA_MAX, s)
	_io_direction_indicator_material.albedo_color = c
	_io_direction_indicator_material.emission_energy = lerpf(IO_ARROW_EMISSION_MIN, IO_ARROW_EMISSION_MAX, s)
	# Keep the arrow from inheriting the cortical area's Z-scale by applying an inverse base scale.
	_io_direction_indicator.scale = _io_direction_indicator_base_scale * lerpf(0.95, 1.05, s)

func _schedule_directpoints_fastpath_registration_retry(defined_cortical_area: AbstractCorticalArea) -> void:
	# Keep retries bounded and quiet.
	if defined_cortical_area == null or _directpoints_renderer == null:
		return
	if not has_meta("_bv_fastpath_reg_retry"):
		set_meta("_bv_fastpath_reg_retry", 0)
	var attempt: int = int(get_meta("_bv_fastpath_reg_retry"))
	if attempt >= 10:
		return
	set_meta("_bv_fastpath_reg_retry", attempt + 1)
	call_deferred("_retry_directpoints_fastpath_registration", defined_cortical_area)

func _retry_directpoints_fastpath_registration(defined_cortical_area: AbstractCorticalArea) -> void:
	if defined_cortical_area == null or _directpoints_renderer == null:
		return
	if not _directpoints_renderer.has_method("bv_get_multimesh"):
		return
	var mm := _directpoints_renderer.call("bv_get_multimesh") as MultiMesh
	var dims := _directpoints_renderer.call("bv_get_dimensions") as Vector3
	defined_cortical_area.BV_register_directpoints_renderer(_directpoints_renderer, mm, dims)

## Creates/updates a magenta pulsing arrow above boundary I/O areas.
## - Input: arrow points down toward the area
## - Output: arrow points up away from the area
## - Both: bidirectional (double-headed)
## Skips indicators for areas currently positioned on brain-region plates.
func _refresh_io_direction_indicator(_unused = null) -> void:
	if not _io_direction_indicators_allowed_by_scene():
		_clear_io_direction_indicator()
		return
	# Skip indicators for plate-positioned areas (explicit user requirement).
	if _is_on_brain_region_plate():
		_clear_io_direction_indicator()
		return

	var region := _get_containing_region_context()
	if region == null or _representing_cortial_area == null:
		_clear_io_direction_indicator()
		return

	# Determine IO directionality: connections from/to areas outside the containing region.
	var is_input := _has_afferent_from_outside_region(_representing_cortial_area, region)
	var is_output := _has_efferent_to_outside_region(_representing_cortial_area, region)

	# Always show on IPU/OPU areas (directional override).
	if _representing_cortial_area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU:
		is_input = true
	if _representing_cortial_area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU:
		is_output = true

	var mode: StringName = &"none"
	if is_input and is_output:
		mode = &"bidirectional"
	elif is_input:
		mode = &"input"
	elif is_output:
		mode = &"output"

	if mode == &"none":
		_clear_io_direction_indicator()
		return

	# If mode changed, rebuild geometry.
	if mode != _io_direction_indicator_mode:
		_clear_io_direction_indicator()
		_io_direction_indicator_mode = mode
		_create_io_direction_indicator(mode)

	_update_io_direction_indicator_transform(mode)

func _create_io_direction_indicator(mode: StringName) -> void:
	var parent_body := _get_best_static_body_for_indicator()
	if parent_body == null:
		return

	var root := Node3D.new()
	root.name = "IODirectionIndicator"

	# Shared material for unibody arrow (single mesh, unshaded, transparent, emissive).
	var mat := StandardMaterial3D.new()
	mat.flags_unshaded = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.emission_enabled = true
	mat.albedo_color = IO_ARROW_COLOR
	mat.emission = IO_ARROW_EMISSION_COLOR
	mat.emission_energy = IO_ARROW_EMISSION_MIN

	var body := MeshInstance3D.new()
	body.name = "ArrowBody"
	body.mesh = _build_unibody_arrow_mesh(
		mode,
		IO_ARROW_SIZE_MIN_RADIUS,
		IO_ARROW_SIZE_MIN_SHAFT_H,
		IO_ARROW_SIZE_MIN_HEAD_H
	)
	body.material_override = mat
	root.add_child(body)

	parent_body.add_child(root)
	_io_direction_indicator = root
	_io_direction_indicator_material = mat
	_io_direction_indicator_label = _create_io_direction_indicator_label(mode)
	set_process(true)

func _update_io_direction_indicator_transform(mode: StringName) -> void:
	if _io_direction_indicator == null or not is_instance_valid(_io_direction_indicator):
		return

	var parent_body := _get_best_static_body_for_indicator()
	if parent_body == null:
		return

	# Compute visual bounds in WORLD space (so sizing is not affected by parent scaling).
	var bounds_world := _compute_world_visual_aabb(parent_body, _io_direction_indicator)
	if bounds_world.size.length() < 0.001:
		_clear_io_direction_indicator()
		return
	var top_y_world: float = bounds_world.position.y + bounds_world.size.y
	# Sizing decision must ignore Z (explicit requirement). Use only X/Y dimensions.
	var base_width_x: float = maxf(0.01, bounds_world.size.x)
	var base_height_y: float = maxf(0.01, bounds_world.size.y)

	# Scale arrow relative to the cortical area's actual rendered size.
	var radius: float = clampf(
		base_width_x * 0.12 * IO_ARROW_SIZE_MULTIPLIER,
		IO_ARROW_SIZE_MIN_RADIUS * IO_ARROW_SIZE_MULTIPLIER,
		IO_ARROW_SIZE_MAX_RADIUS * IO_ARROW_SIZE_MULTIPLIER
	)
	var shaft_h: float = clampf(
		base_height_y * 0.35 * IO_ARROW_SIZE_MULTIPLIER,
		IO_ARROW_SIZE_MIN_SHAFT_H * IO_ARROW_SIZE_MULTIPLIER,
		IO_ARROW_SIZE_MAX_SHAFT_H * IO_ARROW_SIZE_MULTIPLIER
	)
	var head_h: float = clampf(
		base_height_y * 0.18 * IO_ARROW_SIZE_MULTIPLIER,
		IO_ARROW_SIZE_MIN_HEAD_H * IO_ARROW_SIZE_MULTIPLIER,
		IO_ARROW_SIZE_MAX_HEAD_H * IO_ARROW_SIZE_MULTIPLIER
	)
	var gap: float = clampf(base_height_y * 0.08, 0.10, 0.45)

	_update_io_direction_indicator_geometry(mode, radius, shaft_h, head_h)

	# Place indicator immediately above the cortical area (small gap) in WORLD coordinates.
	var total_height: float = shaft_h + head_h
	if mode == &"bidirectional":
		total_height = shaft_h + (2.0 * head_h)
	var center_y_world: float = top_y_world + gap + (total_height * 0.5)
	
	# Align X with the friendly-name label's plated positioning (when available).
	var label := _get_friendly_name_label()
	var edge_world: Vector3 = parent_body.global_position
	if label != null and is_instance_valid(label):
		# Use the label's X/Z position since it is already camera-aware (snapped to camera-facing edge).
		edge_world = Vector3(label.global_position.x, edge_world.y, label.global_position.z)
	else:
		# Fall back to the same camera-facing-edge logic used by the label renderers.
		var viewport := get_viewport()
		if viewport != null:
			var cam := viewport.get_camera_3d()
			if cam != null:
				var cam_in_body_local: Vector3 = parent_body.to_local(cam.global_position)
				var z_sign: float = -1.0 if cam_in_body_local.z < 0.0 else 1.0
				# parent_body.global_transform.basis.z already includes scale; half-depth is basis.z * 0.5.
				var half_depth_vec_world: Vector3 = parent_body.global_transform.basis.z * 0.5
				var edge_pos_world: Vector3 = parent_body.global_position + (z_sign * half_depth_vec_world)
				edge_world = Vector3(edge_pos_world.x, edge_world.y, edge_pos_world.z)

	_io_direction_indicator.global_position = Vector3(edge_world.x, center_y_world, edge_world.z)

	# Prevent inherited non-uniform scaling (especially Z) from thickening the arrow.
	var parent_scale: Vector3 = parent_body.global_transform.basis.get_scale()
	if absf(parent_scale.x) < 0.001 or absf(parent_scale.y) < 0.001 or absf(parent_scale.z) < 0.001:
		_clear_io_direction_indicator()
		return
	_io_direction_indicator_base_scale = Vector3(
		1.0 / absf(parent_scale.x),
		1.0 / absf(parent_scale.y),
		1.0 / absf(parent_scale.z)
	)
	_update_io_direction_indicator_label(mode, shaft_h, head_h)
	_update_io_direction_indicator_label_visibility()

	# Orient direction
	if mode == &"input":
		# Input arrow points DOWN toward the area.
		_io_direction_indicator.rotation = Vector3(PI, 0.0, 0.0)
	elif mode == &"output":
		# Output arrow points UP away from the area.
		_io_direction_indicator.rotation = Vector3.ZERO
	else:
		# Bidirectional indicator is symmetric; keep upright.
		_io_direction_indicator.rotation = Vector3.ZERO

func _get_friendly_name_label() -> Label3D:
	# These renderer members are used elsewhere (e.g., UI_BrainMonitor_3DScene), so it's safe to reference.
	if _dda_renderer != null and _dda_renderer.get("_friendly_name_label") != null:
		return _dda_renderer._friendly_name_label
	if _directpoints_renderer != null and _directpoints_renderer.get("_friendly_name_label") != null:
		return _directpoints_renderer._friendly_name_label
	return null

func _create_io_direction_indicator_label(mode: StringName) -> Label3D:
	if _io_direction_indicator == null or not is_instance_valid(_io_direction_indicator):
		return null
	var label := Label3D.new()
	label.name = "IODirectionLabel"
	# Keep label independent of arrow rotation/scale so it always appears above in world space.
	label.top_level = true
	label.font_size = 256
	label.font = load("res://BrainVisualizer/UI/GenericResources/RobotoCondensed-Bold.ttf")
	label.modulate = Color.WHITE
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.alpha_scissor_threshold = 0.5
	label.no_depth_test = false
	label.render_priority = 2  # Render after the arrow geometry
	label.visible = false  # Only shown on hover
	label.text = _io_direction_indicator_label_text(mode)
	_io_direction_indicator.add_child(label)
	return label

func _io_direction_indicator_label_text(mode: StringName) -> String:
	if mode == &"input":
		return "Input Area"
	if mode == &"output":
		return "Output Area"
	if mode == &"bidirectional":
		return "Input/Output Area"
	return ""

func _update_io_direction_indicator_label(mode: StringName, shaft_h: float, head_h: float) -> void:
	if _io_direction_indicator_label == null or not is_instance_valid(_io_direction_indicator_label):
		return
	if _io_direction_indicator == null or not is_instance_valid(_io_direction_indicator):
		return
	_io_direction_indicator_label.text = _io_direction_indicator_label_text(mode)
	# Position label above the arrow in WORLD space (avoids inheriting arrow flips/scales).
	var total_h: float = shaft_h + head_h
	if mode == &"bidirectional":
		total_h = shaft_h + (2.0 * head_h)
	var y_above: float = (total_h / 2.0) + (head_h * IO_ARROW_LABEL_Y_GAP_MULT)
	_io_direction_indicator_label.global_position = _io_direction_indicator.global_position + Vector3(0.0, y_above, 0.0)

func _update_io_direction_indicator_label_visibility() -> void:
	if _io_direction_indicator_label == null or not is_instance_valid(_io_direction_indicator_label):
		return
	# Only show label when the cortical area itself is hovered (consistent with hover highlighting).
	_io_direction_indicator_label.visible = _is_volume_moused_over and _io_direction_indicator_mode != &"none"

func _update_io_direction_indicator_geometry(mode: StringName, radius: float, shaft_h: float, head_h: float) -> void:
	var body := _io_direction_indicator.get_node_or_null("ArrowBody") as MeshInstance3D
	if body == null:
		return
	body.mesh = _build_unibody_arrow_mesh(mode, radius, shaft_h, head_h)

func _build_unibody_arrow_mesh(mode: StringName, base_radius: float, shaft_h: float, head_h: float) -> ArrayMesh:
	var shaft_radius := base_radius * IO_ARROW_SHAFT_RADIUS_MULTIPLIER
	var tip_radius := maxf(0.001, base_radius * 0.06)
	var head_radius := base_radius * 1.35
	var transition_h := maxf(0.01, head_h * 0.35)

	var profile: Array[Vector2] = []
	if mode == &"bidirectional":
		var total_h := shaft_h + (2.0 * head_h)
		var bottom_tip_y := -total_h * 0.5
		var bottom_head_base_y := bottom_tip_y + head_h
		var shaft_top_y := bottom_head_base_y + shaft_h
		var top_tip_y := total_h * 0.5
		profile = [
			Vector2(tip_radius, bottom_tip_y),
			Vector2(head_radius * 0.22, bottom_tip_y + head_h * 0.22),
			Vector2(head_radius * 0.52, bottom_tip_y + head_h * 0.52),
			Vector2(head_radius, bottom_head_base_y),
			Vector2(lerpf(head_radius, shaft_radius, 0.55), bottom_head_base_y + transition_h * 0.55),
			Vector2(shaft_radius, bottom_head_base_y + transition_h),
			Vector2(shaft_radius, shaft_top_y - transition_h),
			Vector2(lerpf(head_radius, shaft_radius, 0.55), shaft_top_y - transition_h * 0.55),
			Vector2(head_radius, shaft_top_y),
			Vector2(head_radius * 0.52, shaft_top_y + head_h * 0.48),
			Vector2(head_radius * 0.22, shaft_top_y + head_h * 0.78),
			Vector2(tip_radius, top_tip_y),
		]
	else:
		var total_h := shaft_h + head_h
		var shaft_bottom_y := -total_h * 0.5
		var shaft_top_y := shaft_bottom_y + shaft_h
		var tip_y := total_h * 0.5
		profile = [
			Vector2(shaft_radius, shaft_bottom_y),
			Vector2(shaft_radius, shaft_top_y - transition_h),
			Vector2(lerpf(head_radius, shaft_radius, 0.55), shaft_top_y - transition_h * 0.55),
			Vector2(head_radius, shaft_top_y),
			Vector2(head_radius * 0.52, shaft_top_y + head_h * 0.48),
			Vector2(head_radius * 0.22, shaft_top_y + head_h * 0.78),
			Vector2(tip_radius, tip_y),
		]
	return _build_revolved_profile_mesh(profile, 14)

func _build_revolved_profile_mesh(profile: Array[Vector2], radial_segments: int) -> ArrayMesh:
	if profile.size() < 2:
		return ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for ring_idx in range(profile.size()):
		var radius := maxf(0.0, profile[ring_idx].x)
		var y := profile[ring_idx].y
		for seg_idx in range(radial_segments):
			var t := float(seg_idx) / float(radial_segments)
			var angle := t * TAU
			var x := cos(angle) * radius
			var z := sin(angle) * radius
			st.set_uv(Vector2(t, float(ring_idx) / float(profile.size() - 1)))
			st.add_vertex(Vector3(x, y, z))

	for ring_idx in range(profile.size() - 1):
		var ring_start := ring_idx * radial_segments
		var next_ring_start := (ring_idx + 1) * radial_segments
		for seg_idx in range(radial_segments):
			var next_seg := (seg_idx + 1) % radial_segments
			var a := ring_start + seg_idx
			var b := ring_start + next_seg
			var c := next_ring_start + seg_idx
			var d := next_ring_start + next_seg
			st.add_index(a)
			st.add_index(c)
			st.add_index(b)
			st.add_index(b)
			st.add_index(c)
			st.add_index(d)

	st.generate_normals()
	return st.commit()

## Computes a merged local-space AABB for all MeshInstance3D descendants under `root`.
## Falls back to a small default AABB if no meshes are found yet.
func _compute_local_visual_aabb(root: Node3D) -> AABB:
	var merged := AABB()
	var has_any := false
	if root == null or not is_instance_valid(root):
		return AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1.0, 1.0, 1.0))

	var root_inv := root.global_transform.affine_inverse()
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n := stack.pop_back()
		for child in n.get_children():
			stack.append(child)
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh == null:
				continue
			var aabb := mi.get_aabb()
			# Transform AABB into root-local space.
			var rel_xform := root_inv * mi.global_transform
			var local_aabb: AABB = _aabb_transformed_by_transform3d(aabb, rel_xform)
			if not has_any:
				merged = local_aabb
				has_any = true
			else:
				merged = merged.merge(local_aabb)

	if not has_any:
		return AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1.0, 1.0, 1.0))
	return merged

## Transform an AABB by a Transform3D by transforming its 8 corners and recomputing bounds.
func _aabb_transformed_by_transform3d(aabb: AABB, xform: Transform3D) -> AABB:
	var p: Vector3 = aabb.position
	var s: Vector3 = aabb.size
	var min_v := Vector3(INF, INF, INF)
	var max_v := Vector3(-INF, -INF, -INF)

	for ix in [0, 1]:
		for iy in [0, 1]:
			for iz in [0, 1]:
				var corner := Vector3(
					p.x + (s.x if ix == 1 else 0.0),
					p.y + (s.y if iy == 1 else 0.0),
					p.z + (s.z if iz == 1 else 0.0)
				)
				var tc: Vector3 = xform * corner
				min_v = Vector3(minf(min_v.x, tc.x), minf(min_v.y, tc.y), minf(min_v.z, tc.z))
				max_v = Vector3(maxf(max_v.x, tc.x), maxf(max_v.y, tc.y), maxf(max_v.z, tc.z))

	return AABB(min_v, max_v - min_v)

func _clear_io_direction_indicator() -> void:
	_io_direction_indicator_mode = &"none"
	if _io_direction_indicator != null and is_instance_valid(_io_direction_indicator):
		_io_direction_indicator.queue_free()
	_io_direction_indicator = null
	_io_direction_indicator_material = null
	_io_direction_indicator_base_scale = Vector3.ONE
	_io_direction_indicator_label = null
	set_process(false)

## Computes a merged WORLD-space AABB for all MeshInstance3D descendants under `root`.
func _compute_world_visual_aabb(root: Node3D, exclude_root: Node = null) -> AABB:
	var merged := AABB()
	var has_any := false
	if root == null or not is_instance_valid(root):
		return AABB(Vector3.ZERO, Vector3.ONE)

	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n := stack.pop_back()
		if exclude_root != null:
			if n == exclude_root or exclude_root.is_ancestor_of(n):
				continue
		for child in n.get_children():
			stack.append(child)
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh == null:
				continue
			var aabb := mi.get_aabb()
			var world_aabb: AABB = _aabb_transformed_by_transform3d(aabb, mi.global_transform)
			if not has_any:
				merged = world_aabb
				has_any = true
			else:
				merged = merged.merge(world_aabb)

	if not has_any:
		return AABB(Vector3.ZERO, Vector3.ZERO)
	return merged

func _get_best_static_body_for_indicator() -> StaticBody3D:
	if _dda_renderer != null and _dda_renderer.get("_static_body") != null and _dda_renderer._static_body != null:
		return _dda_renderer._static_body
	if _directpoints_renderer != null and _directpoints_renderer.get("_static_body") != null and _directpoints_renderer._static_body != null:
		return _directpoints_renderer._static_body
	return null

func _is_on_brain_region_plate() -> bool:
	# Prefer renderer-side detection (keeps consistent with plate logic in renderers).
	if _directpoints_renderer != null and _directpoints_renderer.has_method("_is_on_brain_region_plate"):
		return bool(_directpoints_renderer.call("_is_on_brain_region_plate"))
	if _dda_renderer != null and _dda_renderer.has_method("_is_on_brain_region_plate"):
		return bool(_dda_renderer.call("_is_on_brain_region_plate"))
	# Fallback: climb parent chain and look for plate containers (InputAreas/OutputAreas/ConflictAreas).
	var current_parent := get_parent()
	while current_parent != null:
		if current_parent.name == "InputAreas" or current_parent.name == "OutputAreas" or current_parent.name == "ConflictAreas":
			return true
		current_parent = current_parent.get_parent()
	return false

func _io_direction_indicators_allowed_by_scene() -> bool:
	var current := get_parent()
	while current != null:
		if current is UI_BrainMonitor_3DScene:
			var bm := current as UI_BrainMonitor_3DScene
			if bm.has_method("are_io_direction_indicators_allowed"):
				return bm.are_io_direction_indicators_allowed()
			return true
		current = current.get_parent()
	return true

func _get_containing_region_context() -> BrainRegion:
	# Prefer the nearest brain-region frame (subregion context). Otherwise, use the main BM 3D scene's region.
	var current := get_parent()
	while current != null:
		if current is UI_BrainMonitor_BrainRegion3D:
			var viz: UI_BrainMonitor_BrainRegion3D = current
			return viz.representing_region
		if current is UI_BrainMonitor_3DScene:
			var bm := current as UI_BrainMonitor_3DScene
			return bm.representing_region
		current = current.get_parent()
	return null

func _has_afferent_from_outside_region(area: AbstractCorticalArea, region: BrainRegion) -> bool:
	if area == null or region == null:
		return false
	for source_area: AbstractCorticalArea in area.afferent_mappings.keys():
		if source_area == null:
			continue
		if not region.is_cortical_area_in_region_recursive(source_area):
			return true
	return false

func _has_efferent_to_outside_region(area: AbstractCorticalArea, region: BrainRegion) -> bool:
	if area == null or region == null:
		return false
	for dest_area: AbstractCorticalArea in area.efferent_mappings.keys():
		if dest_area == null:
			continue
		if not region.is_cortical_area_in_region_recursive(dest_area):
			return true
	return false

## Sets new position (in FEAGI space)
func set_new_position(new_position: Vector3i) -> void:
	if _dda_renderer != null:
		_dda_renderer.update_position_with_new_FEAGI_coordinate(new_position)
	if _directpoints_renderer != null:
		_directpoints_renderer.update_position_with_new_FEAGI_coordinate(new_position)

## Repositions the area name labels so they sit below the cortical area but at the camera-facing edge of its depth.
func bv_update_friendly_name_label_positions() -> void:
	if _dda_renderer != null:
		_dda_renderer.bv_update_friendly_name_label_position()
	if _directpoints_renderer != null:
		_directpoints_renderer.bv_update_friendly_name_label_position()

func set_hover_over_volume_state(is_moused_over: bool, is_global_mode: bool = false) -> void:
	if is_moused_over == _is_volume_moused_over:
		return
	_is_volume_moused_over = is_moused_over
	if _dda_renderer != null:
		_dda_renderer.set_cortical_area_mouse_over_highlighting(is_moused_over)
	if _directpoints_renderer != null:
		_directpoints_renderer.set_cortical_area_mouse_over_highlighting(is_moused_over)
	_update_io_direction_indicator_label_visibility()
	
	# Show/hide neural connection curves on hover
	if is_moused_over:
		_show_neural_connections(is_global_mode)
	else:
		_hide_neural_connections()

func set_highlighted_neurons(neuron_coordinates: Array[Vector3i]) -> void:
		_hovered_neuron_coordinates = neuron_coordinates
		if _dda_renderer != null:
			_dda_renderer.set_highlighted_neurons(neuron_coordinates)
		if _directpoints_renderer != null:
			_directpoints_renderer.set_highlighted_neurons(neuron_coordinates)

func clear_hover_state_for_all_neurons() -> void:
	if len(_hovered_neuron_coordinates) != 0:
		_hovered_neuron_coordinates = []
		if _dda_renderer != null:
			_dda_renderer.set_highlighted_neurons(_hovered_neuron_coordinates)
		if _directpoints_renderer != null:
			_directpoints_renderer.set_highlighted_neurons(_hovered_neuron_coordinates)

func set_neuron_selection_state(neuron_coordinate: Vector3i, is_selected: bool) -> void:
	var index: int = _selected_neuron_coordinates.find(neuron_coordinate)
	if (index != -1 && is_selected):
		return #nothing to change
	if is_selected:
		_selected_neuron_coordinates.append(neuron_coordinate)
	else:
		_selected_neuron_coordinates.remove_at(index)
	if _dda_renderer != null:
		_dda_renderer.set_neuron_selections(_selected_neuron_coordinates)
	if _directpoints_renderer != null:
		_directpoints_renderer.set_neuron_selections(_selected_neuron_coordinates)

# flips the neuron coordinate selection state, and returns the new state (if its selected now)
func toggle_neuron_selection_state(neuron_coordinate: Vector3i) -> bool:
	var index: int = _selected_neuron_coordinates.find(neuron_coordinate)
	var is_selected: bool
	if index == -1:
		_selected_neuron_coordinates.append(neuron_coordinate)
		is_selected = true
	else:
		_selected_neuron_coordinates.remove_at(index)
		is_selected = false
	if _dda_renderer != null:
		_dda_renderer.set_neuron_selections(_selected_neuron_coordinates)
	if _directpoints_renderer != null:
		_directpoints_renderer.set_neuron_selections(_selected_neuron_coordinates)
	return is_selected

func clear_all_neuron_selection_states() -> void:
	if len(_selected_neuron_coordinates) != 0:
		_selected_neuron_coordinates =  []
		if _dda_renderer != null:
			_dda_renderer.set_neuron_selections(_selected_neuron_coordinates)
		if _directpoints_renderer != null:
			_directpoints_renderer.set_neuron_selections(_selected_neuron_coordinates)

func get_neuron_selection_states() -> Array[Vector3i]:
	return _selected_neuron_coordinates

func _on_ui_highlighted_state_updated(is_highlighted: bool) -> void:
	if _dda_renderer != null and _dda_renderer.has_method("set_cortical_area_selection"):
		_dda_renderer.set_cortical_area_selection(is_highlighted)
	if _directpoints_renderer != null and _directpoints_renderer.has_method("set_cortical_area_selection"):
		_directpoints_renderer.set_cortical_area_selection(is_highlighted)

func _create_renderer_depending_on_cortical_area_type(defined_cortical_area: AbstractCorticalArea) -> UI_BrainMonitor_AbstractCorticalAreaRenderer:
	# Special cases: Memory and Power cortical areas use DirectPoints rendering
	if defined_cortical_area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY:
		return UI_BrainMonitor_DirectPointsCorticalAreaRenderer.new()
	elif AbstractCorticalArea.is_power_area(defined_cortical_area.cortical_ID):
		return UI_BrainMonitor_DirectPointsCorticalAreaRenderer.new()
	else:
		# Use DDA renderer for all other cortical area types
		return UI_BrainMonitor_DDACorticalAreaRenderer.new()

## Show 3D curves connecting this cortical area to all its destinations
func _show_neural_connections(is_global_mode: bool = false) -> void:
	if _are_connections_visible:
		return  # Already showing connections
	
	# Clear any existing pulse tweens
	_pulse_tweens.clear()
	
	# Check if we have the cortical area object
	if _representing_cortial_area == null:
		return
	
	# Get all efferent (outgoing) connections from this cortical area
	var efferent_mappings = _representing_cortial_area.efferent_mappings
	
	# Get the center position of this cortical area (needed for both efferent and afferent connections)
	var source_position = _get_cortical_area_center_position()
	
	if source_position == Vector3.ZERO:
		return
	
	var curves_created = 0
	
	# Process efferent (outgoing) connections if they exist
	if not efferent_mappings.is_empty():
		# Create curves to all destination cortical areas (OUTGOING)
		for destination_area: AbstractCorticalArea in efferent_mappings.keys():
			var destination_position = _get_cortical_area_center_position_for_area(destination_area)
			
			if destination_position != Vector3.ZERO:  # Valid position found
				var mapping_set: InterCorticalMappingSet = efferent_mappings[destination_area]
				var curve_node = _create_connection_curve(source_position, destination_position, destination_area.cortical_ID, mapping_set, is_global_mode)
				_connection_curves.append(curve_node)
				add_child(curve_node)
				curves_created += 1
	
	# Get all afferent (incoming) connections to this cortical area
	var afferent_mappings = _representing_cortial_area.afferent_mappings
	
	if not afferent_mappings.is_empty():
		# Create curves from all source cortical areas (INCOMING)
		for source_area: AbstractCorticalArea in afferent_mappings.keys():
			var source_area_position = _get_cortical_area_center_position_for_area(source_area)
			
			if source_area_position != Vector3.ZERO:  # Valid position found
				var mapping_set: InterCorticalMappingSet = afferent_mappings[source_area]
				var curve_node = _create_connection_curve(source_area_position, source_position, source_area.cortical_ID, mapping_set, is_global_mode)
				_connection_curves.append(curve_node)
				add_child(curve_node)
				curves_created += 1
	
	# Get all recursive (self) connections within this cortical area
	var recursive_mappings = _representing_cortial_area.recursive_mappings
	
	if not recursive_mappings.is_empty():
		# Create looping curves for recursive connections
		for recursive_area: AbstractCorticalArea in recursive_mappings.keys():
			# Create a self-looping curve
			var mapping_set: InterCorticalMappingSet = recursive_mappings[recursive_area]
			var loop_node = _create_recursive_loop(source_position, recursive_area.cortical_ID, mapping_set, is_global_mode)
			_connection_curves.append(loop_node)
			add_child(loop_node)
			curves_created += 1
	
	_are_connections_visible = true

## Hide all neural connection curves
func _hide_neural_connections() -> void:
	if not _are_connections_visible:
		return  # Already hidden
	
	# Stop all pulse animations
	for tween in _pulse_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_pulse_tweens.clear()
	
	# Remove all curve nodes
	for curve_node in _connection_curves:
		if curve_node != null:
			curve_node.queue_free()
	
	_connection_curves.clear()
	_are_connections_visible = false

## Get the center position of this cortical area in world space
func _get_cortical_area_center_position() -> Vector3:
	# print("     🔍 Getting position for: ", _representing_cortial_area.cortical_ID)  # Suppressed - too frequent
	# print("     🔍 _dda_renderer: ", _dda_renderer != null)  # Suppressed - too frequent  
	# print("     🔍 _directpoints_renderer: ", _directpoints_renderer != null)  # Suppressed - too frequent
	
	if _representing_cortial_area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY:
		print("     🔮 MEMORY AREA position retrieval...")
	
	# Use the renderer's static body position as the center
	if _dda_renderer != null and _dda_renderer._static_body != null:
		var pos = _dda_renderer._static_body.global_position
		# print("     ✅ DDA renderer position: ", pos)  # Suppressed - too frequent
		return pos
	elif _directpoints_renderer != null and _directpoints_renderer._static_body != null:
		var pos = _directpoints_renderer._static_body.global_position
		# print("     ✅ DirectPoints renderer position: ", pos)  # Suppressed - too frequent
		return pos
	else:
		print("     ❌ No renderer or static body available for: ", _representing_cortial_area.cortical_ID)
		if _dda_renderer != null:
			print("     🔍 DDA renderer exists but _static_body is: ", _dda_renderer._static_body)
		if _directpoints_renderer != null:
			print("     🔍 DirectPoints renderer exists but _static_body is: ", _directpoints_renderer._static_body)
		return Vector3.ZERO

## Get the center position of another cortical area by finding its renderer in the scene
func _get_cortical_area_center_position_for_area(area: AbstractCorticalArea) -> Vector3:
	# 🚨 FIX: Use main 3D scene's cortical area registry instead of parent searching
	# This fixes connection visualization for I/O areas moved to brain region containers
	
	# Find the main 3D scene by traversing up the tree
	var current_node = self
	var main_3d_scene: UI_BrainMonitor_3DScene = null
	
	while current_node != null:
		current_node = current_node.get_parent()
		if current_node is UI_BrainMonitor_3DScene:
			main_3d_scene = current_node as UI_BrainMonitor_3DScene
			break
	
	if main_3d_scene == null:
		print("   ⚠️ Could not find main 3D scene for cortical area lookup")
		return Vector3.ZERO
	
	# Use the 3D scene's cortical area registry to find the target
	var target_visualization = main_3d_scene.get_cortical_area_visualization(area.cortical_ID)
	
	if target_visualization == null:
		print("   ⚠️ Could not find cortical area visualization for: ", area.cortical_ID)
		return Vector3.ZERO
	
	# Get position from the target's renderer  
	return target_visualization._get_cortical_area_center_position()

## Create a 3D curve connecting two points
func _create_connection_curve(start_pos: Vector3, end_pos: Vector3, connection_id: StringName, mapping_set: InterCorticalMappingSet, is_global_mode: bool = false) -> Node3D:
	var is_plastic = _is_mapping_set_plastic(mapping_set)  # Back to original logic
	var is_bidirectional = _is_mapping_set_bidirectional_plastic(mapping_set)
	
	# If inhibitory and excitatory coexist between two areas, render two independent arcs.
	# - Excitatory: green
	# - Inhibitory: red
	# The arcs use a slightly different bend to remain visually distinguishable.
	var has_inhibitory := false
	var has_excitatory := false
	if mapping_set != null and not mapping_set.mappings.is_empty():
		has_inhibitory = mapping_set.is_any_PSP_multiplier_negative()
		has_excitatory = mapping_set.is_any_PSP_multiplier_positive()
	
	if has_inhibitory and has_excitatory:
		var mixed_node := Node3D.new()
		var plastic_prefix = "PLA_" if is_plastic else "STD_"
		mixed_node.name = "MIXED_" + plastic_prefix + connection_id
		
		# Slightly different bend multipliers for separation
		var excitatory_curve = _create_connection_curve_variant(start_pos, end_pos, connection_id, false, is_plastic, is_bidirectional, is_global_mode, 0.43)
		var inhibitory_curve = _create_connection_curve_variant(start_pos, end_pos, connection_id, true, is_plastic, is_bidirectional, is_global_mode, 0.37)
		mixed_node.add_child(excitatory_curve)
		mixed_node.add_child(inhibitory_curve)
		return mixed_node
	
	var is_inhibitory = _is_mapping_set_inhibitory(mapping_set)
	return _create_connection_curve_variant(start_pos, end_pos, connection_id, is_inhibitory, is_plastic, is_bidirectional, is_global_mode, 0.4)

## Internal helper that creates a single visual arc for a connection.
## arc_height_multiplier controls the curve bend height relative to distance (e.g. 0.4 = 40% of distance).
func _create_connection_curve_variant(
	start_pos: Vector3,
	end_pos: Vector3,
	connection_id: StringName,
	is_inhibitory: bool,
	is_plastic: bool,
	is_bidirectional: bool,
	is_global_mode: bool,
	arc_height_multiplier: float
) -> Node3D:
	
	# Create a container for the curve segments
	var connection_node = Node3D.new()
	var type_prefix = "INH_" if is_inhibitory else "EXC_"
	var plastic_prefix = "PLA_" if is_plastic else "STD_" 
	connection_node.name = type_prefix + plastic_prefix + connection_id
	
	# Calculate curve parameters
	var direction = (end_pos - start_pos)
	var distance = direction.length()
	var mid_point = (start_pos + end_pos) / 2.0
	
	# Create an upward arc - arc height based on distance
	var arc_height = distance * arc_height_multiplier
	var control_point = mid_point + Vector3(0, arc_height, 0)
	
	# For plastic connections, add wobble effect by modifying control point and segments
	var is_wobbly = is_plastic
	
	# Store curve points for pulse animation
	var curve_points: Array[Vector3] = []
	
	# For bidirectional plastic connections, render as electric arc
	if is_plastic and is_bidirectional:
		var arc_points = _create_electric_arc_segments(
			connection_node,
			start_pos,
			control_point,
			end_pos,
			is_inhibitory,
			is_global_mode,
			connection_id
		)
		_add_electric_arc_animation(connection_node, start_pos, control_point, end_pos)
		# Skip default pulse animation so arc stays visually distinct.
		return connection_node
	
	# For plastic connections, create dashed lines
	if is_plastic:
		# Calculate number of dashes based on curve length for consistent spacing
		var curve_length = _estimate_curve_length(start_pos, control_point, end_pos)
		var desired_dash_spacing = 2.5  # Units between dashes
		var num_dashes = max(4, int(curve_length / desired_dash_spacing))  # Minimum 4 dashes
		
		var dash_material = _create_plastic_animated_material(is_inhibitory, is_global_mode)
		
		for i in range(num_dashes):
			var t = float(i) / float(num_dashes - 1)  # 0 to 1 along curve
			
			# Calculate position on quadratic Bezier curve
			var dash_position = _quadratic_bezier(start_pos, control_point, end_pos, t)
			
			# Calculate direction for orientation
			var t_next = min(t + 0.1, 1.0)  # Small step ahead for direction
			var next_position = _quadratic_bezier(start_pos, control_point, end_pos, t_next)
			var dash_direction = (next_position - dash_position).normalized()
			
			# Create a small cylinder for each dash
			var dash = MeshInstance3D.new()
			dash.name = "Dash_" + str(i)
			dash.mesh = CylinderMesh.new()
			
			# Set dash size (longer line segment)
			var cylinder_mesh = dash.mesh as CylinderMesh
			cylinder_mesh.height = 1.2  # Longer dashes
			cylinder_mesh.top_radius = 0.06  # Thin line
			cylinder_mesh.bottom_radius = 0.06
			cylinder_mesh.radial_segments = 6  # Simple geometry
			
			# Position the dash
			dash.position = dash_position
			dash.material_override = dash_material
			
			# Orient the dash along the curve direction (Y-axis is cylinder height)
			if dash_direction.length() > 0.001:  # Avoid zero direction
				# Create transform matrix to align Y-axis (cylinder height) with curve direction
				var up_vector = Vector3.UP
				if abs(dash_direction.dot(Vector3.UP)) > 0.9:
					up_vector = Vector3.FORWARD  # Avoid parallel vectors
				
				var right_vector = up_vector.cross(dash_direction).normalized()
				var corrected_up = dash_direction.cross(right_vector).normalized()
				
				# Set the transform to align Y-axis with dash direction
				dash.transform.basis = Basis(right_vector, dash_direction, corrected_up)
			
			connection_node.add_child(dash)
			
			# Store position for pulse animation
			if i == 0:
				curve_points.append(dash_position)
			curve_points.append(dash_position)
		
		# Store dashes for animation
		connection_node.set_meta("plastic_dashes", connection_node.get_children())
		_add_dash_wave_animation(connection_node, start_pos, control_point, end_pos)
	else:
		# For non-plastic connections, use continuous segments
		var num_segments = 12
		var segment_material = _create_curve_material(is_inhibitory, is_global_mode)
		
		for i in range(num_segments):
			var t1 = float(i) / float(num_segments)
			var t2 = float(i + 1) / float(num_segments)
			
			# Calculate points on quadratic Bezier curve
			var point1 = _quadratic_bezier(start_pos, control_point, end_pos, t1)
			var point2 = _quadratic_bezier(start_pos, control_point, end_pos, t2)
			
			# Store points for animation
			if i == 0:
				curve_points.append(point1)
			curve_points.append(point2)
			
			# Create cylinder segment between these two points
			var segment = _create_curve_segment(point1, point2, i, segment_material)
			connection_node.add_child(segment)
	
	# Create pulse animation along this curve
	_create_pulse_animation(connection_node, curve_points, connection_id, is_inhibitory)
	
	return connection_node

## Add traveling wave animation to dashed plastic connections
func _add_dash_wave_animation(connection_node: Node3D, curve_start: Vector3, curve_control: Vector3, curve_end: Vector3) -> void:
	"""Animate dashes with traveling wave effect for plastic connections"""
	if not connection_node:
		return
	
	# Get the stored dashes
	var dashes = connection_node.get_meta("plastic_dashes", []) as Array[Node]
	if dashes.is_empty():
		print("       ❌ Could not find dashes for animation")
		return
	
	var num_dashes = dashes.size()
	
	# Store original scales for each dash
	var original_scales: Array[Vector3] = []
	for dash_node in dashes:
		var dash = dash_node as MeshInstance3D
		if is_instance_valid(dash):
			original_scales.append(dash.scale)
	
	# Create traveling wave animation
	var wave_tween = create_tween()
	wave_tween.set_loops()  # Infinite animation
	
	wave_tween.tween_method(
		func(animation_time: float):
			# Safety check
			if not connection_node or not is_instance_valid(connection_node):
				wave_tween.kill()
				return
			
			# Traveling wave parameters
			var wave_speed = 1.0  # Speed of traveling effect
			var pulse_width = 2.5  # How many dashes are bright at once
			var brightness_variation = 0.8  # How much dashes pulse
			var length_variation = 0.5  # How much dashes extend in length
			
			# Create traveling wave effect along the dashes
			var time_phase = animation_time * wave_speed
			
			# Animate each dash
			for i in range(num_dashes):
				var dash = dashes[i] as MeshInstance3D
				if not is_instance_valid(dash):
					continue
				
				# Calculate position along curve (0 to 1)
				var curve_position = float(i) / float(num_dashes - 1)
				
				# Create traveling wave with smooth falloff
				var wave_center = fmod(time_phase, TAU) / TAU  # Traveling center (0 to 1)
				var distance_from_wave = abs(curve_position - wave_center)
				
				# Handle wrap-around
				if distance_from_wave > 0.5:
					distance_from_wave = 1.0 - distance_from_wave
				
				# Create smooth pulse using cosine for smooth falloff
				var pulse_intensity = cos(distance_from_wave * PI / pulse_width) if distance_from_wave < pulse_width else 0.0
				pulse_intensity = max(0.0, pulse_intensity)  # Only positive values
				
				# Apply scale animation (dashes grow in length and thickness)
				var original_scale = original_scales[i] if i < original_scales.size() else Vector3.ONE
				var thickness_multiplier = 1.0 + (pulse_intensity * brightness_variation * 0.5)  # Thickness
				var length_multiplier = 1.0 + (pulse_intensity * length_variation)  # Length
				
				dash.scale = Vector3(
					original_scale.x * thickness_multiplier,  # X radius
					original_scale.y * length_multiplier,     # Y height (length)
					original_scale.z * thickness_multiplier  # Z radius
				)
				
				# Apply brightness animation to material
				if dash.material_override is StandardMaterial3D:
					var material = dash.material_override as StandardMaterial3D
					var base_emission = 0.2  # Base emission energy
					var emission_boost = pulse_intensity * 0.7  # Bright pulse
					material.emission_energy = base_emission + emission_boost
					
					# Also modify transparency for additional effect
					var base_transparency = 0.8
					var transparency_boost = pulse_intensity * 0.2
					material.albedo_color.a = base_transparency + transparency_boost,
		0.0,
		100.0,  # Long animation time
		4.0     # 4 second wave cycle
	)

## Add circular rotating wave animation to dashed recursive loops
func _add_circular_dash_wave_animation(loop_node: Node3D, loop_center: Vector3, loop_radius: float) -> void:
	"""Animate dashes around circular loop with rotating wave patterns"""
	if not loop_node:
		return
	
	# Get the stored loop dashes
	var dashes = loop_node.get_meta("plastic_loop_dashes", []) as Array[Node]
	if dashes.is_empty():
		print("       ❌ Could not find loop dashes for animation")
		return
	
	var num_dashes = dashes.size()
	
	# Store original scales for each dash
	var original_scales: Array[Vector3] = []
	for dash_node in dashes:
		var dash = dash_node as MeshInstance3D
		if is_instance_valid(dash):
			original_scales.append(dash.scale)
	
	# Create circular rotating wave animation
	var circular_tween = create_tween()
	circular_tween.set_loops()  # Infinite animation
	
	circular_tween.tween_method(
		func(animation_time: float):
			# Safety check
			if not loop_node or not is_instance_valid(loop_node):
				circular_tween.kill()
				return
			
			# Circular wave parameters
			var rotation_speed = 0.8  # Speed of rotating wave
			var pulse_width = 3.0  # How many dashes are bright at once
			var brightness_variation = 1.0  # How much dashes pulse
			var length_variation = 0.6  # How much dashes extend in length
			
			# Create rotating wave effect around the circle
			var time_phase = animation_time * rotation_speed
			
			# Animate each dash around the circle
			for i in range(num_dashes):
				var dash = dashes[i] as MeshInstance3D
				if not is_instance_valid(dash):
					continue
				
				# Calculate angular position around circle (0 to TAU)
				var angular_position = (float(i) / float(num_dashes)) * TAU
				
				# Create rotating wave
				var wave_angle = angular_position - time_phase  # Subtract for clockwise rotation
				
				# Normalize wave angle to 0-TAU range
				wave_angle = fmod(wave_angle, TAU)
				if wave_angle < 0:
					wave_angle += TAU
				
				# Create smooth pulse using cosine
				var pulse_intensity = cos(wave_angle * pulse_width / TAU)
				pulse_intensity = max(0.0, pulse_intensity)  # Only positive values
				
				# Apply scale animation (dashes grow in length and thickness)
				var original_scale = original_scales[i] if i < original_scales.size() else Vector3.ONE
				var thickness_multiplier = 1.0 + (pulse_intensity * brightness_variation * 0.4)  # Thickness
				var length_multiplier = 1.0 + (pulse_intensity * length_variation)  # Length
				
				dash.scale = Vector3(
					original_scale.x * thickness_multiplier,  # X radius
					original_scale.y * length_multiplier,     # Y height (length)
					original_scale.z * thickness_multiplier  # Z radius
				)
				
				# Apply brightness animation to material
				if dash.material_override is StandardMaterial3D:
					var material = dash.material_override as StandardMaterial3D
					var base_emission = 0.25  # Base emission energy
					var emission_boost = pulse_intensity * 0.8  # Strong bright rotating pulse
					material.emission_energy = base_emission + emission_boost
					
					# Also modify transparency for additional effect
					var base_transparency = 0.75
					var transparency_boost = pulse_intensity * 0.25
					material.albedo_color.a = base_transparency + transparency_boost,
		0.0,
		100.0,  # Long animation time
		5.0     # 5 second rotation cycle
	)

## Calculate point on quadratic Bezier curve
func _quadratic_bezier(p0: Vector3, p1: Vector3, p2: Vector3, t: float) -> Vector3:
	var u = 1.0 - t
	return u * u * p0 + 2.0 * u * t * p1 + t * t * p2

## Estimate the length of a quadratic Bezier curve by sampling points
func _estimate_curve_length(start_pos: Vector3, control_pos: Vector3, end_pos: Vector3) -> float:
	var total_length = 0.0
	var num_samples = 20  # More samples for better accuracy
	
	var prev_point = start_pos
	for i in range(1, num_samples + 1):
		var t = float(i) / float(num_samples)
		var current_point = _quadratic_bezier(start_pos, control_pos, end_pos, t)
		total_length += prev_point.distance_to(current_point)
		prev_point = current_point
	
	return total_length

## Tangent of a quadratic Bezier curve at t
func _quadratic_bezier_tangent(p0: Vector3, p1: Vector3, p2: Vector3, t: float) -> Vector3:
	return 2.0 * (1.0 - t) * (p1 - p0) + 2.0 * t * (p2 - p1)

## Create electric arc segments for bidirectional plastic connections
func _create_electric_arc_segments(
	connection_node: Node3D,
	start_pos: Vector3,
	control_point: Vector3,
	end_pos: Vector3,
	is_inhibitory: bool,
	is_global_mode: bool,
	connection_id: StringName
) -> Array[Vector3]:
	var arc_length = _estimate_curve_length(start_pos, control_point, end_pos)
	var segment_count = max(8, int(arc_length * 1.5))
	var t_values: Array[float] = []
	for i in range(segment_count + 1):
		t_values.append(float(i) / float(segment_count))
	
	var jitter_strength = max(0.35, arc_length * 0.03)
	var seed_offset = float(hash(String(connection_id))) * 0.001
	var points = _build_electric_arc_points(start_pos, control_point, end_pos, t_values, seed_offset, jitter_strength)
	
	var material = _create_electric_arc_material(is_inhibitory, is_global_mode)
	var segments: Array = []
	for i in range(segment_count):
		var segment = _create_curve_segment(points[i], points[i + 1], i, material)
		connection_node.add_child(segment)
		segments.append(segment)
	
	connection_node.set_meta("electric_arc_segments", segments)
	connection_node.set_meta("electric_arc_t_values", t_values)
	connection_node.set_meta("electric_arc_seed", seed_offset)
	return points

## Build jittered arc points for electric arc animation
func _build_electric_arc_points(
	start_pos: Vector3,
	control_point: Vector3,
	end_pos: Vector3,
	t_values: Array[float],
	time_offset: float,
	jitter_strength: float
) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for t in t_values:
		var base = _quadratic_bezier(start_pos, control_point, end_pos, t)
		var offset = _electric_arc_offset(start_pos, control_point, end_pos, t, time_offset, jitter_strength)
		points.append(base + offset)
	return points

## Compute offset for electric arc jitter
func _electric_arc_offset(
	start_pos: Vector3,
	control_point: Vector3,
	end_pos: Vector3,
	t: float,
	time_offset: float,
	jitter_strength: float
) -> Vector3:
	var tangent = _quadratic_bezier_tangent(start_pos, control_point, end_pos, t)
	if tangent.length() < 0.001:
		return Vector3.ZERO
	var dir = tangent.normalized()
	var up_vector = Vector3.UP
	if abs(dir.dot(Vector3.UP)) > 0.9:
		up_vector = Vector3.FORWARD
	var right_vector = up_vector.cross(dir).normalized()
	var corrected_up = dir.cross(right_vector).normalized()
	
	var time = Time.get_ticks_msec() / 1000.0
	var phase = time_offset + time * 3.5 + t * TAU
	var noise_x = sin(phase * 2.7 + t * 11.3)
	var noise_y = cos(phase * 3.9 + t * 8.1)
	var noise_z = sin(phase * 4.3 + t * 6.7)
	
	var lateral = (right_vector * noise_x + corrected_up * noise_y) * jitter_strength
	var longitudinal = dir * noise_z * jitter_strength * 0.15
	return lateral + longitudinal

## Electric arc material for bidirectional plastic connections
func _create_electric_arc_material(is_inhibitory: bool = false, is_global_mode: bool = false) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	if is_global_mode:
		material.albedo_color = Color(0.6, 0.7, 0.9, 0.85)
		material.emission = Color(0.4, 0.6, 0.9)
	elif is_inhibitory:
		material.albedo_color = Color(0.9, 0.4, 1.0, 0.9)
		material.emission = Color(0.8, 0.3, 1.0)
	else:
		material.albedo_color = Color(0.4, 0.9, 1.0, 0.9)
		material.emission = Color(0.3, 0.8, 1.0)
	
	material.emission_enabled = true
	material.emission_energy = 4.0
	material.flags_unshaded = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

## Update an existing curve segment with new endpoints
func _update_curve_segment(segment: MeshInstance3D, start_pos: Vector3, end_pos: Vector3) -> void:
	if segment == null or not is_instance_valid(segment):
		return
	var direction = (end_pos - start_pos)
	var segment_length = direction.length()
	var center_pos = (start_pos + end_pos) / 2.0
	segment.position = center_pos
	var cylinder_mesh = segment.mesh as CylinderMesh
	if cylinder_mesh != null:
		cylinder_mesh.height = segment_length
	if direction.length() > 0.001:
		var normalized_direction = direction.normalized()
		var up_vector = Vector3.UP
		if abs(normalized_direction.dot(Vector3.UP)) > 0.9:
			up_vector = Vector3.FORWARD
		var right_vector = up_vector.cross(normalized_direction).normalized()
		var corrected_up = normalized_direction.cross(right_vector).normalized()
		var basis = Basis(right_vector, normalized_direction, corrected_up)
		segment.basis = basis

## Add flicker + jitter animation to electric arc segments
func _add_electric_arc_animation(connection_node: Node3D, start_pos: Vector3, control_point: Vector3, end_pos: Vector3) -> void:
	if connection_node == null:
		return
	var segments = connection_node.get_meta("electric_arc_segments", []) as Array
	var t_values = connection_node.get_meta("electric_arc_t_values", []) as Array
	if segments.is_empty() or t_values.is_empty():
		return
	
	var seed_offset = float(connection_node.get_meta("electric_arc_seed", 0.0))
	var arc_tween = create_tween()
	arc_tween.set_loops()
	
	var arc_callback = func(animation_time: float) -> void:
		if connection_node == null or not is_instance_valid(connection_node):
			arc_tween.kill()
			return
		var jitter_strength = max(0.35, _estimate_curve_length(start_pos, control_point, end_pos) * 0.03)
		var points = _build_electric_arc_points(
			start_pos,
			control_point,
			end_pos,
			t_values,
			seed_offset + animation_time * 1.3,
			jitter_strength
		)
		for i in range(segments.size()):
			var segment = segments[i] as MeshInstance3D
			if segment == null or not is_instance_valid(segment):
				continue
			_update_curve_segment(segment, points[i], points[i + 1])
			if segment.material_override is StandardMaterial3D:
				var material = segment.material_override as StandardMaterial3D
				var flicker = 0.7 + (sin(animation_time * 9.0 + float(i)) * 0.3)
				material.emission_energy = 3.5 * flicker
	arc_tween.tween_method(arc_callback, 0.0, 100.0, 0.35)

## Create a single segment of the curve
func _create_curve_segment(start_pos: Vector3, end_pos: Vector3, segment_index: int, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "CurveSegment_" + str(segment_index)
	
	# Calculate segment properties
	var direction = (end_pos - start_pos)
	var segment_length = direction.length()
	var center_pos = (start_pos + end_pos) / 2.0
	
	# Create cylinder mesh for this segment
	var cylinder_mesh = CylinderMesh.new()
	cylinder_mesh.top_radius = 0.15  # Thinner for elegant curve
	cylinder_mesh.bottom_radius = 0.15
	cylinder_mesh.height = segment_length
	cylinder_mesh.radial_segments = 6
	cylinder_mesh.rings = 1
	
	mesh_instance.mesh = cylinder_mesh
	mesh_instance.position = center_pos
	
	# Rotate segment to align with direction
	if direction.length() > 0.001:
		var normalized_direction = direction.normalized()
		var up_vector = Vector3.UP
		if abs(normalized_direction.dot(Vector3.UP)) > 0.9:
			up_vector = Vector3.FORWARD
		
		var right_vector = up_vector.cross(normalized_direction).normalized()
		var corrected_up = normalized_direction.cross(right_vector).normalized()
		var basis = Basis(right_vector, normalized_direction, corrected_up)
		mesh_instance.basis = basis
	
	mesh_instance.material_override = material
	return mesh_instance

## Create material for curve segments based on inhibitory/excitatory properties
func _create_curve_material(is_inhibitory: bool = false, is_global_mode: bool = false) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	
	if is_global_mode:
		# Global mode - Gray color for all connections
		material.albedo_color = Color(0.7, 0.7, 0.7, 0.8)  # Light gray
		material.emission = Color(0.5, 0.5, 0.5)     # Gray emission
	elif is_inhibitory:
		# Inhibitory connections - Red color
		material.albedo_color = Color(1.0, 0.2, 0.2, 0.9)  # Bright red
		material.emission = Color(0.8, 0.1, 0.1)
	else:
		# Excitatory (non-inhibitory) connections - Green color
		material.albedo_color = Color(0.2, 1.0, 0.3, 0.9)  # Bright green
		material.emission = Color(0.1, 0.8, 0.2)
	
	material.emission_enabled = true
	material.emission_energy = 2.0
	material.flags_unshaded = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

## Create pulse animation along the curve
func _create_pulse_animation(curve_node: Node3D, curve_points: Array[Vector3], connection_id: StringName, is_inhibitory: bool = false) -> void:
	
	# Create multiple pulse spheres for continuous animation
	var num_pulses = 3  # Multiple pulses traveling at once
	
	for pulse_index in range(num_pulses):
		# Create a glowing pulse sphere
		var pulse_sphere = MeshInstance3D.new()
		pulse_sphere.name = "Pulse_" + str(pulse_index)
		
		# Create sphere mesh
		var sphere_mesh = SphereMesh.new()
		sphere_mesh.radius = 0.3
		sphere_mesh.height = 0.6
		sphere_mesh.radial_segments = 8
		sphere_mesh.rings = 4
		pulse_sphere.mesh = sphere_mesh
		
		# Create bright pulsing material with different colors based on connection type
		var pulse_material = StandardMaterial3D.new()
		# Both inhibitory and excitatory pulses - Bright white for better visibility
		pulse_material.albedo_color = Color(1.0, 1.0, 1.0, 0.8)  # Bright white
		pulse_material.emission = Color(1.0, 1.0, 1.0)
		
		pulse_material.emission_enabled = true
		pulse_material.emission_energy = 4.0
		pulse_material.flags_unshaded = true
		pulse_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pulse_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD  # Additive for glow
		pulse_sphere.material_override = pulse_material
		
		# Start pulse at beginning of curve
		pulse_sphere.position = curve_points[0]
		curve_node.add_child(pulse_sphere)
		# Initial distance-based scaling
		_apply_distance_scale_to_pulse(pulse_sphere)
		
		# Create animation tween
		var pulse_tween = create_tween()
		pulse_tween.set_loops()  # Infinite loop
		_pulse_tweens.append(pulse_tween)
		
		# Stagger the pulses so they don't all start together
		var delay = pulse_index * 0.5  # 0.5 second delay between pulses
		var travel_time = 2.0  # Time to travel the full curve
		
		# Add initial delay for staggering
		if delay > 0:
			pulse_tween.tween_interval(delay)
		
		# Animate the pulse along the curve points
		pulse_tween.tween_method(
			func(progress: float):
				var point_index = int(progress * (curve_points.size() - 1))
				var local_progress = (progress * (curve_points.size() - 1)) - point_index
				
				# Interpolate between current and next point
				if point_index < curve_points.size() - 1:
					var current_point = curve_points[point_index]
					var next_point = curve_points[point_index + 1]
					pulse_sphere.position = current_point.lerp(next_point, local_progress)
				else:
					pulse_sphere.position = curve_points[-1]  # End point
				# Update size relative to camera distance while moving
				_apply_distance_scale_to_pulse(pulse_sphere)
				
				# Pulse the glow intensity
				var glow_intensity = 3.0 + sin(Time.get_ticks_msec() / 100.0) * 1.5
				pulse_material.emission_energy = glow_intensity,
			0.0,
			1.0,
			travel_time
		)
		
		# Add a brief pause at the end before restarting
		pulse_tween.tween_interval(0.3)

## Create a recursive (self-looping) connection
func _create_recursive_loop(center_pos: Vector3, area_id: StringName, mapping_set: InterCorticalMappingSet, is_global_mode: bool = false) -> Node3D:
	var is_plastic = _is_mapping_set_plastic(mapping_set)  # Back to original logic
	
	# If inhibitory and excitatory coexist in the recursive mapping set, render two loops
	# separated slightly in height so both remain visible.
	var has_inhibitory := false
	var has_excitatory := false
	if mapping_set != null and not mapping_set.mappings.is_empty():
		has_inhibitory = mapping_set.is_any_PSP_multiplier_negative()
		has_excitatory = mapping_set.is_any_PSP_multiplier_positive()
	
	if has_inhibitory and has_excitatory:
		var mixed_loop := Node3D.new()
		var plastic_prefix = "PLA_" if is_plastic else "STD_"
		mixed_loop.name = "MIXED_RECURS_" + plastic_prefix + area_id
		
		var loop_height_separation := 0.6  # Small vertical separation between E/I loops
		var excitatory_loop = _create_recursive_loop_variant(center_pos, area_id, false, is_plastic, is_global_mode, loop_height_separation)
		var inhibitory_loop = _create_recursive_loop_variant(center_pos, area_id, true, is_plastic, is_global_mode, -loop_height_separation)
		mixed_loop.add_child(excitatory_loop)
		mixed_loop.add_child(inhibitory_loop)
		return mixed_loop
	
	var is_inhibitory = _is_mapping_set_inhibitory(mapping_set)
	return _create_recursive_loop_variant(center_pos, area_id, is_inhibitory, is_plastic, is_global_mode, 0.0)

## Internal helper that creates a single recursive loop visual.
## loop_height_offset vertically shifts the loop relative to its default loop height.
func _create_recursive_loop_variant(
	center_pos: Vector3,
	area_id: StringName,
	is_inhibitory: bool,
	is_plastic: bool,
	is_global_mode: bool,
	loop_height_offset: float
) -> Node3D:
	
	# Create a container for the loop
	var loop_node = Node3D.new()
	var type_prefix = "INH_RECURS_" if is_inhibitory else "EXC_RECURS_"
	var plastic_prefix = "PLA_" if is_plastic else "STD_"
	loop_node.name = type_prefix + plastic_prefix + area_id
	
	# Create a circular loop around the cortical area
	var loop_radius = 3.0  # Radius of the loop around the area
	var loop_height = 2.0 + loop_height_offset  # Height above the area center
	var num_segments = 16  # More segments for smooth circle
	
	# Calculate loop points in a circle
	var loop_points: Array[Vector3] = []
	for i in range(num_segments + 1):  # +1 to close the loop
		var angle = (i / float(num_segments)) * TAU
		var loop_point = center_pos + Vector3(
			cos(angle) * loop_radius,
			loop_height,
			sin(angle) * loop_radius
		)
		loop_points.append(loop_point)
	
	# For plastic recursive loops, create dashed circular pattern
	if is_plastic:
		# Calculate number of dashes based on loop circumference for consistent spacing
		var loop_circumference = TAU * loop_radius  # 2π * radius
		var desired_dash_spacing = 2.0  # Units between dashes for loops
		var num_dashes = max(6, int(loop_circumference / desired_dash_spacing))  # Minimum 6 dashes
		
		var dash_material = _create_plastic_animated_material(is_inhibitory, is_global_mode)
		
		for i in range(num_dashes):
			var angle = (float(i) / float(num_dashes)) * TAU
			var dash_position = center_pos + Vector3(
				cos(angle) * loop_radius,
				loop_height,
				sin(angle) * loop_radius
			)
			
			# Calculate tangent direction for circular orientation
			var tangent_direction = Vector3(-sin(angle), 0, cos(angle))  # Perpendicular to radius
			
			# Create a small cylinder for each dash
			var dash = MeshInstance3D.new()
			dash.name = "LoopDash_" + str(i)
			dash.mesh = CylinderMesh.new()
			
			# Set dash size (longer line segment)
			var cylinder_mesh = dash.mesh as CylinderMesh
			cylinder_mesh.height = 1.4  # Longer dashes for loops
			cylinder_mesh.top_radius = 0.06  # Thin line
			cylinder_mesh.bottom_radius = 0.06
			cylinder_mesh.radial_segments = 6  # Simple geometry
			
			# Position the dash
			dash.position = dash_position
			dash.material_override = dash_material
			
			# Orient the dash tangent to the circle (Y-axis is cylinder height)
			if tangent_direction.length() > 0.001:
				# Create transform matrix to align Y-axis (cylinder height) with tangent direction
				var up_vector = Vector3.UP
				if abs(tangent_direction.dot(Vector3.UP)) > 0.9:
					up_vector = Vector3.FORWARD  # Avoid parallel vectors
				
				var right_vector = up_vector.cross(tangent_direction).normalized()
				var corrected_up = tangent_direction.cross(right_vector).normalized()
				
				# Set the transform to align Y-axis with tangent direction
				dash.transform.basis = Basis(right_vector, tangent_direction, corrected_up)
			
			loop_node.add_child(dash)
			
			# Store position for pulse animation
			if i == 0:
				loop_points.append(dash_position)
			loop_points.append(dash_position)
		
		# Store dashes for animation
		loop_node.set_meta("plastic_loop_dashes", loop_node.get_children())
		_add_circular_dash_wave_animation(loop_node, center_pos, loop_radius)
	else:
		# For non-plastic recursive connections, use continuous segments
		var loop_material = _create_recursive_material(is_inhibitory, is_global_mode)
		
		for i in range(num_segments):
			var point1 = loop_points[i]
			var point2 = loop_points[i + 1]
			
			var segment = _create_curve_segment(point1, point2, i, loop_material)
			loop_node.add_child(segment)
		
	
	# Create recursive pulse animation
	_create_recursive_pulse_animation(loop_node, loop_points, area_id, is_inhibitory)
	
	return loop_node

## Create material for recursive connections based on inhibitory/excitatory properties
func _create_recursive_material(is_inhibitory: bool = false, is_global_mode: bool = false) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	
	if is_global_mode:
		# Global mode - Gray color for recursive connections
		material.albedo_color = Color(0.7, 0.7, 0.7, 0.8)  # Light gray
		material.emission = Color(0.5, 0.5, 0.5)     # Gray emission
	elif is_inhibitory:
		# Inhibitory recursive connections - Red
		# Keep consistent with non-recursive inhibitory connections.
		material.albedo_color = Color(1.0, 0.2, 0.2, 0.9)  # Bright red
		material.emission = Color(1.0, 0.2, 0.2)
	else:
		# Excitatory recursive connections - Green
		# Keep consistent with non-recursive excitatory connections.
		material.albedo_color = Color(0.2, 1.0, 0.3, 0.9)  # Bright green
		material.emission = Color(0.2, 1.0, 0.3)
	
	material.emission_enabled = true
	material.emission_energy = 2.5
	material.flags_unshaded = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

## Create pulse animation for recursive loops
func _create_recursive_pulse_animation(loop_node: Node3D, loop_points: Array[Vector3], area_id: StringName, is_inhibitory: bool = false) -> void:
	
	# Create multiple pulses traveling around the loop
	var num_pulses = 2  # Fewer pulses for cleaner loop animation
	
	for pulse_index in range(num_pulses):
		# Create a glowing pulse sphere
		var pulse_sphere = MeshInstance3D.new()
		pulse_sphere.name = "RecursivePulse_" + str(pulse_index)
		
		# Create sphere mesh (slightly smaller for recursive)
		var sphere_mesh = SphereMesh.new()
		sphere_mesh.radius = 0.25  # Smaller than regular pulses
		sphere_mesh.height = 0.5
		sphere_mesh.radial_segments = 8
		sphere_mesh.rings = 4
		pulse_sphere.mesh = sphere_mesh
		
		# Create bright pulsing material based on connection type
		var pulse_material = StandardMaterial3D.new()
		pulse_material.emission_enabled = true
		pulse_material.emission_energy = 4.0
		pulse_material.flags_unshaded = true
		pulse_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pulse_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		
		# Both inhibitory and excitatory recursive - Bright white for visibility
		pulse_material.albedo_color = Color(1.0, 1.0, 1.0, 0.8)  # Bright white
		pulse_material.emission = Color(1.0, 1.0, 1.0)
		
		pulse_sphere.material_override = pulse_material
		
		# Start pulse at beginning of loop
		pulse_sphere.position = loop_points[0]
		loop_node.add_child(pulse_sphere)
		# Initial distance-based scaling
		_apply_distance_scale_to_pulse(pulse_sphere)
		
		# Create animation tween
		var pulse_tween = create_tween()
		pulse_tween.set_loops()  # Infinite loop
		_pulse_tweens.append(pulse_tween)
		
		# Stagger the pulses
		var delay = pulse_index * 1.0  # 1 second delay between recursive pulses
		var travel_time = 3.0  # Slower travel for recursive loops
		
		# Add initial delay for staggering
		if delay > 0:
			pulse_tween.tween_interval(delay)
		
		# Animate the pulse around the loop
		pulse_tween.tween_method(
			func(progress: float):
				var point_index = int(progress * (loop_points.size() - 2))  # -2 because last point = first point
				var local_progress = (progress * (loop_points.size() - 2)) - point_index
				
				# Interpolate between current and next point
				if point_index < loop_points.size() - 1:
					var current_point = loop_points[point_index]
					var next_point = loop_points[point_index + 1]
					pulse_sphere.position = current_point.lerp(next_point, local_progress)
				else:
					pulse_sphere.position = loop_points[0]  # Back to start
				# Update size relative to camera distance while moving
				_apply_distance_scale_to_pulse(pulse_sphere)
				
				# Pulse the glow intensity
				var glow_intensity = 3.0 + sin(Time.get_ticks_msec() / 80.0) * 1.5
				pulse_material.emission_energy = glow_intensity,
			0.0,
			1.0,
			travel_time
		)
		
		# Brief pause before restarting
		pulse_tween.tween_interval(0.2)
	

## Check if a cortical area should use PNG icon rendering
func _should_use_png_icon(area: AbstractCorticalArea) -> bool:
	# Check for special core areas (supports both old and new formats)
	if AbstractCorticalArea.is_death_area(area.cortical_ID):
		return true
	
	# Add more cortical area IDs here that should use PNG icons (using old format for now)
	var png_icon_areas = ["_health", "_energy", "_status"]  # Expandable list
	return area.cortical_ID in png_icon_areas

## Helper function to determine if a mapping set contains inhibitory connections
func _is_mapping_set_inhibitory(mapping_set: InterCorticalMappingSet) -> bool:
	"""Check if the mapping set contains any inhibitory connections (negative PSC multiplier)"""
	if mapping_set == null or mapping_set.mappings.is_empty():
		return false
	
	# Check all mappings in the set
	for mapping in mapping_set.mappings:
		if mapping.post_synaptic_current_multiplier < 0:
			return true  # At least one inhibitory connection found
	
	return false  # All connections are excitatory

## Helper function to determine if a mapping set contains plastic connections
func _is_mapping_set_plastic(mapping_set: InterCorticalMappingSet) -> bool:
	"""Check if the mapping set contains any plastic connections"""
	if mapping_set == null or mapping_set.mappings.is_empty():
		return false
	
	# Check all mappings in the set
	for mapping in mapping_set.mappings:
		if mapping.morphology_used != null and mapping.morphology_used.name == &"associative_memory":
			return true  # Bi-directional STDP is inherently plastic
		if mapping.is_plastic:
			return true  # At least one plastic connection found
	
	return false  # All connections are non-plastic

## Helper function to determine if a mapping set is plastic and bidirectional (mixed sign)
func _is_mapping_set_bidirectional_plastic(mapping_set: InterCorticalMappingSet) -> bool:
	if mapping_set == null or mapping_set.mappings.is_empty():
		return false
	for mapping in mapping_set.mappings:
		if mapping.morphology_used != null and mapping.morphology_used.name == &"associative_memory":
			return true
	var source_area: AbstractCorticalArea = mapping_set.source_cortical_area
	var destination_area: AbstractCorticalArea = mapping_set.destination_cortical_area
	if source_area == null or destination_area == null:
		return false
	if not _is_mapping_set_plastic(mapping_set):
		return false
	var reciprocal_set = destination_area.efferent_mappings.get(source_area, null)
	if reciprocal_set == null:
		return false
	return _is_mapping_set_plastic(reciprocal_set)

## Helper function to determine if MAJORITY of mappings in a set are plastic (for connection-wide effects)
func _is_mapping_set_majority_plastic(mapping_set: InterCorticalMappingSet) -> bool:
	"""Check if the majority of mappings in the set are plastic - use this for visual effects"""
	if mapping_set == null or mapping_set.mappings.is_empty():
		return false
	
	var plastic_count = 0
	var total_count = mapping_set.mappings.size()
	
	for mapping in mapping_set.mappings:
		if mapping.is_plastic:
			plastic_count += 1
	
	return plastic_count > (total_count / 2)  # More than 50% are plastic

## Add dramatic wobble effect to a point for plastic connections
func _add_wobble_to_point(point: Vector3, t: float) -> Vector3:
	"""Add a dramatic, highly visible wobble effect to connection points for plastic connections"""
	var time = Time.get_ticks_msec() / 1000.0  # Current time in seconds
	var wobble_strength = 1.2  # Much stronger wobble - 4x stronger than before
	var wobble_frequency = 1.5  # Slightly slower for more dramatic effect
	
	# Create multiple layered sine waves for very organic, snake-like movement
	var primary_wobble_x = sin(time * wobble_frequency + t * PI * 2) * wobble_strength
	var primary_wobble_y = cos(time * wobble_frequency * 1.3 + t * PI * 1.5) * wobble_strength * 0.8
	var primary_wobble_z = sin(time * wobble_frequency * 0.8 + t * PI * 2.5) * wobble_strength
	
	# Add secondary higher-frequency ripples for more complexity
	var ripple_strength = wobble_strength * 0.3
	var ripple_frequency = wobble_frequency * 3.5
	var secondary_wobble_x = sin(time * ripple_frequency + t * PI * 4) * ripple_strength
	var secondary_wobble_y = cos(time * ripple_frequency * 1.7 + t * PI * 3) * ripple_strength
	var secondary_wobble_z = sin(time * ripple_frequency * 1.2 + t * PI * 5) * ripple_strength
	
	# Combine primary and secondary wobbles
	var total_wobble = Vector3(
		primary_wobble_x + secondary_wobble_x,
		primary_wobble_y + secondary_wobble_y,
		primary_wobble_z + secondary_wobble_z
	)
	
	return point + total_wobble

## Create animated material for plastic connections with pulsing effects
func _create_plastic_animated_material(is_inhibitory: bool = false, is_global_mode: bool = false) -> StandardMaterial3D:
	"""Create a dynamic, pulsing material for plastic connections with enhanced visual effects"""
	var material = StandardMaterial3D.new()
	
	if is_global_mode:
		# Global mode - Gray color for all connections
		material.albedo_color = Color(0.7, 0.7, 0.7, 0.8)
		material.emission = Color(0.5, 0.5, 0.5)
	elif is_inhibitory:
		# Inhibitory plastic connections - Enhanced red with stronger base emission
		material.albedo_color = Color(1.0, 0.3, 0.3, 0.95)  # More opaque for visibility
		material.emission = Color(1.0, 0.2, 0.2)  # Brighter emission
	else:
		# Excitatory plastic connections - Enhanced green with stronger base emission  
		material.albedo_color = Color(0.3, 1.0, 0.4, 0.95)  # More opaque for visibility
		material.emission = Color(0.2, 1.0, 0.3)  # Brighter emission
	
	material.emission_enabled = true
	material.emission_energy = 3.0  # Higher base emission for plastic connections
	material.flags_unshaded = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.metallic = 0.3  # Add some metallic sheen for plastic connections
	material.roughness = 0.4
	
	return material

## Add dynamic thickness animation to plastic connection segments
func _add_plastic_thickness_animation(segment: MeshInstance3D, t_position: float) -> void:
	"""Add breathing/pulsing thickness animation to plastic connection segments"""
	if not segment or not segment.mesh:
		return
	
	# Create a tween for continuous thickness animation
	var thickness_tween = create_tween()
	thickness_tween.set_loops()  # Infinite animation
	
	# Store reference to the original cylinder mesh
	var cylinder_mesh = segment.mesh as CylinderMesh
	if not cylinder_mesh:
		return
	
	var base_radius = cylinder_mesh.top_radius
	var thickness_variation = 0.08  # More subtle thickness variation (8% instead of 15%)
	var breathing_speed = 2.5 + (t_position * 0.5)  # Speed varies along curve
	
	# Animate thickness with breathing effect
	thickness_tween.tween_method(
		func(scale_factor: float):
			# Safety checks - ensure objects still exist
			if not segment or not is_instance_valid(segment):
				thickness_tween.kill()  # Stop animation if segment is destroyed
				return
			
			if not cylinder_mesh or not is_instance_valid(cylinder_mesh):
				thickness_tween.kill()  # Stop animation if mesh is destroyed
				return
			
			var time_offset = t_position * PI * 2  # Phase shift based on position
			var breathing = sin(Time.get_ticks_msec() / 1000.0 * breathing_speed + time_offset) * thickness_variation
			var new_radius = base_radius * (1.0 + breathing)
			
			# Apply thickness changes safely
			cylinder_mesh.top_radius = new_radius
			cylinder_mesh.bottom_radius = new_radius
			
			# Also pulse the material emission energy with null safety
			if segment.material_override != null:
				var material = segment.material_override as StandardMaterial3D
				if material != null:
					var emission_pulse = 1.0 + (sin(Time.get_ticks_msec() / 1000.0 * breathing_speed * 1.5 + time_offset) * 0.2)  # More subtle pulse - reduced from 0.4 to 0.2
					material.emission_energy = 3.0 * emission_pulse,
		0.0,
		1.0,
		breathing_speed
	)

## Cleanup method to disconnect signals and prevent memory leaks
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_cleanup_cache_connections()

func _cleanup_cache_connections() -> void:
	print("🧹 CLEANUP: Disconnecting cache signals for cortical area: ", _representing_cortial_area.cortical_ID if _representing_cortial_area else "unknown")
	
	# Disconnect cache reload signal
	if FeagiCore.feagi_local_cache:
		var cache = FeagiCore.feagi_local_cache
		if cache.cache_reloaded.is_connected(_on_cache_reloaded):
			cache.cache_reloaded.disconnect(_on_cache_reloaded)
		if cache.mappings_reloaded.is_connected(_on_cache_reloaded):
			cache.mappings_reloaded.disconnect(_on_cache_reloaded)
		if cache.cortical_areas_reloaded.is_connected(_on_cache_reloaded):
			cache.cortical_areas_reloaded.disconnect(_on_cache_reloaded)
		if cache.brain_regions_reloaded.is_connected(_on_cache_reloaded):
			cache.brain_regions_reloaded.disconnect(_on_cache_reloaded)
	
	# Disconnect mapping change signals if cortical area still exists
	if _representing_cortial_area:
		if _representing_cortial_area.afferent_input_cortical_area_added.is_connected(_on_mapping_changed):
			_representing_cortial_area.afferent_input_cortical_area_added.disconnect(_on_mapping_changed)
		if _representing_cortial_area.afferent_input_cortical_area_removed.is_connected(_on_mapping_changed):
			_representing_cortial_area.afferent_input_cortical_area_removed.disconnect(_on_mapping_changed)
		if _representing_cortial_area.efferent_input_cortical_area_added.is_connected(_on_mapping_changed):
			_representing_cortial_area.efferent_input_cortical_area_added.disconnect(_on_mapping_changed)
		if _representing_cortial_area.efferent_input_cortical_area_removed.is_connected(_on_mapping_changed):
			_representing_cortial_area.efferent_input_cortical_area_removed.disconnect(_on_mapping_changed)
		if _representing_cortial_area.recursive_cortical_area_added.is_connected(_on_mapping_changed):
			_representing_cortial_area.recursive_cortical_area_added.disconnect(_on_mapping_changed)
		if _representing_cortial_area.recursive_cortical_area_removed.is_connected(_on_mapping_changed):
			_representing_cortial_area.recursive_cortical_area_removed.disconnect(_on_mapping_changed)
		if _representing_cortial_area.coordinates_3D_updated.is_connected(_refresh_io_direction_indicator):
			_representing_cortial_area.coordinates_3D_updated.disconnect(_refresh_io_direction_indicator)
		if _representing_cortial_area.dimensions_3D_updated.is_connected(_refresh_io_direction_indicator):
			_representing_cortial_area.dimensions_3D_updated.disconnect(_refresh_io_direction_indicator)

#region Cache Event Handlers

## Called when the cache is reloaded to refresh connection curves
func _on_cache_reloaded() -> void:
	# If we're currently showing connections, refresh them with updated cache data
	if _is_volume_moused_over:
		_hide_neural_connections()  # Clear old curves
		_show_neural_connections()  # Rebuild with fresh cache data
	_refresh_io_direction_indicator()

## Called when mapping connections change in real-time
func _on_mapping_changed(_area = null, _mapping_set = null) -> void:
	# If we're currently showing connections, refresh them immediately
	if _is_volume_moused_over:
		_hide_neural_connections()  # Clear old curves
		_show_neural_connections()  # Rebuild with updated mappings
	_refresh_io_direction_indicator()
		
#endregion
