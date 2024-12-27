extends BaseDraggableWindow
class_name WindowOptionsMenu

const WINDOW_NAME: StringName = "options_menu"

var _section_general: WindowOptionsMenu_General
var _section_vision: WindowOptionsMenu_Vision

var _action_buttons: HBoxContainer

var _waiting: bool

func _ready() -> void:
	super()
	
	_section_general = _window_internals.get_node("HBoxContainer/SpecificSettings/General")
	_section_vision = _window_internals.get_node("HBoxContainer/SpecificSettings/Vision")
	_action_buttons = _window_internals.get_node("HBoxContainer/SpecificSettings/Buttons")
	

func setup() -> void:
	_setup_base_window(WINDOW_NAME)

	if not FeagiCore.feagi_local_cache.cortical_areas.try_to_get_cortical_area_by_ID("iv00_C"):
		var vision_button: Button = _window_internals.get_node("HBoxContainer/SettingSelector/Selection/Vision")
		vision_button.disabled = true
		vision_button.tooltip_text = "No Vision Cortical Areas Found!"

## Buttons in the tscn have their pressed signal binded, with an added argument of the name of the section (by node name) to open
func _select_section(section_name: String) -> void:
	var setting_holders: Node = _window_internals.get_node("HBoxContainer/SpecificSettings")
	if !setting_holders.has_node(section_name):
		push_error("Invalid section name %s selected!" % section_name)
		return
	var section: Node = setting_holders.get_node(section_name)
	
	if section is WindowOptionsMenu_General:
		_action_buttons.visible = true
		_section_general.visible = true
		_section_vision.visible = false
		# dont need to load anything
		return
	if section is WindowOptionsMenu_Vision:
		if _waiting:
			return # prevent feagi spam
		_waiting = true
		_action_buttons.visible = true
		_section_general.visible = false
		_section_vision.visible = true
		
		var feagi_response: FeagiRequestOutput = await FeagiCore.requests.retrieve_vision_tuning_parameters()
		_waiting = false
		if not feagi_response.success:
			BV.NOTIF.add_notification("Unable to get Vision Turning Parameters", NotificationSystemNotification.NOTIFICATION_TYPE.ERROR)
			close_window()
		_section_vision.load_from_FEAGI(feagi_response.decode_response_as_dict())

func _apply_pressed() -> void:
	
	if _section_general.visible:
		_section_general.apply_settings()
		BV.NOTIF.add_notification("Updated local Settings!", NotificationSystemNotification.NOTIFICATION_TYPE.INFO)
		return
	
	if _section_vision.visible:
		_waiting = true
		## Send vision data
		var response: FeagiRequestOutput = await FeagiCore.requests.send_vision_tuning_parameters(_section_vision.export_for_FEAGI())
		if response.success:
			BV.NOTIF.add_notification("Updated Visual Parameters!", NotificationSystemNotification.NOTIFICATION_TYPE.INFO)
		else:
			BV.NOTIF.add_notification("Unable to update Visual Parameters!", NotificationSystemNotification.NOTIFICATION_TYPE.ERROR)
		_waiting = false
		return
