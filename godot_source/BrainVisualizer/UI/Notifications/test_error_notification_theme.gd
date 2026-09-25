extends SceneTree
## Error toasts must use the theme variation name stored in the dark themes.
## Run: godot --headless -s res://BrainVisualizer/UI/Notifications/test_error_notification_theme.gd

const NOTIFICATION_PATH := "res://BrainVisualizer/UI/Notifications/NotificationSystemNotification.gd"
const THEME_PATH := "res://BrainVisualizer/UI/Themes/source_themes/source_dark.tres"
const ERROR_VARIATION := "NotificationSystemNotification_Error"


func _initialize() -> void:
	var notification := FileAccess.get_file_as_string(NOTIFICATION_PATH)
	var theme := FileAccess.get_file_as_string(THEME_PATH)
	var failures: int = 0
	if notification.find("\"%s\"" % ERROR_VARIATION) < 0:
		push_error("Error notifications must request theme variation %s" % ERROR_VARIATION)
		failures += 1
	if notification.find("NotificationSystemNotification_ERROR") >= 0:
		push_error("Error notifications must not request the uppercase ERROR variation")
		failures += 1
	if theme.find("%s/styles/panel" % ERROR_VARIATION) < 0:
		push_error("Dark theme is missing the error notification panel style")
		failures += 1
	if failures == 0:
		print("Error notification theme tests: PASS")
		quit(0)
		return
	push_error("Error notification theme tests: FAIL (%d)" % failures)
	quit(1)
