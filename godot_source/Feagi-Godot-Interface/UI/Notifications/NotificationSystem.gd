extends Control
class_name NotificationSystem

@export var Y_gap: int = 5
@export var Y_offset: int = 50
@export var X_offset: int = -300

var _notification_prefab: PackedScene = preload("res://Feagi-Godot-Interface/UI/Notifications/SingleNotification.tscn")

func add_notification(message: StringName, notification_type: SingleNotification.NOTIFICATION_TYPE = SingleNotification.NOTIFICATION_TYPE.INFO, time_seconds: float = SingleNotification.DEFAULT_TIME):
	var new_message: SingleNotification = _notification_prefab.instantiate()
	var spawn_position: Vector2 = Vector2(X_offset, _get_next_notification_height())
	var previous_children: Array = get_children()
	add_child(new_message)
	new_message.position = spawn_position
	new_message.set_notification(message, Y_gap, time_seconds, notification_type)
	for prev_child in previous_children:
		prev_child.notification_closed.connect(new_message.move_up_by)
	
	
func _get_next_notification_height() -> int:
	var offset: int = Y_offset
	for child in get_children():
		offset += child.size.y + Y_gap
	return offset
	

	
