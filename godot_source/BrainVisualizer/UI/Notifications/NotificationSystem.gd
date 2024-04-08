extends VBoxContainer
class_name NotificationSystem

var _notification_prefab: PackedScene = preload("res://BrainVisualizer/UI/Notifications/NotificationSystemNotification.tscn")

func add_notification(message: StringName, notification_type: NotificationSystemNotification.NOTIFICATION_TYPE = NotificationSystemNotification.NOTIFICATION_TYPE.INFO, time_seconds: float = NotificationSystemNotification.DEFAULT_TIME):
	var new_message: NotificationSystemNotification = _notification_prefab.instantiate()
	add_child(new_message)
	move_child(new_message, 0)
	new_message.set_notification(message, notification_type, time_seconds)

func update_theme(new_theme: Theme) -> void:
	theme = new_theme
