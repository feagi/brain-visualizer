extends VBoxContainer
class_name NotificationSystem

var _notification_prefab: PackedScene = preload("res://BrainVisualizer/UI/Notifications/NotificationSystemNotification.tscn")
var _last_notification_emit_ms: Dictionary = {}
const MAX_VISIBLE_NOTIFICATIONS: int = 8

func _ready() -> void:
	FeagiCore.network.connection_state_changed.connect(_connection_state_change)
	FeagiCore.genome_load_state_changed.connect(_genome_state_change)
	BV.UI.theme_changed.connect(update_theme)

func add_notification(message: StringName, notification_type: NotificationSystemNotification.NOTIFICATION_TYPE = NotificationSystemNotification.NOTIFICATION_TYPE.INFO):
	var dedupe_key: String = "%s|%d" % [String(message), int(notification_type)]
	var now_ms: int = Time.get_ticks_msec()
	var dedupe_window_ms: int = _get_notification_duration_ms(notification_type)
	if dedupe_window_ms > 0 and _last_notification_emit_ms.has(dedupe_key):
		var last_ms: int = int(_last_notification_emit_ms[dedupe_key])
		if now_ms - last_ms < dedupe_window_ms:
			return
	_last_notification_emit_ms[dedupe_key] = now_ms

	var new_message: NotificationSystemNotification = _notification_prefab.instantiate()
	add_child(new_message)
	move_child(new_message, 0) #TODO discuss this with nadji, should new notifications come from the top?
	new_message.set_notification(message, notification_type)
	_enforce_notification_capacity()

func _get_notification_duration_ms(notification_type: NotificationSystemNotification.NOTIFICATION_TYPE) -> int:
	if FeagiCore.feagi_settings == null:
		return 0
	match notification_type:
		NotificationSystemNotification.NOTIFICATION_TYPE.INFO:
			return int(FeagiCore.feagi_settings.seconds_info_notification * 1000.0)
		NotificationSystemNotification.NOTIFICATION_TYPE.WARNING:
			return int(FeagiCore.feagi_settings.seconds_warning_notification * 1000.0)
		NotificationSystemNotification.NOTIFICATION_TYPE.ERROR:
			return int(FeagiCore.feagi_settings.seconds_error_notification * 1000.0)
	return 0

func _enforce_notification_capacity() -> void:
	while get_child_count() > MAX_VISIBLE_NOTIFICATIONS:
		var oldest_index: int = get_child_count() - 1
		var oldest_notification := get_child(oldest_index)
		if oldest_notification == null:
			break
		remove_child(oldest_notification)
		oldest_notification.queue_free()

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
