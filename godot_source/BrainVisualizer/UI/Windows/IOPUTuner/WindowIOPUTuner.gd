extends BaseDraggableWindow
class_name WindowIOPUTuner

const WINDOW_NAME: StringName = "IOPU_tuner"

var _vision_button: Button
var _no_section: VBoxContainer
var _vision: WindowOptionsMenu_Vision
var _apply_button: Button

var _waiting: bool

func _ready() -> void:
	super()
	_vision_button = _window_internals.get_node("HBoxContainer/IOPUs/Selection/Vision")
	_no_section = _window_internals.get_node("HBoxContainer/SpecificSettings/Nothing")
	_vision = _window_internals.get_node("HBoxContainer/SpecificSettings/Vision")
	_apply_button = _window_internals.get_node("HBoxContainer/SpecificSettings/Apply")

func setup() -> void:
	_setup_base_window(WINDOW_NAME)
	
	if not FeagiCore.feagi_local_cache.cortical_areas.try_to_get_cortical_area_by_ID("iv00_C"):
		_vision_button.disabled = true
		_vision_button.tooltip_text = "No Vision Cortical Areas Found!"

func _vision_pressed() -> void:
	if _waiting:
		return # prevent feagi spam
	_waiting = true
	_no_section.visible = false
	_vision.visible = true
	_apply_button.visible = true
	
	var feagi_response: FeagiRequestOutput = await FeagiCore.requests.retrieve_vision_tuning_parameters()
	_waiting = false
	if not feagi_response.success:
		BV.NOTIF.add_notification("Unable to get Vision Turning Parameters", NotificationSystemNotification.NOTIFICATION_TYPE.ERROR)
		close_window()
	_vision.load_from_FEAGI(feagi_response.decode_response_as_dict())

func _apply_pressed() -> void:
	
	_waiting = true
	if _vision.visible:
		## Send vision data
		var response: FeagiRequestOutput = await FeagiCore.requests.send_vision_tuning_parameters(_vision.export_for_FEAGI())
		if response.success:
			BV.NOTIF.add_notification("Updated Visual Parameters!", NotificationSystemNotification.NOTIFICATION_TYPE.INFO)
		else:
			BV.NOTIF.add_notification("Unable to update Visual Parameters!", NotificationSystemNotification.NOTIFICATION_TYPE.ERROR)
	
	
	close_window()
	
	
