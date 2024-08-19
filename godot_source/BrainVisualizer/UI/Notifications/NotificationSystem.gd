extends VBoxContainer
class_name NotificationSystem

var _notification_prefab: PackedScene = preload("res://BrainVisualizer/UI/Notifications/NotificationSystemNotification.tscn")

func _ready() -> void:
	FeagiCore.network.connection_state_changed.connect(_connection_state_change)
	FeagiCore.genome_load_state_changed.connect(_genome_state_change)
	BV.UI.theme_changed.connect(update_theme)

func add_notification(message: StringName, notification_type: NotificationSystemNotification.NOTIFICATION_TYPE = NotificationSystemNotification.NOTIFICATION_TYPE.INFO):
	var new_message: NotificationSystemNotification = _notification_prefab.instantiate()
	add_child(new_message)
	move_child(new_message, 0) #TODO discuss this with nadji, should new notifications come from the top?
	new_message.set_notification(message, notification_type)

func update_theme(new_theme: Theme) -> void:
	theme = new_theme

func _connection_state_change(_prev_state: FEAGINetworking.CONNECTION_STATE, new_state: FEAGINetworking.CONNECTION_STATE):
	match(new_state):
		FEAGINetworking.CONNECTION_STATE.HEALTHY:
			add_notification("Connected to FEAGI!")
		FEAGINetworking.CONNECTION_STATE.DISCONNECTED:
			add_notification("Disconnected from FEAGI!", NotificationSystemNotification.NOTIFICATION_TYPE.WARNING)
		FEAGINetworking.CONNECTION_STATE.RETRYING_HTTP:
			add_notification("Waiting for FEAGI API!", NotificationSystemNotification.NOTIFICATION_TYPE.WARNING)
		FEAGINetworking.CONNECTION_STATE.RETRYING_WS:
			add_notification("Waiting for FEAGI WebSocket!", NotificationSystemNotification.NOTIFICATION_TYPE.WARNING)
		FEAGINetworking.CONNECTION_STATE.RETRYING_HTTP_WS:
			add_notification("Waiting for FEAGI!", NotificationSystemNotification.NOTIFICATION_TYPE.WARNING)

func _genome_state_change(new_state: FeagiCore.GENOME_LOAD_STATE, _prev_state: FeagiCore.GENOME_LOAD_STATE):
	match(new_state):
		FeagiCore.GENOME_LOAD_STATE.UNKNOWN:
			add_notification("No Genome was found in FEAGI!", NotificationSystemNotification.NOTIFICATION_TYPE.WARNING)
		FeagiCore.GENOME_LOAD_STATE.GENOME_RELOADING:
			add_notification("Loading Genome...")
		FeagiCore.GENOME_LOAD_STATE.GENOME_READY:
			add_notification("Genome loaded!")
		FeagiCore.GENOME_LOAD_STATE.GENOME_PROCESSING:
			add_notification("FEAGI is processing the genome!")
		FeagiCore.GENOME_LOAD_STATE.UNKNOWN:
			pass # Don't do anything, this likely only happens if we are losing connection, which we already notify for
