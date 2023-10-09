extends Node
## AUTOLOADED
## Contains any general info about the state of the visualizer

enum STATES {
	LOADING_INITIAL,
	READY,
}

var UI_manager: UIManager
var is_premium: bool = true
var version: BVVersion

var visualizer_state: STATES:
	get: return _visualizer_state
	set(v):
		print("STATE: SWITCH TO " + STATES.find_key(v))
		_visualizer_state = v

var _visualizer_state: STATES = STATES.LOADING_INITIAL

func show_info_popup(title_text: StringName, message_text: StringName, button_text: StringName, icon: WindowPopupInfo.ICON = WindowPopupInfo.ICON.DEFAULT) -> void:
	UI_manager.window_manager.spawn_info_popup(title_text, message_text, button_text, icon)

func _ready() -> void:
	version = BVVersion.new()
	push_warning("Init Brain Visualizer Verion " + str(version.manual_version))
	push_warning("Compile time: " + Time.get_datetime_string_from_unix_time(version.automatic_version))
