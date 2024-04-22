extends PanelContainer
class_name NotificationSystemNotification

const DEFAULT_TIME: float = 5.0 #TODO move to config

enum NOTIFICATION_TYPE {
	INFO,
	WARNING,
	ERROR
}

var _label: Label
var _timer: Timer
var _theme_sclar: ScaleThemeApplier

func _ready():
	_label = $MarginContainer/HBoxContainer/error_label
	_timer = $Timer
	_timer.autostart = false
	_theme_sclar = ScaleThemeApplier.new()
	_theme_sclar.setup(self, [], BV.UI.loaded_theme)

## Define what the notification should be
func set_notification(message: StringName, notification_type: NOTIFICATION_TYPE, time_seconds: float = DEFAULT_TIME) -> void:
	_label.text = message
	_timer.start(time_seconds)
	match(notification_type):
		NOTIFICATION_TYPE.INFO:
			if has_theme_stylebox("panel", "NotificationSystemNotification"):
				theme_type_variation = "NotificationSystemNotification"
			else:
				push_error("Unable to locate theme variation 'NotificationSystemNotification'! Notification colors may be wrong!")
		NOTIFICATION_TYPE.WARNING:
			if has_theme_stylebox("panel", "NotificationSystemNotification_Warning"):
				theme_type_variation = "NotificationSystemNotification_Warning"
			else:
				push_error("Unable to locate theme variation 'NotificationSystemNotification_Warning'! Notification colors may be wrong!")
		NOTIFICATION_TYPE.ERROR:
			if has_theme_stylebox("panel", "NotificationSystemNotification_ERROR"):
				theme_type_variation = "NotificationSystemNotification_ERROR"
			else:
				push_error("Unable to locate theme variation 'NotificationSystemNotification_ERROR'! Notification colors may be wrong!")


func _on_timeout_or_button_close() -> void:
	queue_free()

func _pause_timer_on_mouse_over() -> void:
	_timer.paused = true
	
func _unpause_timer_on_mouse_off() -> void:
	_timer.paused = false
