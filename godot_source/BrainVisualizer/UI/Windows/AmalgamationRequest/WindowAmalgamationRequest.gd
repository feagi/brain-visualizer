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
	var closed_signals: Array[Signal] = [close_window_requested, FeagiCore.about_to_reload_genome]
	var move_signals: Array[Signal] = [_field_3d_location.user_updated_vector]
	var resize_signals: Array[Signal] = [null_dimchange_signal]
	var root_region = FeagiCore.feagi_local_cache.brain_regions.get_root_region()
	print("🔧 DEBUG: Setting up region button with root region: %s" % root_region)
	_region_button.setup(root_region, GenomeObject.SINGLE_MAKEUP.SINGLE_BRAIN_REGION)
	print("🔧 DEBUG: Region button setup complete, current_selected: %s" % _region_button.current_selected)
	var active_bm = BV.UI.get_active_brain_monitor()
	if active_bm == null:
		push_error("WindowAmalgamationRequest: No brain monitor available for preview creation!")
		return
	var preview: UI_BrainMonitor_InteractivePreview = active_bm.create_preview(Vector3i(0,0,0), circuit_size, false)
	preview.connect_UI_signals(move_signals, resize_signals, closed_signals)
	#BV.UI.start_cortical_area_preview(_field_3d_location.current_vector, _circuit_size, move_signals, resize_signals, closed_signals)


func setup_for_clone(source_region: BrainRegion, suggested_title: StringName) -> void:
	_setup_base_window(WINDOW_NAME)
	_is_pre_submit_clone = true
	_source_region_for_clone = source_region
	_amalgamation_ID = &"" # No pending yet
	_circuit_size = Vector3i(1,1,1) # Unknown until server computes; preview minimal
	# Default suggested title editable by user
	_field_title.text = suggested_title
	var closed_signals: Array[Signal] = [close_window_requested, FeagiCore.about_to_reload_genome]
	var move_signals: Array[Signal] = [_field_3d_location.user_updated_vector]
	var resize_signals: Array[Signal] = [null_dimchange_signal]
	var root_region = FeagiCore.feagi_local_cache.brain_regions.get_root_region()
	_region_button.setup(root_region, GenomeObject.SINGLE_MAKEUP.SINGLE_BRAIN_REGION)
	var active_bm = BV.UI.get_active_brain_monitor()
	if active_bm == null:
		push_error("WindowAmalgamationRequest: No brain monitor available for preview creation!")
		return
	# Use brain region preview (dual plates) instead of voxel preview
	_region_preview = active_bm.create_brain_region_preview(_source_region_for_clone, Vector3i(0,0,0))
	# Connect movement from the 3D coordinate field to update the preview position
	_field_3d_location.user_updated_vector.connect(func(new_vec: Vector3i):
		if _region_preview != null:
			_region_preview.update_position_with_new_FEAGI_coordinate(new_vec)
	)
	# Ensure preview is cleaned up when window closes or genome reloads
	close_window_requested.connect(func(_wname: StringName = WINDOW_NAME):
		if _region_preview != null:
			_region_preview.cleanup()
			_region_preview = null
	)
	FeagiCore.about_to_reload_genome.connect(func():
		if _region_preview != null:
			_region_preview.cleanup()
			_region_preview = null
	)


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
	
	# CRITICAL: Start flashing preview to show progress
	print("🔧 DEBUG: Starting flashing preview for cloning progress...")
	print("🔧 DEBUG: About to call _start_flashing_preview()")
	_start_flashing_preview()
	print("🔧 DEBUG: _start_flashing_preview() completed")
	
	# Pre-submit clone mode: initiate clone pending first, then finalize
	if _is_pre_submit_clone:
		# Pass user-edited title through to pending clone so server sets the clone name
		var pending_out: FeagiRequestOutput = await FeagiCore.requests.clone_brain_region_pending(_source_region_for_clone, _field_title.text, _field_3d_location.current_vector, Vector2i(0,0))
		if FeagiCore.requests._return_if_HTTP_failed_and_automatically_handle(pending_out):
			push_error("WindowAmalgamationRequest: Failed to initiate region clone pending")
			# Stop flashing preview on failure
			_stop_flashing_preview()
			return
		var pending_dict: Dictionary = pending_out.decode_response_as_dict()
		_amalgamation_ID = pending_dict.get("amalgamation_id", &"")
		# Optional: _circuit_size = Vector3i(pending_dict.get("circuit_size", [1,1,1])[0], pending_dict.get("circuit_size", [1,1,1])[1], pending_dict.get("circuit_size", [1,1,1])[2])

	# Finalize amalgamation destination (async - don't wait for completion)
	print("🔧 DEBUG: About to call request_import_amalgamation...")
	print("🚨 WINDOW DEBUG: Parameters - position: %s, amalgamation_ID: %s, parent_region_ID: %s, wiring_mode: %s" % [_field_3d_location.current_vector, _amalgamation_ID, selected_region.genome_ID, wiring_mode])
	print("🚨 WINDOW DEBUG: FeagiCore.requests exists: %s" % (FeagiCore.requests != null))
	
	var result = await FeagiCore.requests.request_import_amalgamation(_field_3d_location.current_vector, _amalgamation_ID, selected_region.genome_ID, wiring_mode)
	print("🚨 WINDOW DEBUG: request_import_amalgamation call completed: %s" % (result != null))
	print("🔧 DEBUG: request_import_amalgamation initiated - closing window immediately for user feedback")
	
	# CRITICAL: Close window immediately but keep flashing preview alive
	close_window(false)

#OVERRIDE
func close_window(request_cancel: bool = true) -> void:
	if request_cancel and _amalgamation_ID != &"":
		FeagiCore.requests.cancel_pending_amalgamation(_amalgamation_ID)
	# Always cleanup preview if present
	if _region_preview != null:
		_region_preview.cleanup()
		_region_preview = null
	
	# Only cleanup flashing preview if canceling - otherwise let it continue
	if request_cancel:
		print("🔄 FLASH: Window closing due to cancel - stopping flashing preview")
		_stop_flashing_preview()
	else:
		print("🔄 FLASH: Window closing normally - keeping flashing preview alive for background processing")
		# Detach the timer from this window so it doesn't get destroyed
		if _flash_timer != null:
			_flash_timer.get_parent().remove_child(_flash_timer)
			# Add timer to the main scene tree so it stays alive
			var scene_tree = Engine.get_main_loop() as SceneTree
			if scene_tree and scene_tree.root:
				scene_tree.root.add_child(_flash_timer)
				print("🔄 FLASH: Timer detached and moved to scene root")
	
	super()

## Start flashing preview to indicate cloning progress
func _start_flashing_preview() -> void:
	if _is_flashing:
		print("🔄 FLASH: Already flashing, skipping")
		return # Already flashing
	
	print("🔄 FLASH: Starting flashing preview for region clone progress")
	print("🔄 FLASH: _source_region_for_clone: %s" % (_source_region_for_clone.friendly_name if _source_region_for_clone else "null"))
	print("🔄 FLASH: _is_pre_submit_clone: %s" % _is_pre_submit_clone)
	
	_is_flashing = true
	
	# Create flashing preview at the target location
	if _source_region_for_clone != null:
		var target_position = _field_3d_location.current_vector
		print("🔄 FLASH: Creating flashing preview at position: %s" % target_position)
		print("🔄 FLASH: Source region: %s (ID: %s)" % [_source_region_for_clone.friendly_name, _source_region_for_clone.region_ID])
		
		# Use the brain monitor's factory method to create the preview properly
		var main_bm = BV.UI.get_temp_root_bm()
		print("🔄 FLASH: Main brain monitor: %s" % (main_bm.name if main_bm else "null"))
		
		if main_bm:
			print("🔄 FLASH: Calling create_brain_region_preview...")
			_flashing_preview = main_bm.create_brain_region_preview(_source_region_for_clone, target_position)
			print("🔄 FLASH: Preview created: %s" % (_flashing_preview.name if _flashing_preview else "null"))
			
			if _flashing_preview:
				print("🔄 FLASH: Preview position: %s" % _flashing_preview.position)
				print("🔄 FLASH: Preview visible: %s" % _flashing_preview.visible)
				print("🔄 FLASH: Added flashing preview to 3D scene")
			else:
				print("❌ FLASH: Failed to create flashing preview!")
		else:
			print("❌ FLASH: No main brain monitor available!")
		
		# Create timer for flashing effect
		_flash_timer = Timer.new()
		_flash_timer.wait_time = 0.75  # Flash every 0.75 seconds (slightly slower than original)
		_flash_timer.timeout.connect(_on_flash_timer_timeout)
		add_child(_flash_timer)
		_flash_timer.start()
		
		print("🔄 FLASH: Flashing timer started (wait_time: %s)" % _flash_timer.wait_time)
	else:
		print("❌ FLASH: No source region for clone available!")
		_is_flashing = false

## Stop flashing preview and clean up
func _stop_flashing_preview() -> void:
	if not _is_flashing:
		return
	
	print("🔄 FLASH: Stopping flashing preview")
	_is_flashing = false
	
	# Stop and cleanup timer
	if _flash_timer != null:
		_flash_timer.stop()
		_flash_timer.queue_free()
		_flash_timer = null
	
	# Cleanup flashing preview
	if _flashing_preview != null:
		_flashing_preview.queue_free()
		_flashing_preview = null
		print("🔄 FLASH: Flashing preview cleaned up")

## Timer callback for flashing effect
func _on_flash_timer_timeout() -> void:
	if _flashing_preview != null:
		# Toggle visibility for flashing effect
		var new_visibility = not _flashing_preview.visible
		_flashing_preview.visible = new_visibility
		print("🔄 FLASH: Timer tick - toggled visibility to: %s" % new_visibility)
	else:
		print("❌ FLASH: Timer tick but no preview available!")
