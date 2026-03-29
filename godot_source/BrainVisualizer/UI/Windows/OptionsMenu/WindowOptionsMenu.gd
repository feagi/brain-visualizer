extends BaseDraggableWindow
class_name WindowOptionsMenu

const WINDOW_NAME: StringName = "options_menu"

var _section_general: WindowOptionsMenu_General
var _section_network: VBoxContainer
var _section_vision: WindowOptionsMenu_Vision

var _action_buttons: HBoxContainer
var _network_api_url: LineEdit
var _network_api_host: LineEdit
var _network_api_port: LineEdit
var _network_ws_url: LineEdit
var _network_ws_host: LineEdit
var _network_ws_port: LineEdit
var _network_ws_health: LineEdit

var _waiting: bool

func _ready() -> void:
	super()
	
	_section_general = _window_internals.get_node("HBoxContainer/SpecificSettings/General")
	_section_network = _window_internals.get_node("HBoxContainer/SpecificSettings/Network")
	_section_vision = _window_internals.get_node("HBoxContainer/SpecificSettings/Vision")
	_action_buttons = _window_internals.get_node("HBoxContainer/SpecificSettings/Buttons")
	_network_api_url = _window_internals.get_node("HBoxContainer/SpecificSettings/Network/VBoxContainer5/APIURL")
	_network_api_host = _window_internals.get_node("HBoxContainer/SpecificSettings/Network/VBoxContainer6/APIHost")
	_network_api_port = _window_internals.get_node("HBoxContainer/SpecificSettings/Network/VBoxContainer7/APIPort")
	_network_ws_url = _window_internals.get_node("HBoxContainer/SpecificSettings/Network/VBoxContainer8/WebSocketURL")
	_network_ws_host = _window_internals.get_node("HBoxContainer/SpecificSettings/Network/VBoxContainer9/WebSocketHost")
	_network_ws_port = _window_internals.get_node("HBoxContainer/SpecificSettings/Network/VBoxContainer10/WebSocketPort")
	_network_ws_health = _window_internals.get_node("HBoxContainer/SpecificSettings/Network/VBoxContainer11/WebSocketHealth")
	

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
	if section_name == "General":
		_action_buttons.visible = true
		_section_general.visible = true
		_section_network.visible = false
		_section_vision.visible = false
		# dont need to load anything
		return
	if section_name == "Network":
		_action_buttons.visible = false
		_section_general.visible = false
		_section_network.visible = true
		_section_vision.visible = false
		_populate_network_info()
		return
	if section_name == "Vision":
		if _waiting:
			return # prevent feagi spam
		_waiting = true
		_action_buttons.visible = true
		_section_general.visible = false
		_section_network.visible = false
		_section_vision.visible = true
		
		var feagi_response: FeagiRequestOutput = await FeagiCore.requests.retrieve_vision_tuning_parameters()
		_waiting = false
		if not feagi_response.success:
			BV.NOTIF.add_notification("Unable to get Vision Turning Parameters", NotificationSystemNotification.NOTIFICATION_TYPE.ERROR)
			close_window()
		_section_vision.load_from_FEAGI(feagi_response.decode_response_as_dict())


## Populates Network section fields from currently active FEAGI endpoint/network state.
func _populate_network_info() -> void:
	var endpoint: FeagiEndpointDetails = null
	if FeagiCore != null and FeagiCore.network != null:
		endpoint = FeagiCore.network._feagi_endpoint_details
	var api_url: String = ""
	var websocket_url: String = ""
	if endpoint != null:
		api_url = str(endpoint.full_http_address)
		websocket_url = str(endpoint.full_websocket_address)
	var api_parts: Dictionary = _extract_host_port(api_url)
	var websocket_parts: Dictionary = _extract_host_port(websocket_url)
	_network_api_url.text = api_url
	_network_api_host.text = str(api_parts.get("host", ""))
	_network_api_port.text = str(api_parts.get("port", ""))
	_network_ws_url.text = websocket_url
	_network_ws_host.text = str(websocket_parts.get("host", ""))
	_network_ws_port.text = str(websocket_parts.get("port", ""))
	_network_ws_health.text = _get_websocket_health_text()


## Returns host/port extracted from URL-like addresses (supports host:port, http://host:port, ws://host:port/path).
func _extract_host_port(address: String) -> Dictionary:
	var output: Dictionary = {"host": "", "port": ""}
	var trimmed: String = address.strip_edges()
	if trimmed == "":
		return output
	var authority: String = trimmed
	var scheme_index: int = authority.find("://")
	if scheme_index != -1:
		authority = authority.substr(scheme_index + 3)
	var path_index: int = authority.find("/")
	if path_index != -1:
		authority = authority.substr(0, path_index)
	var at_index: int = authority.rfind("@")
	if at_index != -1:
		authority = authority.substr(at_index + 1)
	if authority.begins_with("["):
		var end_bracket_index: int = authority.find("]")
		if end_bracket_index != -1:
			var ipv6_host: String = authority.substr(0, end_bracket_index + 1)
			var remainder: String = authority.substr(end_bracket_index + 1)
			output["host"] = ipv6_host
			if remainder.begins_with(":"):
				output["port"] = remainder.substr(1)
			return output
	if authority.count(":") == 1:
		var separator_index: int = authority.rfind(":")
		output["host"] = authority.substr(0, separator_index)
		output["port"] = authority.substr(separator_index + 1)
		return output
	output["host"] = authority
	return output


## Returns websocket connection health as readable text.
func _get_websocket_health_text() -> String:
	if FeagiCore == null or FeagiCore.network == null or FeagiCore.network.websocket_API == null:
		return ""
	var health_enum: int = FeagiCore.network.websocket_API.socket_health
	return str(FeagiCore.network.websocket_API.WEBSOCKET_HEALTH.keys()[health_enum])

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
