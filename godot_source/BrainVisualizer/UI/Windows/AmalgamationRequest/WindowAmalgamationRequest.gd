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
	var preview: UI_BrainMonitor_InteractivePreview = active_bm.create_preview(Vector3i(0,0,0), _circuit_size, false)
	preview.connect_UI_signals(move_signals, resize_signals, closed_signals)


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
	
	# Pre-submit clone mode: initiate clone pending first, then finalize
	if _is_pre_submit_clone:
		var pending_out: FeagiRequestOutput = await FeagiCore.requests.clone_brain_region_pending(_source_region_for_clone, _field_title.text, _field_3d_location.current_vector, Vector2i(0,0))
		if FeagiCore.requests._return_if_HTTP_failed_and_automatically_handle(pending_out):
			push_error("WindowAmalgamationRequest: Failed to initiate region clone pending")
			return
		var pending_dict: Dictionary = pending_out.decode_response_as_dict()
		_amalgamation_ID = pending_dict.get("amalgamation_id", &"")
		# Optional: _circuit_size = Vector3i(pending_dict.get("circuit_size", [1,1,1])[0], pending_dict.get("circuit_size", [1,1,1])[1], pending_dict.get("circuit_size", [1,1,1])[2])

	# Finalize amalgamation destination
	FeagiCore.requests.request_import_amalgamation(_field_3d_location.current_vector, _amalgamation_ID, selected_region.genome_ID, wiring_mode)
	close_window(false)

#OVERRIDE
func close_window(request_cancel: bool = true) -> void:
	if request_cancel and _amalgamation_ID != &"":
		FeagiCore.requests.cancel_pending_amalgamation(_amalgamation_ID)
	super()
