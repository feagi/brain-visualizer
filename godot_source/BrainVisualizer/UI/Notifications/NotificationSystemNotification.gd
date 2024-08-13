extends PanelContainer
class_name NotificationSystemNotification

const ERROR_ICON_PATH: StringName = "res://BrainVisualizer/UI/GenericResources/NotificationIcons/error.png"
const WARNING_ICON_PATH: StringName = "res://BrainVisualizer/UI/GenericResources/NotificationIcons/warning.png"
const INFO_ICON_PATH: StringName = "res://BrainVisualizer/UI/GenericResources/NotificationIcons/info.png"


enum NOTIFICATION_TYPE {
	INFO,
	WARNING,
	ERROR
}

var _label: Label
var _timer: Timer
var _icon
var _theme_sclar: ScaleThemeApplier

func _ready():
	_label = $MarginContainer/HBoxContainer/error_label
	_timer = $Timer
	_icon = $MarginContainer/HBoxContainer/icon
	_timer.autostart = false
	_theme_sclar = ScaleThemeApplier.new()
	_theme_sclar.setup(self, [], BV.UI.loaded_theme)

## Define what the notification should be
func set_notification(message: StringName, notification_type: NOTIFICATION_TYPE) -> void:
	_label.text = message
	match(notification_type):
		NOTIFICATION_TYPE.INFO:
			if has_theme_stylebox("panel", "NotificationSystemNotification"):
				theme_type_variation = "NotificationSystemNotification"
				_icon.texture = load(INFO_ICON_PATH)
				_timer.start(FeagiCore.feagi_settings.seconds_info_notification)
			else:
				push_error("Unable to locate theme variation 'NotificationSystemNotification'! Notification colors may be wrong!")
		NOTIFICATION_TYPE.WARNING:
			if has_theme_stylebox("panel", "NotificationSystemNotification_Warning"):
				theme_type_variation = "NotificationSystemNotification_Warning"
				_icon.texture = load(WARNING_ICON_PATH)
				_timer.start(FeagiCore.feagi_settings.seconds_warning_notification)
			else:
				push_error("Unable to locate theme variation 'NotificationSystemNotification_Warning'! Notification colors may be wrong!")
		NOTIFICATION_TYPE.ERROR:
			if has_theme_stylebox("panel", "NotificationSystemNotification_ERROR"):
				theme_type_variation = "NotificationSystemNotification_ERROR"
				_icon.texture = load(ERROR_ICON_PATH)
				_timer.start(FeagiCore.feagi_settings.seconds_error_notification)
			else:
				push_error("Unable to locate theme variation 'NotificationSystemNotification_ERROR'! Notification colors may be wrong!")


func _on_timeout_or_button_close() -> void:
	queue_free()

func _pause_timer_on_mouse_over() -> void:
	_timer.paused = true
	
func _unpause_timer_on_mouse_off() -> void:
	_timer.paused = false
