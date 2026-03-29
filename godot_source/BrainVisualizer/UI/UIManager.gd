extends Node
class_name UIManager
## Manages UI aspects of BV as a whole

const PREFAB_CB: PackedScene = preload("res://BrainVisualizer/UI/CircuitBuilder/CircuitBuilder.tscn")
const MOUSE_CONTEXT_FONT_SIZE: int = 32
const MOUSE_CONTEXT_OUTLINE_SIZE: int = 2
const MOUSE_CONTEXT_MARGIN_PX: int = 10
const MOUSE_CONTEXT_MAX_WIDTH_PX: int = 1200
const MOUSE_CONTEXT_HEIGHT_PX: int = 44

# TODO dev menu - build_settings_object



## public var references and init for this object
#region References and Init

var window_manager:
	get: return _window_manager
var notification_system: NotificationSystem:
	get: return _notification_system
var top_bar: TopBar:
	get: return _top_bar
var root_UI_view: UIView:
	get: return _root_UI_view
var selection_system: SelectionSystem:
	get: return _selection_system
# Main brain monitor instance - public access
var temp_root_bm: UI_BrainMonitor_3DScene = null
var qc_guide_source_bm: UI_BrainMonitor_3DScene = null
var qc_last_source_scene_name: String = ""
var qc_last_source_start: Vector3 = Vector3.ZERO
var qc_last_source_end: Vector3 = Vector3.ZERO
var qc_last_bridge_scene_name: String = ""
var qc_last_bridge_start: Vector3 = Vector3.ZERO
var qc_last_bridge_end: Vector3 = Vector3.ZERO

# Session-scoped last created cortical position (for prefill nudging)
var last_created_cortical_location: Vector3i = Vector3i.ZERO
var last_created_cortical_size: Vector3i = Vector3i.ZERO

func qc_log_both() -> void:
	print("[QC_BOTH] src_scene=", qc_last_source_scene_name,
		" src_start=", qc_last_source_start,
		" src_end=", qc_last_source_end,
		" br_scene=", qc_last_bridge_scene_name,
		" br_start=", qc_last_bridge_start,
		" br_end=", qc_last_bridge_end)

var _top_bar: TopBar
var _window_manager
var _root_UI_view: UIView
var _notification_system: NotificationSystem
var _version_label: Label
var _mouse_context_label: Label
var _active_hover_bm: UI_BrainMonitor_3DScene = null

# CRITICAL: Track whether 3D scene has been successfully instantiated
# This prevents hiding the loading screen before the 3D scene is actually ready
var _3d_scene_instantiated: bool = false
var _selection_system: SelectionSystem
var _temp_bm_holder: UI_Capsules_Capsule
var _temp_bm_camera_pos: Vector3 = Vector3(0,0,0)
var _temp_bm_camera_rot: Vector3
var _fps_label: Label
var _loading_status_label: Label
var _manual_stim_pending_workers: Dictionary = {}
var _manual_stim_timeouts: Dictionary = {}
var _genome_confirm_retry_in_flight: bool = false
var _startup_scale_locked_by_endpoint: bool = false

# Startup UI scaling thresholds based only on monitor DPI and resolution.
# Goal: fit more content on low-resolution displays while preserving readability on high-DPI panels.
const UI_STARTUP_DPI_XLARGE: int = 180
const UI_STARTUP_DPI_LARGE: int = 150
const UI_STARTUP_DPI_MEDIUM: int = 125
const UI_STARTUP_DPI_STANDARD: int = 96
const UI_STARTUP_LONG_SIDE_COMPACT: int = 1600
const UI_STARTUP_SHORT_SIDE_COMPACT: int = 900
const UI_STARTUP_LONG_SIDE_STANDARD: int = 1920
const UI_STARTUP_LONG_SIDE_LARGE: int = 2560
const UI_STARTUP_FULLSCREEN_HIDPI_FALLBACK_SCALE: float = 2.0
const UI_SCALE_SMALL: float = 0.75
const UI_SCALE_STANDARD: float = 1.0
const UI_SCALE_MEDIUM: float = 1.25
const UI_SCALE_LARGE: float = 1.5
const UI_SCALE_XLARGE: float = 2.0
enum STARTUP_DPI_TIER { DPI_STANDARD, DPI_MEDIUM, DPI_LARGE, DPI_XLARGE }
enum STARTUP_RES_TIER { RES_COMPACT, RES_STANDARD, RES_LARGE, RES_XLARGE }

## Top bar "brain activity" tool: global connection curves vs voxel-level API inspector.
enum BRAIN_MONITOR_ACTIVITY_MODE { GLOBAL_NEURAL_CONNECTIONS = 0, VOXEL_INSPECTOR = 1, MEMORY_INSPECTOR = 2 }

var brain_monitor_activity_mode: BRAIN_MONITOR_ACTIVITY_MODE = BRAIN_MONITOR_ACTIVITY_MODE.GLOBAL_NEURAL_CONNECTIONS
var _voxel_inspector_fetch_generation: int = 0
var _memory_inspector_fetch_generation: int = 0
var _memory_neuron_fetch_generation: int = 0


func _enter_tree():
	_screen_size = get_viewport().get_visible_rect().size
	get_viewport().size_changed.connect(_update_screen_size)
	_find_possible_scales()
	# Select startup scale from monitor DPI + monitor resolution only.
	_apply_startup_scale_from_display_metrics()
	# Multi-monitor note: window state restoration can move BV to a different screen
	# one or more frames after startup. Re-evaluate once after the window settles.
	call_deferred("_reapply_startup_scale_after_window_settle")

func _apply_startup_scale_from_display_metrics() -> void:
	var startup_scale: float = _select_startup_scale_from_display_metrics()
	print("UIMANAGER: [SCALE_TRACE] Applying startup scale from display metrics: %s" % startup_scale)
	request_switch_to_theme(startup_scale, UIManager.THEME_COLORS.DARK)

func _reapply_startup_scale_after_window_settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if _startup_scale_locked_by_endpoint:
		print("UIMANAGER: [SCALE_TRACE] Skipping settled startup reapply because endpoint theme is locked")
		return
	print("UIMANAGER: [SCALE_TRACE] Reapplying startup scale after window settle")
	_apply_startup_scale_from_display_metrics()

func _process(_delta: float):
	if _fps_label:
		var fps = Engine.get_frames_per_second()
		_fps_label.text = "%d FPS" % fps

func _ready():
	_notification_system = $NotificationSystem
	_top_bar = $TopBar
	_window_manager = $FloatingWindowsLayer/WindowManager
	_version_label = $VersionLabel
	_root_UI_view = $CB_Holder/UIView
	_selection_system = SelectionSystem.new()
	_loading_status_label = $LoadingScreenOverlayLayer/TempLoadingScreen/LoadingOverlay/Bottom_Row/StatusLabel
	
	_version_label.text = Time.get_datetime_string_from_unix_time(BVVersion.brain_visualizer_timestamp)
	_top_bar.resized.connect(_top_bar_resized)
	_top_bar_resized()
	
	# Create FPS label in bottom right corner
	_fps_label = Label.new()
	_fps_label.name = "FPS_Label"
	_fps_label.anchors_preset = Control.PRESET_BOTTOM_RIGHT
	_fps_label.anchor_left = 1.0
	_fps_label.anchor_top = 1.0
	_fps_label.anchor_right = 1.0
	_fps_label.anchor_bottom = 1.0
	_fps_label.offset_left = -120.0
	_fps_label.offset_top = -30.0
	_fps_label.offset_right = -10.0
	_fps_label.offset_bottom = -10.0
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fps_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_fps_label.add_theme_font_size_override("font_size", 16)
	add_child(_fps_label)
	_setup_mouse_context_label()
	
	# Connect cortical area cache signals
	FeagiCore.feagi_local_cache.cortical_areas.cortical_area_added.connect(_proxy_notification_cortical_area_added)
	FeagiCore.feagi_local_cache.cortical_areas.cortical_area_about_to_be_removed.connect(_proxy_notification_cortical_area_removed)
	FeagiCore.feagi_local_cache.cortical_areas.cortical_area_mass_updated.connect(_proxy_notification_cortical_area_updated)
	#FeagiCore.feagi_local_cache.cortical_areas.cortical_area_mappings_changed.connect(_proxy_notification_mappings_updated)
	FeagiCore.feagi_local_cache.morphologies.morphology_added.connect(_proxy_notification_morphology_added)
	FeagiCore.feagi_local_cache.morphologies.morphology_about_to_be_removed.connect(_proxy_notification_morphology_removed)
	#FeagiCore.feagi_local_cache.morphologies.morphology_updated.connect(_proxy_notification_morphology_updated)
	FeagiCore.feagi_local_cache.brain_readiness_changed.connect(_on_brain_readiness_changed)
	FeagiCore.feagi_local_cache.genome_availability_changed.connect(_on_genome_availability_changed)
	FeagiCore.feagi_local_cache.genome_cache_replaced.connect(_on_genome_cache_replaced)
	FeagiCore.network.connection_state_changed.connect(_on_connection_state_changed)
	FeagiCore.network.websocket_API.FEAGI_socket_health_changed.connect(_on_websocket_health_changed)
	FeagiCore.genome_load_state_changed.connect(_on_genome_load_state_changed)
	BV.UI.selection_system.objects_selection_event_called.connect(_selection_processing)

	

#endregion

## Initializes the global mouse hover label shown in the screen corner.
func _setup_mouse_context_label() -> void:
	_mouse_context_label = Label.new()
	_mouse_context_label.name = "MouseContextHUD"
	_mouse_context_label.anchors_preset = Control.PRESET_BOTTOM_LEFT
	_mouse_context_label.anchor_left = 0.0
	_mouse_context_label.anchor_top = 1.0
	_mouse_context_label.anchor_right = 0.0
	_mouse_context_label.anchor_bottom = 1.0
	_mouse_context_label.offset_left = float(MOUSE_CONTEXT_MARGIN_PX)
	_mouse_context_label.offset_top = -float(MOUSE_CONTEXT_HEIGHT_PX)
	_mouse_context_label.offset_right = float(MOUSE_CONTEXT_MAX_WIDTH_PX)
	_mouse_context_label.offset_bottom = -float(MOUSE_CONTEXT_MARGIN_PX)
	_mouse_context_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_mouse_context_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_mouse_context_label.add_theme_color_override("font_color", Color.WHITE)
	_mouse_context_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_mouse_context_label.add_theme_constant_override("outline_size", MOUSE_CONTEXT_OUTLINE_SIZE)
	_mouse_context_label.add_theme_font_size_override("font_size", MOUSE_CONTEXT_FONT_SIZE)
	_mouse_context_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mouse_context_label.text = ""
	_mouse_context_label.z_index = 80
	add_child(_mouse_context_label)

## Marks which brain monitor currently owns hover updates.
func set_active_hover_bm(bm: UI_BrainMonitor_3DScene) -> void:
	_active_hover_bm = bm

## Clears hover ownership and the label when a BM loses hover.
func clear_active_hover_bm(bm: UI_BrainMonitor_3DScene) -> void:
	if _active_hover_bm != bm:
		return
	_active_hover_bm = null
	if _mouse_context_label:
		_mouse_context_label.text = ""

## Updates the global hover label from the active brain monitor only.
func update_mouse_context(text: String, source_bm: UI_BrainMonitor_3DScene) -> void:
	if _mouse_context_label == null:
		return
	if _active_hover_bm != null and source_bm != _active_hover_bm:
		return
	_mouse_context_label.text = text

## Clears the global hover label if the active monitor requests it.
func clear_mouse_context(source_bm: UI_BrainMonitor_3DScene) -> void:
	if _mouse_context_label == null:
		return
	if _active_hover_bm != null and source_bm != _active_hover_bm:
		return
	_mouse_context_label.text = ""


func _voxel_inspector_window() -> WindowVoxelInspector:
	if _window_manager == null:
		return null
	return _window_manager.loaded_windows.get(WindowVoxelInspector.WINDOW_NAME) as WindowVoxelInspector


## Called from the Voxel inspector window: fetch `/v1/cortical_area/voxel_neurons` for the chosen area and voxel.
## `synapse_page` is 0-based; outgoing/incoming synapse lists are paged together (see FEAGI API).
func request_voxel_inspector_fetch(cortical_id: StringName, coord: Vector3i, synapse_page: int = 0) -> void:
	if brain_monitor_activity_mode != BRAIN_MONITOR_ACTIVITY_MODE.VOXEL_INSPECTOR:
		return
	var win := _voxel_inspector_window()
	if win == null:
		_window_manager.spawn_voxel_inspector()
		win = _voxel_inspector_window()
	if win == null:
		return
	if not FeagiCore.can_interact_with_feagi():
		win.set_error_line("FEAGI is not ready.")
		win.restore_pagination_after_failed_fetch()
		return
	_voxel_inspector_fetch_generation += 1
	var gen: int = _voxel_inspector_fetch_generation
	win.set_loading()
	_voxel_inspector_query_async(cortical_id, coord, synapse_page, gen)


func _voxel_inspector_query_async(cortical_id: StringName, coord: Vector3i, synapse_page: int, gen: int) -> void:
	var out: FeagiRequestOutput = await FeagiCore.requests.get_voxel_neurons(str(cortical_id), coord.x, coord.y, coord.z, synapse_page)
	if gen != _voxel_inspector_fetch_generation:
		return
	var win := _voxel_inspector_window()
	if win == null:
		return
	if out.success:
		var d: Dictionary = out.decode_response_as_dict()
		win.set_json_content(_format_voxel_inspector_response(d))
		win.update_summary_from_response(d)
		win.set_last_successful_voxel_payload(d)
		win.update_synapse_pagination_from_response(d)
		if win.is_voxel_synapse_visualization_enabled():
			_voxel_inspector_apply_synapse_visualization(d)
	else:
		win.set_error_line(out.decode_response_as_string())
		win.restore_pagination_after_failed_fetch()


## Rebuild 3D voxel synapse arcs from the last successful Inspect payload (toggle on).
func request_voxel_synapse_visualization_rebuild() -> void:
	var win := _voxel_inspector_window()
	if win == null:
		return
	var d: Dictionary = win.get_last_successful_voxel_payload()
	if d.is_empty():
		return
	_voxel_inspector_apply_synapse_visualization(d)


func _voxel_inspector_apply_synapse_visualization(d: Dictionary) -> void:
	var cid: String = str(d.get("cortical_id", ""))
	if cid.is_empty() or FeagiCore.feagi_local_cache == null:
		return
	var area: AbstractCorticalArea = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.get(
		StringName(cid),
		null
	)
	if area == null:
		return
	var bm: UI_BrainMonitor_3DScene = get_brain_monitor_for_cortical_area(area)
	if bm == null:
		return
	clear_voxel_synapse_visualization_all_brain_monitors()
	bm.rebuild_voxel_synapse_visualization_from_api_payload(d)


func clear_voxel_synapse_visualization_all_brain_monitors() -> void:
	for bm in _find_all_brain_monitors_in_scene_tree():
		if bm != null and is_instance_valid(bm):
			bm.clear_voxel_synapse_visualization()


func _format_voxel_inspector_response(d: Dictionary) -> String:
	# JSON.parse() in Godot stores every number as float; stringify would show 1.0 for integers.
	var normalized: Variant = _json_floats_whole_to_int_for_display(d)
	var s: String = JSON.stringify(normalized, "\t")
	if s.length() > 4000:
		s = s.substr(0, 4000) + "\n...(truncated)"
	return s


## Recursively convert float variants that are mathematically integers to int so JSON.stringify prints 1 not 1.0.
func _json_floats_whole_to_int_for_display(v: Variant) -> Variant:
	var t: int = typeof(v)
	if t == TYPE_FLOAT:
		var f: float = v
		if not is_finite(f):
			return v
		var r: float = roundf(f)
		if is_equal_approx(f, r):
			return int(r)
		return v
	if t == TYPE_DICTIONARY:
		var d: Dictionary = v
		var out: Dictionary = {}
		for k in d.keys():
			out[k] = _json_floats_whole_to_int_for_display(d[k])
		return out
	if t == TYPE_ARRAY:
		var a: Array = v
		var out: Array = []
		out.resize(a.size())
		for i in range(a.size()):
			out[i] = _json_floats_whole_to_int_for_display(a[i])
		return out
	return v


func _memory_inspector_window() -> WindowMemoryInspector:
	if _window_manager == null:
		return null
	return _window_manager.loaded_windows.get(WindowMemoryInspector.WINDOW_NAME) as WindowMemoryInspector


## Fetch `/v1/cortical_area/memory` for the selected memory cortical area (paginated neuron id list in JSON).
func request_memory_inspector_fetch(cortical_id: StringName, page: int = 0, page_size: int = 50) -> void:
	if brain_monitor_activity_mode != BRAIN_MONITOR_ACTIVITY_MODE.MEMORY_INSPECTOR:
		return
	var win := _memory_inspector_window()
	if win == null:
		_window_manager.spawn_memory_inspector()
		win = _memory_inspector_window()
	if win == null:
		return
	if not FeagiCore.can_interact_with_feagi():
		win.set_error_line("FEAGI is not ready.")
		win.restore_pagination_after_failed_fetch()
		return
	_memory_inspector_fetch_generation += 1
	var gen: int = _memory_inspector_fetch_generation
	win.set_loading()
	_memory_inspector_query_async(cortical_id, page, page_size, gen)


func _memory_inspector_query_async(cortical_id: StringName, page: int, page_size: int, gen: int) -> void:
	var out: FeagiRequestOutput = await FeagiCore.requests.get_memory_cortical_area(str(cortical_id), page, page_size)
	if gen != _memory_inspector_fetch_generation:
		return
	var win := _memory_inspector_window()
	if win == null:
		return
	if out.success:
		var d: Dictionary = out.decode_response_as_dict()
		win.set_area_json_content(_format_voxel_inspector_response(d))
		win.update_summary_from_response(d)
		win.update_area_pagination_from_response(d)
	else:
		win.set_error_line(out.decode_response_as_string())
		win.restore_pagination_after_failed_fetch()


## Fetch `/v1/connectome/memory_neuron` for a single memory neuron id (detail JSON).
func request_memory_neuron_detail_fetch(neuron_id: int) -> void:
	if brain_monitor_activity_mode != BRAIN_MONITOR_ACTIVITY_MODE.MEMORY_INSPECTOR:
		return
	var win := _memory_inspector_window()
	if win == null:
		return
	if not FeagiCore.can_interact_with_feagi():
		win.set_neuron_error_line("FEAGI is not ready.")
		return
	_memory_neuron_fetch_generation += 1
	var gen: int = _memory_neuron_fetch_generation
	win.set_neuron_loading()
	_memory_neuron_query_async(neuron_id, gen)


func _memory_neuron_query_async(neuron_id: int, gen: int) -> void:
	var out: FeagiRequestOutput = await FeagiCore.requests.get_memory_neuron(neuron_id)
	if gen != _memory_neuron_fetch_generation:
		return
	var win := _memory_inspector_window()
	if win == null:
		return
	if out.success:
		var d: Dictionary = out.decode_response_as_dict()
		win.set_neuron_json_content(_format_voxel_inspector_response(d))
	else:
		win.set_neuron_error_line(out.decode_response_as_string())


## Interactions with FEAGICORE
#region FEAGI Interactions
## Called from above when we are about to reset genome, may want to clear some things...
func FEAGI_about_to_reset_genome() -> void:
	print("UIMANAGER: [3D_SCENE_DEBUG] FEAGI_about_to_reset_genome() called - preparing for genome reload")
	_notification_system.add_notification("Reloading Genome...", NotificationSystemNotification.NOTIFICATION_TYPE.WARNING)
	_window_manager.force_close_all_windows()
	if _selection_system:
		_selection_system.clear_all_highlighted()
	_root_UI_view.reset()
	#_root_UI_view.close_all_non_root_brain_region_views()
	#toggle_loading_screen(true)
	if _temp_bm_holder:
		print("UIMANAGER: [3D_SCENE_DEBUG] Clearing existing 3D scene and saving camera position")
		(_temp_bm_holder.get_holding_UI() as UI_BrainMonitor_3DScene).clear_all_open_previews()
		_temp_bm_camera_pos = temp_root_bm.get_node("SubViewport/Center/PancakeCam").position
		_temp_bm_camera_rot = temp_root_bm.get_node("SubViewport/Center/PancakeCam").rotation
		print("UIMANAGER: [3D_SCENE_DEBUG] Saved camera position: ", _temp_bm_camera_pos, " rotation: ", _temp_bm_camera_rot)
		_temp_bm_holder.queue_free()
		print("UIMANAGER: [3D_SCENE_DEBUG] 3D scene cleared and queued for deletion")
	


## Called from above when we have no genome, disable UI elements that connect to it
func FEAGI_no_genome() -> void:
	print("UIMANAGER: [3D_SCENE_DEBUG] FEAGI_no_genome() called - disabling 3D scene")
	print("UIMANAGER: [3D_SCENE_DEBUG] Disabling FEAGI UI elements due to no genome")
	window_manager.force_close_all_windows()
	top_bar.toggle_buttons_interactability(false)
	
	# CRITICAL: Mark 3D scene as not instantiated when genome is lost
	print("UIMANAGER: [3D_SCENE_DEBUG] Marking _3d_scene_instantiated = false (genome lost)")
	_3d_scene_instantiated = false
	
	# Force loading screen check to show loading screen again
	print("UIMANAGER: [3D_SCENE_DEBUG] Forcing loading screen to show since genome lost")
	_update_loading_screen_visibility()


## Handle brain readiness changes
func _on_brain_readiness_changed(ready: bool) -> void:
	if ready:
		update_loading_status("FEAGI brain is ready")
	_update_loading_screen_visibility()

## Handle genome availability changes
func _on_genome_availability_changed(available: bool) -> void:
	_update_loading_screen_visibility()

## Handle completed genome cache replacement events
func _on_genome_cache_replaced() -> void:
	update_loading_status("Updating brain visualizer cache...")

## Handle genome load state changes to show/hide loading screen
func _on_genome_load_state_changed(_current_state: FeagiCore.GENOME_LOAD_STATE, _prev_state: FeagiCore.GENOME_LOAD_STATE) -> void:
	_update_loading_screen_visibility()

## Handle websocket health changes to show/hide loading screen
func _on_websocket_health_changed(_prev_health, _current_health) -> void:
	_update_loading_screen_visibility()

## Handle connection state changes to show/hide loading screen
func _on_connection_state_changed(_prev_state: FEAGINetworking.CONNECTION_STATE, new_state: FEAGINetworking.CONNECTION_STATE) -> void:
	print("UIMANAGER: Connection state changed to: ", FEAGINetworking.CONNECTION_STATE.keys()[new_state])
	
	# Update loading status based on connection state
	match new_state:
		FEAGINetworking.CONNECTION_STATE.INITIAL_HTTP_PROBING:
			update_loading_status("Checking FEAGI health...")
		FEAGINetworking.CONNECTION_STATE.INITIAL_WS_PROBING:
			update_loading_status("Making Websocket connection...")
		FEAGINetworking.CONNECTION_STATE.HEALTHY:
			update_loading_status("Websocket connected successfully!")
		FEAGINetworking.CONNECTION_STATE.RETRYING_HTTP:
			update_loading_status("Retrying HTTP connection...")
		FEAGINetworking.CONNECTION_STATE.RETRYING_WS:
			update_loading_status("Retrying Websocket connection...")
		FEAGINetworking.CONNECTION_STATE.RETRYING_HTTP_WS:
			update_loading_status("Retrying connections...")
		FEAGINetworking.CONNECTION_STATE.DISCONNECTED:
			update_loading_status("Disconnected")
	
	_update_loading_screen_visibility()

## Centralized function to determine if loading screen should be visible
## Loading screen is hidden ONLY when ALL conditions are met:
## 1. Connection is HEALTHY
## 2. Brain is ready 
## 3. Genome is available
## 4. Websocket is actually connected (if using websocket transport)
## 5. Genome load state is GENOME_READY (3D scene has been initialized)
func _update_loading_screen_visibility() -> void:
	var connection_healthy = FeagiCore.network.connection_state == FEAGINetworking.CONNECTION_STATE.HEALTHY
	var brain_ready = FeagiCore.feagi_local_cache.brain_readiness
	var genome_available = FeagiCore.feagi_local_cache.genome_availability
	var genome_scene_ready = FeagiCore.genome_load_state == FeagiCore.GENOME_LOAD_STATE.GENOME_READY
	
	# Additional check: If using websocket transport, verify websocket is actually connected
	var websocket_ok = true
	if FeagiCore.network._transport_mode == FEAGINetworking.TRANSPORT_MODE.WEBSOCKET:
		websocket_ok = FeagiCore.network.websocket_API.socket_health == FeagiCore.network.websocket_API.WEBSOCKET_HEALTH.CONNECTED
	
	print("UIMANAGER: Loading screen visibility check:")
	print("  - Connection healthy: %s (state: %s)" % [connection_healthy, FEAGINetworking.CONNECTION_STATE.keys()[FeagiCore.network.connection_state]])
	print("  - Brain ready: %s" % brain_ready)
	print("  - Genome available: %s" % genome_available)
	print("  - Genome scene ready: %s (state: %s)" % [genome_scene_ready, FeagiCore.GENOME_LOAD_STATE.keys()[FeagiCore.genome_load_state]])
	print("  - 3D scene instantiated: %s" % _3d_scene_instantiated)
	print("  - Websocket OK: %s (transport: %s)" % [websocket_ok, FEAGINetworking.TRANSPORT_MODE.keys()[FeagiCore.network._transport_mode]])
	
	# CRITICAL: Only hide loading screen when 3D scene is ACTUALLY instantiated
	# This prevents hiding the loading screen during the gap between genome_load_state becoming GENOME_READY
	# and the actual 3D scene being created via FEAGI_confirmed_genome()
	var should_hide_loading_screen = connection_healthy and brain_ready and genome_available and genome_scene_ready and _3d_scene_instantiated and websocket_ok
	
	if should_hide_loading_screen:
		print("UIMANAGER: ✅ All conditions met - hiding loading screen")
		update_loading_status("Ready!")
		toggle_loading_screen(false)
	else:
		var reasons = []
		if not connection_healthy:
			reasons.append("connection not healthy")
		if not brain_ready:
			reasons.append("brain not ready")
			if connection_healthy:
				update_loading_status("Awaiting FEAGI brain readiness...")
		if not genome_available:
			reasons.append("no genome available")
		if not genome_scene_ready:
			reasons.append("3D scene loading")
			if connection_healthy and brain_ready and genome_available:
				update_loading_status("Loading 3D scene...")
		if genome_scene_ready and not _3d_scene_instantiated:
			reasons.append("3D scene instantiating")
			update_loading_status("Initializing 3D scene...")
		if not websocket_ok:
			reasons.append("websocket not connected")
			update_loading_status("Websocket disconnected - reconnecting...")
		print("UIMANAGER: ❌ Showing loading screen - reasons: %s" % ", ".join(reasons))
		toggle_loading_screen(true)

## Called from above when we confirmed genome to feagi, enable UI elements that connect to it
func FEAGI_confirmed_genome() -> void:
	print("UIMANAGER: [3D_SCENE_DEBUG] FEAGI_confirmed_genome() called - starting 3D scene initialization")
	print("UIMANAGER: [3D_SCENE_DEBUG] Enabling FEAGI UI elements now that genome is confirmed")
	top_bar.toggle_buttons_interactability(true)
	
	print("UIMANAGER: [3D_SCENE_DEBUG] Checking if Main circuit is available...")
	print("UIMANAGER: [DEBUG] Brain regions cache state:")
	print("  - available_brain_regions count: ", FeagiCore.feagi_local_cache.brain_regions._available_brain_regions.size())
	print("  - available_brain_regions keys: ", FeagiCore.feagi_local_cache.brain_regions._available_brain_regions.keys())
	print("  - is_root_available(): ", FeagiCore.feagi_local_cache.brain_regions.is_root_available())
	print("  - ROOT_REGION_ID constant: ", FeagiCore.feagi_local_cache.brain_regions._get_configured_root_id())
	if !FeagiCore.feagi_local_cache.brain_regions.is_root_available():
		print("UIMANAGER: [3D_SCENE_DEBUG] ⚠️ Main circuit not available yet - deferring 3D scene initialization retry")
		update_loading_status("Waiting for Main circuit data...")
		if not _genome_confirm_retry_in_flight:
			_genome_confirm_retry_in_flight = true
			var retry_delay_seconds: float = 0.0
			if FeagiCore.feagi_settings != null:
				retry_delay_seconds = FeagiCore.feagi_settings.seconds_between_healthcheck_pings
			if retry_delay_seconds > 0.0:
				get_tree().create_timer(retry_delay_seconds).timeout.connect(_retry_confirmed_genome_init)
			else:
				call_deferred("_retry_confirmed_genome_init")
		return
	_genome_confirm_retry_in_flight = false
	
	print("UIMANAGER: [3D_SCENE_DEBUG] ✅ Main circuit available - proceeding with initialization")
	var root_region = FeagiCore.feagi_local_cache.brain_regions.get_root_region()
	print("UIMANAGER: [3D_SCENE_DEBUG] Main circuit details: ", root_region)
	
	var initial_tabs: Array[Control]
	print("UIMANAGER: [3D_SCENE_DEBUG] Creating Circuit Builder...")
	#TODO need a better function to add CB in general
	var cb: CircuitBuilder = PREFAB_CB.instantiate()
	initial_tabs = [cb]
	print("UIMANAGER: [3D_SCENE_DEBUG] Setting up Main circuit UI view...")
	_root_UI_view.reset()
	_root_UI_view.set_this_as_root_view()
	# CircuitBuilder must be in the scene tree before setup(): GraphEdit only wires item_rect_changed to
	# _connection_layer when that layer is in-tree at GraphElement add_child_notify time.
	_root_UI_view.setup_as_single_tab(initial_tabs)
	cb.setup(root_region)
	print("UIMANAGER: [3D_SCENE_DEBUG] ✅ Circuit Builder setup complete")
	
	# temp BM
	print("UIMANAGER: [3D_SCENE_DEBUG] Creating Brain Monitor 3D scene...")
	_temp_bm_holder = UI_Capsules_Capsule.spawn_uninitialized_UI_in_capsule(UI_Capsules_Capsule.HELD_TYPE.BRAIN_MONITOR)
	if _temp_bm_holder == null:
		print("UIMANAGER: [3D_SCENE_DEBUG] ❌ CRITICAL: Failed to create brain monitor capsule!")
		return
	
	print("UIMANAGER: [3D_SCENE_DEBUG] Adding brain monitor to scene tree...")
	$test.add_child(_temp_bm_holder)
	
	print("UIMANAGER: [3D_SCENE_DEBUG] Getting brain monitor UI component...")
	var brain_monitor: UI_BrainMonitor_3DScene = _temp_bm_holder.get_holding_UI() as UI_BrainMonitor_3DScene
	if brain_monitor == null:
		print("UIMANAGER: [3D_SCENE_DEBUG] ❌ CRITICAL: Failed to get brain monitor UI component!")
		return
	
	print("UIMANAGER: [3D_SCENE_DEBUG] Setting up brain monitor with Main circuit...")
	brain_monitor.setup(root_region, false)  # false = don't show combo buttons in main scene
	brain_monitor.requesting_to_fire_selected_neurons.connect(_send_activations_to_FEAGI)
	# NOTE: Main brain monitor does NOT connect to central handlers to avoid infinite recursion
	# Only brain region tab monitors connect to central handlers, which then forward to main monitor
	temp_root_bm = brain_monitor

	# If we restored a previous camera position (e.g., genome reload), disable the startup intro this time
	if _temp_bm_camera_pos.length() > 0.01:
		brain_monitor.enable_startup_camera_intro = false
	
	# CRITICAL: Mark 3D scene as fully instantiated BEFORE checking loading screen
	# This ensures loading screen is only hidden when 3D scene is actually visible
	print("UIMANAGER: [3D_SCENE_DEBUG] ✅ Marking _3d_scene_instantiated = true")
	_3d_scene_instantiated = true
	
	# CRITICAL: Force loading screen visibility check NOW that 3D scene is actually ready
	# This is the ONLY safe time to hide the loading screen - after all 3D elements exist
	print("UIMANAGER: [3D_SCENE_DEBUG] ✅ 3D scene fully initialized - triggering final loading screen check")
	_update_loading_screen_visibility()
	
	# CRITICAL: Create visualizations for any missing child regions (e.g., after cloning)
	# This ensures cloned regions appear immediately after genome reload
	# NOTE: Root region is explicitly excluded - only child regions get plate visualizations
	print("UIMANAGER: [3D_SCENE_DEBUG] Creating visualizations for any missing child regions...")
	print("UIMANAGER: [3D_SCENE_DEBUG] About to call _create_missing_brain_region_visualizations() on brain_monitor instance %d" % brain_monitor.get_instance_id())
	brain_monitor._create_missing_brain_region_visualizations()
	print("UIMANAGER: [3D_SCENE_DEBUG] ✅ Missing child region visualizations created")
	
	# ADDITIONAL: Also schedule a deferred update to catch any regions that might be added after this
	print("UIMANAGER: [3D_SCENE_DEBUG] Scheduling deferred region visualization update...")
	brain_monitor.call_deferred("_create_missing_brain_region_visualizations")
	print("UIMANAGER: [3D_SCENE_DEBUG] Deferred update scheduled")
	
	print("UIMANAGER: [3D_SCENE_DEBUG] Restoring camera position if available...")
	if _temp_bm_camera_pos.length() > 0.01:
		print("UIMANAGER: [3D_SCENE_DEBUG] Restoring camera position: ", _temp_bm_camera_pos, " rotation: ", _temp_bm_camera_rot)
		temp_root_bm.get_node("SubViewport/Center/PancakeCam").position = _temp_bm_camera_pos
		temp_root_bm.get_node("SubViewport/Center/PancakeCam").rotation = _temp_bm_camera_rot
		# Clear saved camera markers so next fresh init can play intro again if desired
		_temp_bm_camera_pos = Vector3(0,0,0)
		_temp_bm_camera_rot = Vector3(0,0,0)
	
	print("UIMANAGER: [3D_SCENE_DEBUG] ✅ Brain Monitor 3D scene setup complete")
	
	# This is utter cancer
	print("UIMANAGER: [3D_SCENE_DEBUG] Applying advanced mode and theme settings...")
	set_advanced_mode(FeagiCore._in_use_endpoint_details.is_advanced_mode)
	var option_string: String = FeagiCore._in_use_endpoint_details.theme_string
	print("UIMANAGER: [SCALE_TRACE] Endpoint theme_string received: '%s'" % option_string)
	if option_string == "":
		print("UIMANAGER: [3D_SCENE_DEBUG] ✅ 3D scene initialization COMPLETE - no theme to apply")
		return
	if _is_compact_effective_window():
		print("UIMANAGER: [SCALE_TRACE] Ignoring endpoint theme override on compact effective window to preserve startup matrix scale")
		print("UIMANAGER: [3D_SCENE_DEBUG] ✅ 3D scene initialization COMPLETE - compact window startup scale preserved")
		return
	_startup_scale_locked_by_endpoint = true
	var split_strings: PackedStringArray = option_string.split(" ")
	var color_setting: UIManager.THEME_COLORS
	if split_strings[0] == "Dark":
		color_setting = UIManager.THEME_COLORS.DARK
	var zoom_value: float = split_strings[1].to_float()
	print("UIMANAGER: [SCALE_TRACE] Applying endpoint theme override scale=%s color=%s" % [zoom_value, THEME_COLORS.keys()[color_setting]])
	BV.UI.request_switch_to_theme(zoom_value, color_setting)
	
	print("UIMANAGER: [3D_SCENE_DEBUG] ✅ 3D scene initialization COMPLETE with theme applied")

func _retry_confirmed_genome_init() -> void:
	_genome_confirm_retry_in_flight = false
	if FeagiCore.genome_load_state != FeagiCore.GENOME_LOAD_STATE.GENOME_READY:
		return
	FEAGI_confirmed_genome()

## Returns the main brain monitor instance - alternative getter for external access
func get_temp_root_bm() -> UI_BrainMonitor_3DScene:
	return temp_root_bm


## Rebuilds cortical visualization and DirectPoints registration on every Brain Monitor after WS/SHM transport recovery.
func resync_all_brain_monitors_after_transport_recovery() -> void:
	var done: Dictionary = {}
	for bm in _find_all_brain_monitors_in_scene_tree():
		if bm == null:
			continue
		var bm_id: int = bm.get_instance_id()
		if done.has(bm_id):
			continue
		done[bm_id] = true
		if bm.has_method("resync_visualization_after_transport_recovery"):
			bm.resync_visualization_after_transport_recovery()
	if temp_root_bm != null and is_instance_valid(temp_root_bm):
		var root_id: int = temp_root_bm.get_instance_id()
		if not done.has(root_id) and temp_root_bm.has_method("resync_visualization_after_transport_recovery"):
			temp_root_bm.resync_visualization_after_transport_recovery()

# TEMP - > for sending activation firings to FEAGI
func _send_activations_to_FEAGI(area_IDs_and_neuron_coordinates: Dictionary[StringName, Array]) -> void:
	# Sending neuron activations to FEAGI via HTTP POST
	
	# Verify we actually have neurons to fire
	if area_IDs_and_neuron_coordinates.is_empty():
		push_error("Manual stimulation: No cortical areas provided")
		return
	
	var total_neurons = 0
	for area_id in area_IDs_and_neuron_coordinates:
		var neuron_array = area_IDs_and_neuron_coordinates[area_id]
		total_neurons += neuron_array.size()
	
	if total_neurons == 0:
		push_error("Manual stimulation: No neurons selected")
		return
	
	# Check if network components are available
	if not FeagiCore or not FeagiCore.network or not FeagiCore.network.http_API:
		push_error("Manual stimulation: Network not available")
		return
	
	# Check HTTP API health
	var api_health = FeagiCore.network.http_API.http_health
	match api_health:
		FeagiCore.network.http_API.HTTP_HEALTH.NO_CONNECTION:
			push_error("Manual stimulation: FEAGI not reachable")
			return
		FeagiCore.network.http_API.HTTP_HEALTH.ERROR:
			push_error("Manual stimulation: Connection error")
			return
	
	# Build the correct payload format for manual stimulation API
	var stimulation_payload: Dictionary = {}
	for area_ID in area_IDs_and_neuron_coordinates:
		var arr: Array[Array] = []
		for vector in area_IDs_and_neuron_coordinates[area_ID]:
			arr.append([vector.x, vector.y, vector.z])
		var area_id_string: String = str(area_ID)
		stimulation_payload[area_id_string] = arr
	
	var payload_to_send: Dictionary = {"stimulation_payload": stimulation_payload}
	
	# Send via HTTP POST to /v1/agent/manual_stimulation
	var FEAGI_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_POST_call(FeagiCore.network.http_API.address_list.POST_agent_manualStimulation, payload_to_send)
	var HTTP_FEAGI_request_worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(FEAGI_request)
	
	# Add timeout mechanism
	var worker_id: int = HTTP_FEAGI_request_worker.get_instance_id()
	_manual_stim_pending_workers[worker_id] = weakref(HTTP_FEAGI_request_worker)
	get_tree().create_timer(10.0).timeout.connect(_on_manual_stimulation_timeout.bind(worker_id))
	
	await HTTP_FEAGI_request_worker.worker_done
	_manual_stim_pending_workers.erase(worker_id)
	
	var timed_out: bool = _manual_stim_timeouts.has(worker_id)
	_manual_stim_timeouts.erase(worker_id)
	if timed_out:
		return
	
	var request_output: FeagiRequestOutput = HTTP_FEAGI_request_worker.retrieve_output_and_close()
	
	if not request_output.success:
		push_error("Manual stimulation failed: %s" % request_output.failed_requirement)

## Handles manual stimulation timeouts without capturing freed instances.
func _on_manual_stimulation_timeout(worker_id: int) -> void:
	if not _manual_stim_pending_workers.has(worker_id):
		return
	_manual_stim_timeouts[worker_id] = true
	push_error("Manual stimulation: Request timed out")
	var worker_ref = _manual_stim_pending_workers[worker_id]
	if worker_ref is WeakRef:
		var worker = (worker_ref as WeakRef).get_ref()
		if worker and is_instance_valid(worker):
			(worker as APIRequestWorker).kill_worker()

# CRITICAL: Central voxel selection handlers for QuickConnect functionality
# These receive signals ONLY from brain region tab monitors and forward to main monitor
# Main monitor does NOT connect to these handlers to avoid infinite recursion

## Central handler for full neuron selection state changes (used by QuickConnect)
func _handle_voxel_selection_changed(area: AbstractCorticalArea, selected_neuron_coordinates: Array[Vector3i]) -> void:
	# Re-emit this signal through the main brain monitor so QuickConnect systems receive it
	# This is only called by brain region tab monitors, never by the main monitor
	if temp_root_bm:
		temp_root_bm.cortical_area_selected_neurons_changed.emit(area, selected_neuron_coordinates)

## Central handler for individual voxel selection changes (used by QuickConnectNeuron)
func _handle_voxel_selection_changed_delta(area: AbstractCorticalArea, neuron_coordinate: Vector3i, is_added: bool) -> void:
	# Re-emit this signal through the main brain monitor so QuickConnectNeuron receives it
	# This is only called by brain region tab monitors, never by the main monitor
	if temp_root_bm:
		temp_root_bm.cortical_area_selected_neurons_changed_delta.emit(area, neuron_coordinate, is_added)



#endregion


#region User Interactions
signal advanced_mode_setting_changed(is_in_advanced_mode: bool)


var is_in_advanced_mode: bool:
	get: return _is_in_advanced_mode

func _input(event):
	if FeagiCore.feagi_settings == null:
		return
	
	if event is InputEventKey:
		var keyboard_event: InputEventKey = event as InputEventKey
		if keyboard_event.keycode == FeagiCore.feagi_settings.developer_menu_hotkey:
			if !keyboard_event.pressed:
				return
			if !FeagiCore.feagi_settings.allow_developer_menu:
				return
			show_developer_menu()

var _is_in_advanced_mode: bool = false

func set_advanced_mode(is_advanced_mode: bool) -> void:
	if is_advanced_mode == _is_in_advanced_mode:
		return
	_is_in_advanced_mode = is_advanced_mode
	advanced_mode_setting_changed.emit(_is_in_advanced_mode)


## Open the developer menu
func show_developer_menu():
	_window_manager.spawn_developer_options()

## Show the guide overlay with markdown content.



func toggle_loading_screen(is_on: bool) -> void:
	$LoadingScreenOverlayLayer/TempLoadingScreen.visible = is_on

## Update the loading status message displayed on the loading screen
func update_loading_status(message: String) -> void:
	if _loading_status_label:
		_loading_status_label.text = message
		_loading_status_label.mouse_filter = Control.MOUSE_FILTER_STOP
		_loading_status_label.tooltip_text = _build_loading_status_tooltip()
		print("UIMANAGER: Loading status: %s" % message)

## Builds the loading status tooltip (connection + failure details).
func _build_loading_status_tooltip() -> String:
	var endpoint = FeagiCore.network._feagi_endpoint_details
	var http_addr = endpoint.full_http_address if endpoint != null else "unknown"
	var ws_addr = endpoint.full_websocket_address if endpoint != null else "unknown"
	var transport = FEAGINetworking.TRANSPORT_MODE.keys()[FeagiCore.network._transport_mode]
	var ws_retry = FeagiCore.network.websocket_API._retry_count if FeagiCore.network.websocket_API != null else 0
	var ws_retry_max = FeagiCore.feagi_settings.number_of_times_to_retry_WS_connections if FeagiCore.feagi_settings != null else 0
	var http_retrying = FeagiCore.network.http_API._retrying_workers.size() if FeagiCore.network.http_API != null else 0
	var shm_path = FeagiCore.network.websocket_API._shm_path if FeagiCore.network.websocket_API != null else ""
	var failure_summary = _build_loading_failure_summary()
	return "FEAGI HTTP: %s\nFEAGI WS: %s\nTransport: %s\nSHM path: %s\nWS retries: %d / %d\nHTTP retrying workers: %d\nFailure status: %s" % [
		http_addr,
		ws_addr,
		transport,
		shm_path if shm_path != "" else "not active",
		ws_retry,
		ws_retry_max,
		http_retrying,
		failure_summary
	]

## Returns a concise summary of why loading is blocked.
func _build_loading_failure_summary() -> String:
	var reasons: Array[String] = []
	var connection_healthy = FeagiCore.network.connection_state == FEAGINetworking.CONNECTION_STATE.HEALTHY
	var brain_ready = FeagiCore.feagi_local_cache.brain_readiness
	var genome_available = FeagiCore.feagi_local_cache.genome_availability
	var genome_scene_ready = FeagiCore.genome_load_state == FeagiCore.GENOME_LOAD_STATE.GENOME_READY
	var websocket_ok = true
	if FeagiCore.network._transport_mode == FEAGINetworking.TRANSPORT_MODE.WEBSOCKET:
		websocket_ok = FeagiCore.network.websocket_API.socket_health == FeagiCore.network.websocket_API.WEBSOCKET_HEALTH.CONNECTED
	if not connection_healthy:
		reasons.append("connection not healthy")
	if not brain_ready:
		reasons.append("brain not ready")
	if not genome_available:
		reasons.append("no genome available")
	if not genome_scene_ready:
		reasons.append("3D scene loading")
	if genome_scene_ready and not _3d_scene_instantiated:
		reasons.append("3D scene instantiating")
	if not websocket_ok:
		reasons.append("websocket not connected")
	return "ok" if reasons.is_empty() else ", ".join(reasons)

## Show the shutdown screen with custom styling
func show_shutdown_screen() -> void:
	# Change the title from "Loading..." to "Shutting down..."
	var loading_label = $LoadingScreenOverlayLayer/TempLoadingScreen/LoadingOverlay/VBoxContainer/Label
	if loading_label:
		loading_label.text = "Shutting down..."
	
	# Show the screen
	toggle_loading_screen(true)
	update_loading_status("Preparing to exit...")
	
	# Force UI to update immediately
	await get_tree().process_frame
	
	print("UIMANAGER: ✅ Shutdown screen displayed")

## Update shutdown status (forces UI refresh)
func update_shutdown_status(message: String) -> void:
	update_loading_status(message)
	# Force UI update
	await get_tree().process_frame

func _selection_processing(objects: Array[GenomeObject], context: SelectionSystem.SOURCE_CONTEXT, override_usecases: Array[SelectionSystem.OVERRIDE_USECASE]) -> void:
	var quick_connect_active: bool = SelectionSystem.OVERRIDE_USECASE.QUICK_CONNECT in override_usecases
	var quick_connect_neuron_active: bool = SelectionSystem.OVERRIDE_USECASE.QUICK_CONNECT_NEURON in override_usecases
	if !quick_connect_active and !quick_connect_neuron_active:
		if objects.is_empty():
			_window_manager.force_close_window(QuickCorticalMenu.WINDOW_NAME)
			return
		_window_manager.spawn_quick_cortical_menu(objects, context)
	if SelectionSystem.OVERRIDE_USECASE.CORTICAL_PROPERTIES in override_usecases:
		var cortical_areas: Array[AbstractCorticalArea] = GenomeObject.filter_cortical_areas(objects)
		if len(cortical_areas) != 0:
			_window_manager.spawn_adv_cortical_properties(cortical_areas)

#endregion


## Functionality related to screen size, theming, and scaling of all elements
#region Theming and Scaling
const THEME_FOLDER: StringName = "res://BrainVisualizer/UI/Themes/"

enum THEME_COLORS { # SO MANY COLORS
	DARK
}

signal screen_size_changed(new_screen_size: Vector2)
signal theme_changed(theme: Theme) ## New theme (likely with vustom scale changes) applied

var screen_size: Vector2:  # keep as float for easy division
	get: return _screen_size
var screen_center: Vector2:
	get: return _screen_size / 2.0
var loaded_theme: Theme:
	get: return _loaded_theme
var possible_UI_scales: Array[float]:
	get: return _possible_UI_scales
var loaded_theme_scale: Vector2:
	get: return _loaded_theme_scale

var _screen_size: Vector2
var _loaded_theme: Theme
var _loaded_theme_scale: Vector2 = Vector2(1.0, 1.0)
var _possible_UI_scales: Array[float] = []

# Split handle textures (generated at runtime to avoid SVG import sizing quirks)
var _split_handle_v: Texture2D = null ## @cursor:critical-path - UI affordance must be deterministic across platforms
var _split_handle_h: Texture2D = null ## @cursor:critical-path - UI affordance must be deterministic across platforms


## Ensures splitter handle textures exist. We generate these at runtime to guarantee pixel size
## (SVG import settings can clamp the rendered size and make the handle appear tiny).
func _ensure_split_handle_textures() -> void:
	# Always regenerate so edits to sizes/colors apply deterministically after restart/theme reload.
	# (These textures were previously cached and could make changes appear to have no effect.)
	#
	# "Option A + B":
	# - Make the handle visually thicker (bigger bump)
	# - Keep it elegant with longer "|| / ==" marks
	# Make marks 3x longer:
	# - Vertical: increase texture height (length), keep width (thickness)
	# - Horizontal: increase texture width (length), keep height (thickness)
	_split_handle_v = _make_split_handle_texture(Vector2i(20, 216), true)  # thickness 20px, 3x length
	_split_handle_h = _make_split_handle_texture(Vector2i(216, 20), false) # thickness 20px, 3x length


## Generates an "||" (or "==") split handle icon of a known pixel size.
static func _make_split_handle_texture(size_px: Vector2i, is_vertical: bool) -> Texture2D:
	var img: Image = Image.create(size_px.x, size_px.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Brighter neutral gray so it reads on dark backgrounds.
	# Slightly dimmed (per UX feedback) while remaining discoverable.
	var bar_color: Color = Color(0.88, 0.9, 0.93, 0.92)
	if is_vertical:
		# Two vertical bars centered in a fixed-width texture.
		var bar_w: int = maxi(2, int(size_px.x * 0.16))
		var gap: int = maxi(2, int(size_px.x * 0.12))
		var bar_h: int = maxi(14, int(size_px.y * 0.72)) # longer mark (Option B)
		var y0: int = (size_px.y - bar_h) / 2
		var x0: int = (size_px.x - (bar_w * 2 + gap)) / 2
		img.fill_rect(Rect2i(x0, y0, bar_w, bar_h), bar_color)
		img.fill_rect(Rect2i(x0 + bar_w + gap, y0, bar_w, bar_h), bar_color)
	else:
		# Two horizontal bars centered in a fixed-height texture.
		var bar_h2: int = maxi(2, int(size_px.y * 0.16))
		var gap2: int = maxi(2, int(size_px.y * 0.12))
		var bar_w2: int = maxi(14, int(size_px.x * 0.72)) # longer mark (Option B)
		var x02: int = (size_px.x - bar_w2) / 2
		var y02: int = (size_px.y - (bar_h2 * 2 + gap2)) / 2
		img.fill_rect(Rect2i(x02, y02, bar_w2, bar_h2), bar_color)
		img.fill_rect(Rect2i(x02, y02 + bar_h2 + gap2, bar_w2, bar_h2), bar_color)
	return ImageTexture.create_from_image(img)


## Given the element node, uses the theme_variant property to retrieve the minimum size of the current theme. If there is no theme variant, fall back onto the given default option
func get_minimum_size_from_loaded_theme_variant_given_control(control: Control, fallback_type: StringName) -> Vector2i:
	if control.theme_type_variation != &"":
		fallback_type = control.theme_type_variation
	return get_minimum_size_from_loaded_theme(fallback_type)

## Given the name of the element, try to grab the minimum size defined by the currently loaded theme. If element doesnt exist, return 32x32
func get_minimum_size_from_loaded_theme(element: StringName) -> Vector2i:
	var output: Vector2i = Vector2i(32,32)
	
	if loaded_theme == null:
		push_error("THEME: Theme has not been loaded correctly, a LOT of UI elements will be broken!")
		return output
	
	if loaded_theme.has_constant("size_x", element):
		output.x = loaded_theme.get_constant("size_x", element)
	else:
		push_error("THEME: Loaded theme file is missing size_x for element %s. There will be sizing issues!" % element)
	if BV.UI.loaded_theme.has_constant("size_y", element):
		output.y = loaded_theme.get_constant("size_y", element)
	else:
		push_error("THEME: Loaded theme file is missing size_y for element %s. There will be sizing issues!" % element)
	return output

## Attempts to switch toa  theme file with the given scale and color. If it doesnt exist, will do nothing
func request_switch_to_theme(requested_scale: float, color: THEME_COLORS) -> void:
	var stack_info: Array = get_stack()
	var caller_info: Variant = "<unknown>"
	if stack_info.size() > 1:
		var frame: Variant = stack_info[1]
		if frame is Dictionary and frame.has("function"):
			caller_info = "%s (%s:%s)" % [
				str(frame.get("function", "<fn>")),
				str(frame.get("source", "<source>")),
				str(frame.get("line", "?"))
			]
	print("UIMANAGER: [SCALE_TRACE] request_switch_to_theme called: requested_scale=%s color=%s caller=%s current_loaded_scale=%s" % [requested_scale, THEME_COLORS.keys()[color], caller_info, _loaded_theme_scale.x])

	var file_list: PackedStringArray = DirAccess.get_files_at(THEME_FOLDER)
	var color_suffix: StringName = "-" + THEME_COLORS.keys()[color] + ".tres"
	var guessing_file: StringName = ""
	for file: StringName in file_list:
		if !file.ends_with(color_suffix):
			continue
		var base: StringName = file.get_slice("-", 0)
		if base.is_valid_float() and abs(base.to_float() - requested_scale) < 0.0001:
			guessing_file = file
			break
	if guessing_file == "":
		push_error("THEME: Unable to find theme file matching scale %s and color %s!" % [requested_scale, THEME_COLORS.keys()[color]])
		return
	var theme_file: Theme = load(THEME_FOLDER + guessing_file)
	if theme_file == null:
		push_error("THEME:  Found theme file %s but unable to parse file as a theme!" % guessing_file)
		return
	print("THEME: Loading theme %s..." % guessing_file)
	_load_new_theme(theme_file)


## Updates the screensize 
func _update_screen_size():
	_screen_size = get_viewport().get_visible_rect().size
	screen_size_changed.emit(screen_size)

## Used to reposition notifications so they dont intersect with top bar
func _top_bar_resized() -> void:
	_notification_system.position.y = _top_bar.size.y + _top_bar.position.y
	if has_node("/root/BrainVisualizer/UIManager/CB_Holder"):
		$CB_Holder.offset_top = _top_bar.position.y + _top_bar.size.y + 8

func _load_new_theme(theme: Theme) -> void:
	var scalar: Vector2 = Vector2(1,1)
	
	_loaded_theme = theme
	# Ensure split handles are a consistent, visible size across all platforms/themes.
	_ensure_split_handle_textures()
	_loaded_theme.set_icon("h_grabber", "SplitContainer", _split_handle_v)
	_loaded_theme.set_icon("v_grabber", "SplitContainer", _split_handle_h)
	_loaded_theme.set_icon("h_touch_dragger", "SplitContainer", _split_handle_v)
	_loaded_theme.set_icon("v_touch_dragger", "SplitContainer", _split_handle_h)
	_loaded_theme.set_icon("grabber", "HSplitContainer", _split_handle_v)
	_loaded_theme.set_icon("grabber", "VSplitContainer", _split_handle_h)
	_loaded_theme.set_icon("touch_dragger", "HSplitContainer", _split_handle_v)
	_loaded_theme.set_icon("touch_dragger", "VSplitContainer", _split_handle_h)
	# Use a thicker standard split bar (full-height/width band) so the affordance is obvious.
	# This is more reliable than touch_dragger sizing, which can still read like a small nub.
	_loaded_theme.set_constant("separation", "SplitContainer", 20)
	_loaded_theme.set_constant("separation", "HSplitContainer", 20)
	_loaded_theme.set_constant("separation", "VSplitContainer", 20)
	_loaded_theme.set_constant("autohide", "SplitContainer", 0)
	# Make the drag handle background brighter (still neutral gray) so it is discoverable.
	_loaded_theme.set_color("touch_dragger_color", "SplitContainer", Color(0.92, 0.94, 0.97, 0.72))
	_loaded_theme.set_color("touch_dragger_hover_color", "SplitContainer", Color(0.96, 0.97, 0.99, 0.84))
	_loaded_theme.set_color("touch_dragger_pressed_color", "SplitContainer", Color(1.0, 1.0, 1.0, 0.94))
	if _loaded_theme.has_constant("size_x", "generic_scale"):
		scalar.x = float(_loaded_theme.get_constant("size_x", "generic_scale")) / 4.0
	else:
		push_error("UI: Unable to find size_x under the generic_scale type of the newely loaded theme! There will be scaling issues!")
	if _loaded_theme.has_constant("size_y", "generic_scale"):
		scalar.y = float(_loaded_theme.get_constant("size_y", "generic_scale")) / 4.0
	else:
		push_error("UI: Unable to find size_y under the generic_scale type of the newely loaded theme! There will be scaling issues!")
	
	_loaded_theme_scale = scalar
	print("UIMANAGER: [SCALE_TRACE] Theme loaded, resulting UI scale=%s" % _loaded_theme_scale.x)

	# IMPORTANT: Ensure the theme is actually applied to the active UI Control tree.
	# Many BV widgets opt-in to theme_changed and set their own theme, but core containers
	# like SplitContainer will continue using the project default theme unless we set it here.
	#
	# This is the key reason prior "make it bigger" changes appeared to have no effect.
	if has_node("/root/BrainVisualizer/UIManager/CB_Holder"):
		$CB_Holder.theme = _loaded_theme
		# Ensure nested UIView inherits the theme even if reparented later.
		if $CB_Holder.has_node("UIView"):
			$CB_Holder/UIView.theme = _loaded_theme
	if has_node("/root/BrainVisualizer/UIManager/TopBar"):
		$TopBar.theme = _loaded_theme
	if has_node("/root/BrainVisualizer/UIManager/NotificationSystem"):
		$NotificationSystem.theme = _loaded_theme
	if has_node("/root/BrainVisualizer/UIManager/LoadingScreenOverlayLayer/TempLoadingScreen"):
		$LoadingScreenOverlayLayer/TempLoadingScreen.theme = _loaded_theme
	if has_node("/root/BrainVisualizer/UIManager/ScaleControl"):
		$ScaleControl.theme = _loaded_theme

	$VersionLabel.theme = theme
	theme_changed.emit(theme)


func _find_possible_scales() -> void:
	_possible_UI_scales.clear()
	var file_list: PackedStringArray = DirAccess.get_files_at(THEME_FOLDER)
	for file: StringName in file_list:
		var first_part: StringName = file.get_slice("-", 0)
		if first_part.is_valid_float():
			_possible_UI_scales.append(first_part.to_float())
	_possible_UI_scales.sort()

## Chooses startup UI scale using monitor DPI and resolution only.
func _select_startup_scale_from_display_metrics() -> float:
	var window: Window = get_window()
	var current_screen: int = _resolve_screen_for_window(window)
	var screen_size: Vector2i = DisplayServer.screen_get_size(current_screen)
	var dpi: int = DisplayServer.screen_get_dpi(current_screen)
	var window_size: Vector2i = window.size
	var effective_sizes: Dictionary = _compute_effective_sizes(current_screen, screen_size, window_size, dpi)
	var effective_screen_size: Vector2i = effective_sizes.get("effective_screen_size", screen_size)
	var effective_window_size: Vector2i = effective_sizes.get("effective_window_size", window_size)
	var screen_scale: float = effective_sizes.get("engine_scale", 1.0)
	var content_scale_factor: float = effective_sizes.get("content_scale_factor", 1.0)
	var inferred_scale: float = effective_sizes.get("inferred_scale", 1.0)
	var normalization_scale: float = effective_sizes.get("normalization_scale", 1.0)
	var fullscreen_hidpi_fallback_used: bool = effective_sizes.get("fullscreen_hidpi_fallback_used", false)
	var dpi_tier: int = _classify_startup_dpi_tier(dpi)
	var viewport_rect_size: Vector2 = get_viewport().get_visible_rect().size
	var raw_viewport_size: Vector2i = Vector2i(
		maxi(1, roundi(viewport_rect_size.x)),
		maxi(1, roundi(viewport_rect_size.y))
	)
	var resolution_input_size: Vector2i = Vector2i(
		maxi(1, roundi(float(raw_viewport_size.x) / normalization_scale)),
		maxi(1, roundi(float(raw_viewport_size.y) / normalization_scale))
	)
	var resolution_tier: int = _classify_startup_resolution_tier(resolution_input_size)
	var selected_scale: float = _select_scale_from_startup_matrix(dpi_tier, resolution_tier)
	
	print("UIMANAGER: Startup display metrics -> screen=%d raw_size=%s effective_size=%s dpi=%d dpi_tier=%s engine_scale=%s content_scale_factor=%s inferred_scale=%s normalization_scale=%s fullscreen_hidpi_fallback_used=%s raw_window_size=%s effective_window_size=%s raw_viewport_size=%s resolution_input_size=%s resolution_tier=%s selected_scale=%s window_pos=%s" % [
		current_screen,
		screen_size,
		effective_screen_size,
		dpi,
		STARTUP_DPI_TIER.keys()[dpi_tier],
		screen_scale,
		content_scale_factor,
		inferred_scale,
		normalization_scale,
		fullscreen_hidpi_fallback_used,
		window_size,
		effective_window_size,
		raw_viewport_size,
		resolution_input_size,
		STARTUP_RES_TIER.keys()[resolution_tier],
		selected_scale,
		window.position
	])
	return selected_scale

## Classifies display DPI into startup scale tiers.
func _classify_startup_dpi_tier(dpi: int) -> int:
	if dpi >= UI_STARTUP_DPI_XLARGE:
		return STARTUP_DPI_TIER.DPI_XLARGE
	if dpi >= UI_STARTUP_DPI_LARGE:
		return STARTUP_DPI_TIER.DPI_LARGE
	if dpi >= UI_STARTUP_DPI_MEDIUM:
		return STARTUP_DPI_TIER.DPI_MEDIUM
	return STARTUP_DPI_TIER.DPI_STANDARD

## Classifies effective window resolution into startup scale tiers.
func _classify_startup_resolution_tier(effective_window_size: Vector2i) -> int:
	var long_side: int = maxi(effective_window_size.x, effective_window_size.y)
	var short_side: int = mini(effective_window_size.x, effective_window_size.y)
	if long_side <= UI_STARTUP_LONG_SIDE_COMPACT and short_side <= UI_STARTUP_SHORT_SIDE_COMPACT:
		return STARTUP_RES_TIER.RES_COMPACT
	if long_side <= UI_STARTUP_LONG_SIDE_STANDARD:
		return STARTUP_RES_TIER.RES_STANDARD
	if long_side <= UI_STARTUP_LONG_SIDE_LARGE:
		return STARTUP_RES_TIER.RES_LARGE
	return STARTUP_RES_TIER.RES_XLARGE

## Explicit startup zoom matrix by (DPI tier x effective resolution tier).
## Rows are DPI tiers; columns are resolution tiers:
## - DPI_STANDARD: COMPACT=0.75, STANDARD=1.0, LARGE=1.25, XLARGE=1.5
## - DPI_MEDIUM:   COMPACT=0.75, STANDARD=1.0, LARGE=1.25, XLARGE=1.5
## - DPI_LARGE:    COMPACT=1.0,  STANDARD=1.25, LARGE=1.5,  XLARGE=2.0
## - DPI_XLARGE:   COMPACT=1.25, STANDARD=1.5, LARGE=2.0,   XLARGE=2.0
func _select_scale_from_startup_matrix(dpi_tier: int, resolution_tier: int) -> float:
	match dpi_tier:
		STARTUP_DPI_TIER.DPI_STANDARD:
			match resolution_tier:
				STARTUP_RES_TIER.RES_COMPACT: return UI_SCALE_SMALL
				STARTUP_RES_TIER.RES_STANDARD: return UI_SCALE_STANDARD
				STARTUP_RES_TIER.RES_LARGE: return UI_SCALE_MEDIUM
				_: return UI_SCALE_LARGE
		STARTUP_DPI_TIER.DPI_MEDIUM:
			match resolution_tier:
				STARTUP_RES_TIER.RES_COMPACT: return UI_SCALE_SMALL
				STARTUP_RES_TIER.RES_STANDARD: return UI_SCALE_STANDARD
				STARTUP_RES_TIER.RES_LARGE: return UI_SCALE_MEDIUM
				_: return UI_SCALE_LARGE
		STARTUP_DPI_TIER.DPI_LARGE:
			match resolution_tier:
				STARTUP_RES_TIER.RES_COMPACT: return UI_SCALE_STANDARD
				STARTUP_RES_TIER.RES_STANDARD: return UI_SCALE_MEDIUM
				STARTUP_RES_TIER.RES_LARGE: return UI_SCALE_LARGE
				_: return UI_SCALE_XLARGE
		_:
			match resolution_tier:
				STARTUP_RES_TIER.RES_COMPACT: return UI_SCALE_MEDIUM
				STARTUP_RES_TIER.RES_STANDARD: return UI_SCALE_LARGE
				_: return UI_SCALE_XLARGE

## Resolves the display index using window geometry, which is more reliable than current_screen
## during multi-monitor startup restores.
func _resolve_screen_for_window(window: Window) -> int:
	var fallback_screen: int = window.current_screen
	var screen_count: int = DisplayServer.get_screen_count()
	if screen_count <= 1:
		return fallback_screen
	var window_center: Vector2i = window.position + (window.size / 2)
	for i in range(screen_count):
		var usable_rect: Rect2i = DisplayServer.screen_get_usable_rect(i)
		if usable_rect.has_point(window_center):
			return i
	return fallback_screen

## Computes effective (logical) sizes from raw display metrics.
## Uses usable rect when available and infers pixel ratio to normalize window size.
func _compute_effective_sizes(current_screen: int, raw_screen_size: Vector2i, raw_window_size: Vector2i, dpi: int) -> Dictionary:
	var usable_rect: Rect2i = DisplayServer.screen_get_usable_rect(current_screen)
	var window: Window = get_window()
	var engine_scale: float = DisplayServer.screen_get_scale(current_screen)
	if engine_scale <= 0.0:
		engine_scale = 1.0
	var content_scale_factor: float = window.content_scale_factor
	if content_scale_factor <= 0.0:
		content_scale_factor = 1.0
	var inferred_scale_x: float = float(raw_screen_size.x) / maxf(1.0, float(usable_rect.size.x))
	var inferred_scale_y: float = float(raw_screen_size.y) / maxf(1.0, float(usable_rect.size.y))
	var inferred_scale: float = maxf(1.0, maxf(inferred_scale_x, inferred_scale_y))
	var normalization_scale: float = maxf(content_scale_factor, maxf(engine_scale, inferred_scale))
	var fullscreen_hidpi_fallback_used: bool = false
	var fullscreen_like: bool = window.mode != Window.MODE_WINDOWED
	var long_side_raw: int = maxi(raw_screen_size.x, raw_screen_size.y)
	var looks_like_backing_pixels: bool = (
		fullscreen_like
		and engine_scale <= 1.0001
		and content_scale_factor <= 1.0001
		and inferred_scale < 1.2
		and dpi <= UI_STARTUP_DPI_STANDARD
		and long_side_raw >= 3000
	)
	if looks_like_backing_pixels:
		normalization_scale = maxf(normalization_scale, UI_STARTUP_FULLSCREEN_HIDPI_FALLBACK_SCALE)
		fullscreen_hidpi_fallback_used = true
	var effective_screen_size: Vector2i = raw_screen_size
	if usable_rect.size.x > 0 and usable_rect.size.y > 0:
		effective_screen_size = Vector2i(
			roundi(float(usable_rect.size.x) / normalization_scale),
			roundi(float(usable_rect.size.y) / normalization_scale)
		)
	else:
		effective_screen_size = Vector2i(
			roundi(float(raw_screen_size.x) / normalization_scale),
			roundi(float(raw_screen_size.y) / normalization_scale)
		)
	var effective_window_size: Vector2i = Vector2i(
		roundi(float(raw_window_size.x) / normalization_scale),
		roundi(float(raw_window_size.y) / normalization_scale)
	)
	return {
		"effective_screen_size": effective_screen_size,
		"effective_window_size": effective_window_size,
		"engine_scale": engine_scale,
		"content_scale_factor": content_scale_factor,
		"inferred_scale": inferred_scale,
		"normalization_scale": normalization_scale,
		"fullscreen_hidpi_fallback_used": fullscreen_hidpi_fallback_used
	}

## Returns true when the current effective (HiDPI-normalized) window size is compact.
func _is_compact_effective_window() -> bool:
	var window: Window = get_window()
	var current_screen: int = _resolve_screen_for_window(window)
	var screen_size: Vector2i = DisplayServer.screen_get_size(current_screen)
	var dpi: int = DisplayServer.screen_get_dpi(current_screen)
	var effective_sizes: Dictionary = _compute_effective_sizes(current_screen, screen_size, window.size, dpi)
	var normalization_scale: float = effective_sizes.get("normalization_scale", 1.0)
	var viewport_rect_size: Vector2 = get_viewport().get_visible_rect().size
	var raw_viewport_size: Vector2i = Vector2i(
		maxi(1, roundi(viewport_rect_size.x)),
		maxi(1, roundi(viewport_rect_size.y))
	)
	var resolution_input_size: Vector2i = Vector2i(
		maxi(1, roundi(float(raw_viewport_size.x) / normalization_scale)),
		maxi(1, roundi(float(raw_viewport_size.y) / normalization_scale))
	)
	return _classify_startup_resolution_tier(resolution_input_size) == STARTUP_RES_TIER.RES_COMPACT

#endregion


## To prevent spam, some signals are first validated to ensure they aren't being spammed
#region Notification Filtering Proxies

## Signal proxy for notifications, adds check to ensure genome is loaded (to avoid call spam when loading genome)
func _proxy_notification_cortical_area_added(cortical_area: AbstractCorticalArea) -> void:
	if FeagiCore.genome_load_state != FeagiCore.GENOME_LOAD_STATE.GENOME_READY:
		return
	_notification_system.add_notification("Confirmed addition of cortical area %s!" % cortical_area.friendly_name)
	
	
## Signal proxy for notifications, adds check to ensure genome is loaded (to avoid call spam when loading genome)
## Also refreshes visualization when properties are updated
func _proxy_notification_cortical_area_updated(cortical_area: AbstractCorticalArea) -> void:
	if FeagiCore.genome_load_state != FeagiCore.GENOME_LOAD_STATE.GENOME_READY:
		return
	if FeagiCore.feagi_local_cache.cortical_areas.suppress_update_notifications:
		return
	
	# print("UI: Cortical area %s properties updated - refreshing visualization" % cortical_area.cortical_ID)
	# print("  🔍 Current dimensions: %s" % cortical_area.dimensions_3D)
	# print("  🔍 Current coordinates: %s" % cortical_area.coordinates_3D)
	# print("  🔍 Current visibility (cortical_visibility): %s" % cortical_area.cortical_visibility)
	# print("  🔍 Cortical type: %s" % cortical_area.cortical_type)
	# print("  🔍 Voxel granularity: %s" % cortical_area.visualization_voxel_granularity)
	
	# CRITICAL FIX (similar to clone coordinate fix): Force-trigger dimension update signal
	# to refresh renderer even if dimensions haven't changed. This ensures visualization
	# stays in sync after property updates (e.g., firing threshold changes).
	# The renderer is connected to dimensions_3D_updated signal and will refresh all visuals.
	# print("  🔧 Emitting dimensions_3D_updated signal with dims: %s" % cortical_area.dimensions_3D)
	var current_dims = cortical_area.dimensions_3D
	cortical_area.dimensions_3D_updated.emit(current_dims)
	
	# Also refresh granularity-specific visuals
	# print("  🔧 Calling BV_refresh_directpoints_renderer_visuals()")
	cortical_area.BV_refresh_directpoints_renderer_visuals()
	# print("  ✅ Visualization refresh complete for %s" % cortical_area.cortical_ID)
	
	# Show notification
	_notification_system.add_notification("Confirmed update of cortical area %s!" % cortical_area.friendly_name)
	
	
## Signal proxy for notifications, adds check to ensure genome is loaded (to avoid call spam when loading genome)
func _proxy_notification_cortical_area_removed(cortical_area: AbstractCorticalArea) -> void:
	if FeagiCore.genome_load_state != FeagiCore.GENOME_LOAD_STATE.GENOME_READY:
		return
	_notification_system.add_notification("Confirmed removal of cortical area %s!" % cortical_area.friendly_name)
	
## Signal proxy for notifications, adds check to ensure genome is loaded (to avoid call spam when loading genome)
func _proxy_notification_mappings_updated(source: AbstractCorticalArea, destination: AbstractCorticalArea) -> void:
	if FeagiCore.genome_load_state != FeagiCore.GENOME_LOAD_STATE.GENOME_READY:
		return
	_notification_system.add_notification("Confirmed updated mapping information from %s to %s!" % [source.friendly_name, destination.friendly_name])


## Signal proxy for notifications, adds check to ensure genome is loaded (to avoid call spam when loading genome)
func _proxy_notification_morphology_added(morphology: BaseMorphology) -> void:
	if FeagiCore.genome_load_state != FeagiCore.GENOME_LOAD_STATE.GENOME_READY:
		return
	_notification_system.add_notification("Confirmed addition of connectivity rule %s!" % morphology.name)


## Signal proxy for notifications, adds check to ensure genome is loaded (to avoid call spam when loading genome)
func _proxy_notification_morphology_updated(morphology: BaseMorphology) -> void:
	if FeagiCore.genome_load_state != FeagiCore.GENOME_LOAD_STATE.GENOME_READY:
		return
	_notification_system.add_notification("Confirmed update of connectivity rule %s!" % morphology.name)


## Signal proxy for notifications, adds check to ensure genome is loaded (to avoid call spam when loading genome)
func _proxy_notification_morphology_removed(morphology: BaseMorphology) -> void:
	if FeagiCore.genome_load_state != FeagiCore.GENOME_LOAD_STATE.GENOME_READY:
		return
	_notification_system.add_notification("Confirmed removal of connectivity rule %s!" % morphology.name)

#endregion

#region Icons for cortical areas

const ICON_CUSTOM_INPUT: StringName = "res://BrainVisualizer/UI/GenericResources/CorticalAreaIcons/unknowns/custom-input.png"
const ICON_CUSTOM_OUTPUT: StringName = "res://BrainVisualizer/UI/GenericResources/CorticalAreaIcons/unknowns/custom-output.png"

const KNOWN_ICON_PATHS : Dictionary = {
	"ishock" : "res://BrainVisualizer/UI/GenericResources/CorticalAreaIcons/knowns/ishk.png",
	"iv00_C" : "res://BrainVisualizer/UI/GenericResources/CorticalAreaIcons/knowns/iimg.png",
	"i_hear" : "res://BrainVisualizer/UI/GenericResources/CorticalAreaIcons/knowns/i_hear.png",
	"i_spos" : "res://BrainVisualizer/UI/GenericResources/CorticalAreaIcons/knowns/isvp00.png",
	"i__acc" : "res://BrainVisualizer/UI/GenericResources/CorticalAreaIcons/knowns/i__acc.png",
	"i__bat" : "res://BrainVisualizer/UI/GenericResources/CorticalAreaIcons/knowns/ibat.png",
	"i__bci" : "res://BrainVisualizer/UI/GenericResources/CorticalAreaIcons/knowns/i__bci.png",
	"i__gyr" : "res://BrainVisualizer/UI/GenericResources/CorticalAreaIcons/knowns/i__gyr.png",
	"i__inf" : "res://BrainVisualizer/UI/GenericResources/CorticalAreaIcons/knowns/iinf.png",
	"i__pro" : "res://BrainVisualizer/UI/GenericResources/CorticalAreaIcons/knowns/ipro.png",
	"i___id" : "res://BrainVisualizer/UI/GenericResources/CorticalAreaIcons/knowns/i___id.png",
	"o__mot" : "res://BrainVisualizer/UI/GenericResources/CorticalAreaIcons/knowns/omot.png",
	"___pwr" : "res://BrainVisualizer/UI/GenericResources/CorticalAreaIcons/knowns/_power.png",
}

## Gets the icon texture given the cortical ID
static func get_icon_texture_by_ID(cortical_ID: StringName, fallback_is_input: bool = true) -> Texture:
	# First try dynamic lookup in knowns/<ID>.png as per asset naming convention
	var knowns_base: String = "res://BrainVisualizer/UI/GenericResources/CorticalAreaIcons/knowns/"
	var candidate_path: String = knowns_base + String(cortical_ID) + ".png"
	if ResourceLoader.exists(candidate_path):
		return (load(candidate_path) as Texture)
	# Fallback to curated mapping table (legacy)
	if cortical_ID in KNOWN_ICON_PATHS:
		return (load(KNOWN_ICON_PATHS[cortical_ID]) as Texture)
	# Final fallback to placeholders in unknowns/
	if fallback_is_input:
		return  (load(ICON_CUSTOM_INPUT) as Texture)
	else:
		return  (load(ICON_CUSTOM_OUTPUT) as Texture)

## Gets the currently active brain monitor (either main or currently focused tab)
func get_active_brain_monitor() -> UI_BrainMonitor_3DScene:
	# First try to find the currently active tab brain monitor
	var active_tab_bm = _find_active_tab_brain_monitor()
	if active_tab_bm != null:
		return active_tab_bm
	
	# Fall back to main brain monitor if no tab is active
	return temp_root_bm

## Find the brain monitor that should display this cortical area using EXACT same logic as _add_cortical_area()
func get_brain_monitor_for_cortical_area(cortical_area: AbstractCorticalArea) -> UI_BrainMonitor_3DScene:
	if cortical_area == null:
		return get_active_brain_monitor()

	# Prefer the brain monitor that directly contains this cortical area (its direct parent region)
	var direct_parent_bm := _find_brain_monitor_for_area_direct_parent(cortical_area)
	if direct_parent_bm != null:
		return direct_parent_bm

	# Fallback: Use the broader acceptance logic (may include root monitor)
	var target_brain_monitor = _find_brain_monitor_using_add_cortical_area_logic(cortical_area)
	if target_brain_monitor != null:
		return target_brain_monitor
	
	# Fallback to active brain monitor
	return get_active_brain_monitor()

## Find brain monitor using the exact same logic as UI_BrainMonitor_3DScene._add_cortical_area()
func _find_brain_monitor_using_add_cortical_area_logic(cortical_area: AbstractCorticalArea) -> UI_BrainMonitor_3DScene:
	# Check main brain monitor first (root region)
	if temp_root_bm != null and _would_brain_monitor_accept_cortical_area(temp_root_bm, cortical_area):
		return temp_root_bm
	
	# Search all brain monitors in the scene tree
	var all_brain_monitors = _find_all_brain_monitors_in_scene_tree()
	for bm in all_brain_monitors:
		if _would_brain_monitor_accept_cortical_area(bm, cortical_area):
			return bm
	
	return null

## Returns all visible brain monitors in the scene tree
func get_all_visible_brain_monitors() -> Array[UI_BrainMonitor_3DScene]:
	var all_bms: Array[UI_BrainMonitor_3DScene] = _find_all_brain_monitors_in_scene_tree()
	var visible_bms: Array[UI_BrainMonitor_3DScene] = []
	for bm in all_bms:
		if bm != null and bm.is_visible_in_tree():
			visible_bms.append(bm)
	return visible_bms

## Finds a brain monitor whose representing region directly contains the cortical area
func _find_brain_monitor_for_area_direct_parent(cortical_area: AbstractCorticalArea) -> UI_BrainMonitor_3DScene:
	if cortical_area == null:
		return null
	# Search all visible brain monitors first, prefer a more specific region over root
	var candidates: Array[UI_BrainMonitor_3DScene] = get_all_visible_brain_monitors()
	for bm in candidates:
		var rep = bm._representing_region
		if rep != null and rep.is_cortical_area_in_region_directly(cortical_area):
			return bm
	return null

## Returns the brain monitor that represents the given region (visible preferred)
func get_brain_monitor_for_region(region: BrainRegion) -> UI_BrainMonitor_3DScene:
	if region == null:
		return null
	var all_bms: Array[UI_BrainMonitor_3DScene] = _find_all_brain_monitors_in_scene_tree()
	var region_id_str: String = str(region.region_ID)
	var fallback: UI_BrainMonitor_3DScene = null
	for bm in all_bms:
		if bm == null or bm._representing_region == null:
			continue
		if str(bm._representing_region.region_ID) == region_id_str:
			if bm.is_visible_in_tree():
				return bm
			fallback = bm
	return fallback

## Checks whether the given cortical area is considered I/O of the region
func is_area_io_of_region(area: AbstractCorticalArea, region: BrainRegion) -> bool:
	if area == null or region == null:
		return false
	for partial_mapping in region.partial_mappings:
		if partial_mapping.internal_target_cortical_area == area:
			return true
	return false

## Find ALL brain monitors in the entire scene tree (comprehensive search)
func _find_all_brain_monitors_in_scene_tree() -> Array[UI_BrainMonitor_3DScene]:
	var all_brain_monitors: Array[UI_BrainMonitor_3DScene] = []
	var seen: Dictionary = {}
	var scene_tree = get_tree()
	if scene_tree == null:
		return all_brain_monitors
	# Main scene subtree (typical export / editor run)
	if scene_tree.current_scene != null:
		_recursive_find_brain_monitors(scene_tree.current_scene, all_brain_monitors, seen)
	# Explicit BrainVisualizer node (autoload siblings / non-current_scene layouts)
	var bv_root: Node = scene_tree.root.get_node_or_null("BrainVisualizer")
	if bv_root != null:
		_recursive_find_brain_monitors(bv_root, all_brain_monitors, seen)
	return all_brain_monitors

func _recursive_find_brain_monitors(node: Node, brain_monitors: Array[UI_BrainMonitor_3DScene], seen: Dictionary) -> void:
	if node is UI_BrainMonitor_3DScene:
		var bm: UI_BrainMonitor_3DScene = node as UI_BrainMonitor_3DScene
		var iid: int = bm.get_instance_id()
		if seen.has(iid):
			return
		seen[iid] = true
		brain_monitors.append(bm)
	for child in node.get_children():
		_recursive_find_brain_monitors(child, brain_monitors, seen)

## Check if a brain monitor would accept this cortical area using the same logic as _add_cortical_area()
func _would_brain_monitor_accept_cortical_area(brain_monitor: UI_BrainMonitor_3DScene, cortical_area: AbstractCorticalArea) -> bool:
	if brain_monitor == null or cortical_area == null:
		return false
	
	var representing_region = brain_monitor._representing_region
	if representing_region == null:
		return false
	
	# Use the EXACT same logic as UI_BrainMonitor_3DScene._add_cortical_area()
	var is_directly_in_region = representing_region.is_cortical_area_in_region_directly(cortical_area)
	var is_io_of_child_region = _is_area_input_output_of_child_region_for_brain_monitor(brain_monitor, cortical_area)
	
	# Same condition as _add_cortical_area(): accept if directly in region OR I/O of child region
	return is_directly_in_region or is_io_of_child_region

## Helper to check if area is I/O of child region (EXACT same logic as brain monitor)
func _is_area_input_output_of_child_region_for_brain_monitor(brain_monitor: UI_BrainMonitor_3DScene, cortical_area: AbstractCorticalArea) -> bool:
	var representing_region = brain_monitor._representing_region
	if representing_region == null:
		return false
	
	# Use EXACT same logic as UI_BrainMonitor_3DScene._is_area_input_output_of_child_region()
	for child_region: BrainRegion in representing_region.contained_regions:
		if _is_area_input_output_of_specific_child_region_for_brain_monitor(cortical_area, child_region):
			return true
	
	return false

## EXACT copy of UI_BrainMonitor_3DScene._is_area_input_output_of_specific_child_region()
func _is_area_input_output_of_specific_child_region_for_brain_monitor(area: AbstractCorticalArea, child_region: BrainRegion) -> bool:
	# Method 1: Check connection chain links first
	for link: ConnectionChainLink in child_region.input_open_chain_links:
		if link.destination == area:
			return true
	
	for link: ConnectionChainLink in child_region.output_open_chain_links:
		if link.source == area:
			return true
	
	# Method 2: Check partial mappings (from FEAGI direct inputs/outputs arrays)
	for partial_mapping in child_region.partial_mappings:
		if partial_mapping.internal_target_cortical_area == area:
			return true
	
	return false





## Recursively searches for the currently active brain monitor tab
func _find_active_tab_brain_monitor() -> UI_BrainMonitor_3DScene:
	return _search_for_active_brain_monitor_in_view(_root_UI_view)

## Brain monitor tab whose [TabContainer] current tab is a BM, or null if the active tab is not a BM.
func get_brain_monitor_for_active_tab() -> UI_BrainMonitor_3DScene:
	return _find_active_tab_brain_monitor()

## Circuit Builder tab whose [TabContainer] current tab is a CB, or null if the active tab is not a CB.
func get_circuit_builder_for_active_tab() -> CircuitBuilder:
	return _find_active_tab_circuit_builder_in_view(_root_UI_view)

## Recursively searches a UIView for active brain monitor tabs
func _search_for_active_brain_monitor_in_view(ui_view: UIView) -> UI_BrainMonitor_3DScene:
	if ui_view == null:
		return null
	
	# Check if this UIView contains a TabContainer
	if ui_view.mode == UIView.MODE.TAB:
		var tab_container = ui_view._get_primary_child() as UITabContainer
		if tab_container != null and tab_container.get_tab_count() > 0:
			var active_control = tab_container.get_tab_control(tab_container.current_tab)
			if active_control is UI_BrainMonitor_3DScene:
				return active_control as UI_BrainMonitor_3DScene
	
	# If split mode, check both primary and secondary children
	elif ui_view.mode == UIView.MODE.SPLIT:
		# Check primary child (recursive)
		var primary_child = ui_view._get_primary_child()
		if primary_child is UIView:
			var result = _search_for_active_brain_monitor_in_view(primary_child as UIView)
			if result != null:
				return result
		elif primary_child is UITabContainer:
			var tab_container = primary_child as UITabContainer
			if tab_container.get_tab_count() > 0:
				var active_control = tab_container.get_tab_control(tab_container.current_tab)
				if active_control is UI_BrainMonitor_3DScene:
					return active_control as UI_BrainMonitor_3DScene
		
		# Check secondary child (recursive)
		var secondary_child = ui_view._get_secondary_child()
		if secondary_child is UIView:
			var result = _search_for_active_brain_monitor_in_view(secondary_child as UIView)
			if result != null:
				return result
		elif secondary_child is UITabContainer:
			var tab_container = secondary_child as UITabContainer
			if tab_container.get_tab_count() > 0:
				var active_control = tab_container.get_tab_control(tab_container.current_tab)
				if active_control is UI_BrainMonitor_3DScene:
					return active_control as UI_BrainMonitor_3DScene
	
	return null


## Recursively searches a UIView for active Circuit Builder tabs (same traversal as brain monitor search).
func _find_active_tab_circuit_builder_in_view(ui_view: UIView) -> CircuitBuilder:
	if ui_view == null:
		return null
	if ui_view.mode == UIView.MODE.TAB:
		var tab_container = ui_view._get_primary_child() as UITabContainer
		if tab_container != null and tab_container.get_tab_count() > 0:
			var active_control = tab_container.get_tab_control(tab_container.current_tab)
			if active_control is CircuitBuilder:
				return active_control as CircuitBuilder
	elif ui_view.mode == UIView.MODE.SPLIT:
		var primary_child = ui_view._get_primary_child()
		if primary_child is UIView:
			var result = _find_active_tab_circuit_builder_in_view(primary_child as UIView)
			if result != null:
				return result
		elif primary_child is UITabContainer:
			var tab_container = primary_child as UITabContainer
			if tab_container.get_tab_count() > 0:
				var active_control = tab_container.get_tab_control(tab_container.current_tab)
				if active_control is CircuitBuilder:
					return active_control as CircuitBuilder
		var secondary_child = ui_view._get_secondary_child()
		if secondary_child is UIView:
			var result2 = _find_active_tab_circuit_builder_in_view(secondary_child as UIView)
			if result2 != null:
				return result2
		elif secondary_child is UITabContainer:
			var tab_container2 = secondary_child as UITabContainer
			if tab_container2.get_tab_count() > 0:
				var active_control2 = tab_container2.get_tab_control(tab_container2.current_tab)
				if active_control2 is CircuitBuilder:
					return active_control2 as CircuitBuilder
	return null


#endregion
