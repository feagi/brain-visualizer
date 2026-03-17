extends PanelContainer
class_name NotificationSystemNotification

const ERROR_ICON_PATH: StringName = "res://BrainVisualizer/UI/GenericResources/NotificationIcons/error.png"
const WARNING_ICON_PATH: StringName = "res://BrainVisualizer/UI/GenericResources/NotificationIcons/warning.png"
const INFO_ICON_PATH: StringName = "res://BrainVisualizer/UI/GenericResources/NotificationIcons/info.png"
const MAX_DISPLAY_MESSAGE_CHARS: int = 180


enum NOTIFICATION_TYPE {
	INFO,
	WARNING,
	ERROR
}

var _label: RichTextLabel
var _timer: Timer
var _icon
var _theme_sclar: ScaleThemeApplier

## Initialize notification UI references and theme scaling.
func _ready():
	_label = $MarginContainer/HBoxContainer/error_label
	_timer = $Timer
	_icon = $MarginContainer/HBoxContainer/icon
	_label.scroll_active = false
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_timer.autostart = false
	_theme_sclar = ScaleThemeApplier.new()
	_theme_sclar.setup(self, [], BV.UI.loaded_theme)
	# Keep each notification as a shrink-wrapped row in VBox containers.
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	call_deferred("_refresh_row_minimum_size")

## Define what the notification should be
func set_notification(message: StringName, notification_type: NOTIFICATION_TYPE) -> void:
	_label.text = _normalize_message_for_display(message)
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
	call_deferred("_refresh_row_minimum_size")

## Recalculate and pin minimum row height so stacked notifications do not overlap.
func _refresh_row_minimum_size() -> void:
	var min_size: Vector2 = get_combined_minimum_size()
	if min_size.y > 0.0:
		custom_minimum_size.y = min_size.y
	update_minimum_size()

## Keep notification text compact and deterministic for card layout.
func _normalize_message_for_display(message: StringName) -> String:
	var as_text: String = String(message)
	if as_text.length() <= MAX_DISPLAY_MESSAGE_CHARS:
		return as_text
	return "%s..." % as_text.substr(0, MAX_DISPLAY_MESSAGE_CHARS)


## Close the notification when timer or close button fires.
func _on_timeout_or_button_close() -> void:
	queue_free()

## Pause auto-dismiss when the pointer hovers the panel.
func _pause_timer_on_mouse_over() -> void:
	_timer.paused = true
	
## Resume auto-dismiss when the pointer leaves the panel.
func _unpause_timer_on_mouse_off() -> void:
	_timer.paused = false
