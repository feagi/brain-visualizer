extends BaseDraggableWindow
class_name WindowAmalgamationRequest

const WINDOW_NAME: StringName = "import_amalgamation"

signal null_dimchange_signal(val: Vector3i) # Not technically utilized, but needed as a placeholder as a required arg

var _field_title: TextInput
var _field_3d_location: Vector3iSpinboxField
var _region_button: GenomeObjectSelectorButton
var _wiring_selector: OptionButton

var _amalgamation_ID: StringName
var _circuit_size: Vector3i
var _is_pre_submit_clone: bool = false
var _source_region_for_clone: BrainRegion = null
var _region_preview: UI_BrainMonitor_BrainRegionPreview = null
var _interactive_preview: UI_BrainMonitor_InteractivePreview = null
var _preview_refresh_generation: int = 0

# Flashing progress indicator
var _flashing_preview: UI_BrainMonitor_BrainRegionPreview = null
var _flash_timer: Timer = null
var _is_flashing: bool = false


func _ready() -> void:
	super()
	_field_title = _window_internals.get_node('HBoxContainer/AmalgamationTitle')
	_field_3d_location = _window_internals.get_node('HBoxContainer2/Coordinates_3D')
	_region_button = _window_internals.get_node('HBoxContainer4/GenomeObjectSelectorButton')
	_wiring_selector = _window_internals.get_node('HBoxContainer5/OptionButton')


func setup(amalgamation_ID: StringName, genome_title: StringName, circuit_size: Vector3i) -> void:
	_setup_base_window(WINDOW_NAME)
	_amalgamation_ID = amalgamation_ID
	_circuit_size = circuit_size
	_field_title.text = genome_title
	var root_region = FeagiCore.feagi_local_cache.brain_regions.get_root_region()
	_region_button.setup(root_region, GenomeObject.SINGLE_MAKEUP.SINGLE_BRAIN_REGION)
	_connect_parent_circuit_selection()
	await _attach_placement_preview()


func setup_for_clone(source_region: BrainRegion, suggested_title: StringName, default_position: Vector3i = Vector3i(0, 0, 0)) -> void:
	_setup_base_window(WINDOW_NAME)
	_is_pre_submit_clone = true
	_source_region_for_clone = source_region
	_amalgamation_ID = &"" # No pending yet
	_circuit_size = Vector3i(1,1,1) # Unknown until server computes; preview minimal
	_field_title.text = suggested_title
	_field_3d_location.current_vector = default_position
	var root_region = FeagiCore.feagi_local_cache.brain_regions.get_root_region()
	_region_button.setup(root_region, GenomeObject.SINGLE_MAKEUP.SINGLE_BRAIN_REGION)
	_connect_parent_circuit_selection()
	_field_3d_location.user_updated_vector.connect(func(new_vec: Vector3i):
		if _region_preview != null:
			_region_preview.update_position_with_new_FEAGI_coordinate(new_vec)
	)
	FeagiCore.about_to_reload_genome.connect(func():
		_cleanup_placement_previews()
	)
	await _attach_placement_preview()


## Resolves the selected parent circuit (brain region) from the selector, falling back to root.
func _get_parent_circuit_region() -> BrainRegion:
	var sel: GenomeObject = _region_button.current_selected
	if sel is BrainRegion:
		return sel as BrainRegion
	return FeagiCore.feagi_local_cache.brain_regions.get_root_region()


## Ensures split view is open and a Brain Monitor tab exists for [param parent_region], then returns that monitor.
## Root circuit uses the main floating brain monitor ([member UIManager.temp_root_bm]) when present.
func _ensure_brain_monitor_for_parent_circuit(parent_region: BrainRegion) -> UI_BrainMonitor_3DScene:
	if parent_region == null:
		return null
	if parent_region.is_root_region():
		var root_bm: UI_BrainMonitor_3DScene = BV.UI.get_brain_monitor_for_region(parent_region)
		if root_bm != null:
			return root_bm
		return BV.UI.temp_root_bm
	var root_UI_view: UIView = BV.UI.root_UI_view
	if root_UI_view == null:
		return BV.UI.get_brain_monitor_for_region(parent_region)
	if root_UI_view.mode != UIView.MODE.SPLIT:
		root_UI_view.setup_as_split()
	var temp_split: TempSplit = BV.UI.get_node("CB_Holder") as TempSplit
	if temp_split != null and temp_split.current_state == TempSplit.STATES.CB_CLOSED:
		temp_split.set_view(TempSplit.STATES.CB_HORIZONTAL)
	var primary_tab_container: UITabContainer = root_UI_view._get_primary_child() as UITabContainer
	var secondary_tab_container: UITabContainer = root_UI_view.get_secondary_tab_container()
	if primary_tab_container == null or secondary_tab_container == null:
		push_error("WindowAmalgamationRequest: Tab containers not found after split setup")
		return BV.UI.get_brain_monitor_for_region(parent_region)
	root_UI_view.show_or_create_CB_of_region(parent_region, primary_tab_container)
	root_UI_view.show_or_create_BM_of_region(parent_region, secondary_tab_container)
	await get_tree().process_frame
	await get_tree().process_frame
	return BV.UI.get_brain_monitor_for_region(parent_region)


func _connect_parent_circuit_selection() -> void:
	if not _region_button.object_selected.is_connected(_on_parent_circuit_changed):
		_region_button.object_selected.connect(_on_parent_circuit_changed)


func _on_parent_circuit_changed(_object: GenomeObject) -> void:
	if not is_inside_tree():
		return
	await _attach_placement_preview()


## Rebuilds placement preview on the brain monitor that matches the current parent circuit selection.
func _attach_placement_preview() -> void:
	_preview_refresh_generation += 1
	var gen: int = _preview_refresh_generation
	_cleanup_placement_previews()
	var parent_region: BrainRegion = _get_parent_circuit_region()
	var bm: UI_BrainMonitor_3DScene = await _ensure_brain_monitor_for_parent_circuit(parent_region)
	if gen != _preview_refresh_generation:
		return
	if bm == null:
		push_error("WindowAmalgamationRequest: No brain monitor available for preview for parent circuit")
		return
	# Window close cleans previews in close_window(); only genome reload needs a signal here.
	var closed_signals: Array[Signal] = [FeagiCore.about_to_reload_genome]
	var move_signals: Array[Signal] = [_field_3d_location.user_updated_vector]
	var resize_signals: Array[Signal] = [null_dimchange_signal]
	if _is_pre_submit_clone:
		_region_preview = bm.create_brain_region_preview(_source_region_for_clone, _field_3d_location.current_vector)
	else:
		_interactive_preview = bm.create_preview(Vector3i(0,0,0), _circuit_size, false)
		_interactive_preview.connect_UI_signals(move_signals, resize_signals, closed_signals)


func _cleanup_placement_previews() -> void:
	if _region_preview != null:
		_region_preview.cleanup()
		_region_preview = null
	if _interactive_preview != null and is_instance_valid(_interactive_preview):
		_interactive_preview.queue_free()
		_interactive_preview = null


func _import_pressed():
	print("🔧 DEBUG: _import_pressed() called for amalgamation import")
	print("🔧 DEBUG: Region button state: %s" % _region_button)
	print("🔧 DEBUG: Region button current_selected: %s" % _region_button.current_selected)
	
	var wiring_mode: String = "none" #TODO move to an enum!
	match(_wiring_selector.selected):
		0:
			wiring_mode = "all"
		1:
			wiring_mode = "system"
		2:
			wiring_mode = "none"
	
	var selected_region = _region_button.current_selected
	if selected_region == null:
		print("🔧 DEBUG: No region selected, falling back to root region")
		selected_region = FeagiCore.feagi_local_cache.brain_regions.get_root_region()
		if selected_region == null:
			push_error("WindowAmalgamationRequest: No region available for amalgamation import!")
			BV.NOTIF.add_notification("❌ No region available for amalgamation import!", NotificationSystemNotification.NOTIFICATION_TYPE.ERROR)
			return
	
	print("🔧 DEBUG: Selected region: %s" % selected_region.friendly_name)
	print("🔧 DEBUG: Selected region genome ID: %s" % selected_region.genome_ID)
	
	print("🔧 DEBUG: Starting flashing preview for cloning progress...")
	print("🔧 DEBUG: _source_region_for_clone: %s" % (_source_region_for_clone.friendly_name if _source_region_for_clone else "null"))
	print("🔧 DEBUG: _is_pre_submit_clone: %s" % _is_pre_submit_clone)
	await _start_flashing_preview()
	print("🔧 DEBUG: _start_flashing_preview() completed")
	print("🔧 DEBUG: _is_flashing after start: %s" % _is_flashing)
	print("🔧 DEBUG: _flashing_preview after start: %s" % (_flashing_preview.name if _flashing_preview else "null"))
	
	if _is_pre_submit_clone:
		var pending_out: FeagiRequestOutput = await FeagiCore.requests.clone_brain_region_pending(_source_region_for_clone, _field_title.text, _field_3d_location.current_vector, Vector2i(0,0))
		if FeagiCore.requests._return_if_HTTP_failed_and_automatically_handle(pending_out):
			push_error("WindowAmalgamationRequest: Failed to initiate region clone pending")
			_stop_flashing_preview()
			return
		var pending_dict: Dictionary = pending_out.decode_response_as_dict()
		_amalgamation_ID = pending_dict.get("amalgamation_id", &"")
	
	print("🔧 DEBUG: About to call request_import_amalgamation...")
	print("🚨 WINDOW DEBUG: Parameters - position: %s, amalgamation_ID: %s, parent_region_ID: %s, wiring_mode: %s" % [_field_3d_location.current_vector, _amalgamation_ID, selected_region.genome_ID, wiring_mode])
	print("🚨 WINDOW DEBUG: FeagiCore.requests exists: %s" % (FeagiCore.requests != null))
	
	var result = await FeagiCore.requests.request_import_amalgamation(_field_3d_location.current_vector, _amalgamation_ID, selected_region.genome_ID, wiring_mode)
	print("🚨 WINDOW DEBUG: request_import_amalgamation call completed: %s" % (result != null))
	print("🔧 DEBUG: request_import_amalgamation initiated - closing window immediately for user feedback")
	
	close_window(false)

#OVERRIDE
func close_window(request_cancel: bool = true) -> void:
	if request_cancel and _amalgamation_ID != &"":
		FeagiCore.requests.cancel_pending_amalgamation(_amalgamation_ID)
	_cleanup_placement_previews()
	
	if request_cancel:
		print("🔄 FLASH: Window closing due to cancel - stopping flashing preview")
		_stop_flashing_preview()
	else:
		print("🔄 FLASH: Window closing normally - keeping flashing preview alive for background processing")
		if _flash_timer != null:
			_flash_timer.get_parent().remove_child(_flash_timer)
			var scene_tree = Engine.get_main_loop() as SceneTree
			if scene_tree and scene_tree.root:
				scene_tree.root.add_child(_flash_timer)
				print("🔄 FLASH: Timer detached and moved to scene root")
	
	super()


## Start flashing preview to indicate cloning progress (only used when cloning a region).
func _start_flashing_preview() -> void:
	if _is_flashing:
		print("🔄 FLASH: Already flashing, skipping")
		return
	if _source_region_for_clone == null:
		return
	_is_flashing = true
	var target_position: Vector3i = _field_3d_location.current_vector
	var parent_region: BrainRegion = _get_parent_circuit_region()
	var main_bm: UI_BrainMonitor_3DScene = await _ensure_brain_monitor_for_parent_circuit(parent_region)
	if main_bm == null:
		print("❌ FLASH: No brain monitor for parent circuit")
		_is_flashing = false
		return
	_flashing_preview = main_bm.create_brain_region_preview(_source_region_for_clone, target_position)
	if _flashing_preview == null:
		_is_flashing = false
		return
	_flash_timer = Timer.new()
	_flash_timer.wait_time = 0.75
	_flash_timer.timeout.connect(_on_flash_timer_timeout)
	add_child(_flash_timer)
	_flash_timer.start()


## Stop flashing preview and clean up
func _stop_flashing_preview() -> void:
	if not _is_flashing:
		return
	print("🔄 FLASH: Stopping flashing preview")
	_is_flashing = false
	if _flash_timer != null:
		_flash_timer.stop()
		_flash_timer.queue_free()
		_flash_timer = null
	if _flashing_preview != null:
		_flashing_preview.queue_free()
		_flashing_preview = null
		print("🔄 FLASH: Flashing preview cleaned up")


func _on_flash_timer_timeout() -> void:
	if _flashing_preview != null:
		_flashing_preview.visible = not _flashing_preview.visible
