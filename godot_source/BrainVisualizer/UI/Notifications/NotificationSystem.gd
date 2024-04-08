extends VBoxContainer
class_name NotificationSystem

var _notification_prefab: PackedScene = preload("res://BrainVisualizer/UI/Notifications/NotificationSystemNotification.tscn")

func _ready() -> void:
	FeagiCore.connection_state_changed.connect(_connection_state_change)

func add_notification(message: StringName, notification_type: NotificationSystemNotification.NOTIFICATION_TYPE = NotificationSystemNotification.NOTIFICATION_TYPE.INFO, time_seconds: float = NotificationSystemNotification.DEFAULT_TIME):
	var new_message: NotificationSystemNotification = _notification_prefab.instantiate()
	add_child(new_message)
	move_child(new_message, 0) #TODO discuss this with nadji, should new notifications come from the top?
	new_message.set_notification(message, notification_type, time_seconds)

func update_theme(new_theme: Theme) -> void:
	theme = new_theme

func _connection_state_change(new_state: FeagiCore.CONNECTION_STATE, _prev_state: FeagiCore.CONNECTION_STATE):
	match(new_state):
		FeagiCore.CONNECTION_STATE.CONNECTING:
			add_notification("Attempting to connect to FEAGI...")
		FeagiCore.CONNECTION_STATE.CONNECTED:
			add_notification("Connected to FEAGI!")
		FeagiCore.CONNECTION_STATE.DISCONNECTED:
			add_notification("Disconnected from FEAGI!", NotificationSystemNotification.NOTIFICATION_TYPE.WARNING)
			
			