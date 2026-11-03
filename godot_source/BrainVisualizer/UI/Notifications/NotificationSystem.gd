extends VBoxContainer
class_name NotificationSystem

var _notification_prefab: PackedScene = preload("res://BrainVisualizer/UI/Notifications/NotificationSystemNotification.tscn")
var _last_notification_emit_ms: Dictionary = {}
var _top_bar_bottom: float = 0.0
const MAX_VISIBLE_NOTIFICATIONS: int = 8
const _COLUMN_THEME := &"NotificationSystem"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	FeagiCore.network.connection_state_changed.connect(_connection_state_change)
	FeagiCore.genome_load_state_changed.connect(_genome_state_change)
	BV.UI.theme_changed.connect(update_theme)
	_apply_column_metrics()

## Place the column under the top bar. Width and inset come from the theme.
func place_below_top_bar(top_bar_bottom: float) -> void:
	_top_bar_bottom = top_bar_bottom
	_apply_column_metrics()

## Right-column offsets. x = left, y = top, z = right, w = bottom.
static func column_offsets(top_bar_bottom: float, width: int, inset: int) -> Vector4:
	return Vector4(-(width + inset), top_bar_bottom + float(inset), -inset, -inset)

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
	new_message.tree_exiting.connect(_sync_card_widths_deferred)
	new_message.set_notification(message, notification_type)
	_enforce_notification_capacity()
	_sync_card_widths_deferred()

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
	_apply_column_metrics()
	sync_card_widths()

## One width for every visible card: the longest message, and never wider than the column.
static func shared_card_width(content_widths: Array, column_cap: float) -> float:
	var widest := 0.0
	for entry in content_widths:
		widest = maxf(widest, float(entry))
	if column_cap > 0.0 and widest > column_cap:
		return column_cap
	return widest

func sync_card_widths() -> void:
	var content_widths: Array = []
	for child in get_children():
		if not child is NotificationSystemNotification:
			continue
		if child.is_queued_for_deletion():
			continue
		content_widths.append(child.content_width())
	var cap := 0.0
	if theme != null and theme.has_constant("size_x", _COLUMN_THEME):
		cap = float(theme.get_constant("size_x", _COLUMN_THEME))
	var shared := shared_card_width(content_widths, cap)
	for child in get_children():
		if not child is NotificationSystemNotification:
			continue
		if child.is_queued_for_deletion():
			continue
		child.apply_shared_width(shared)

func _sync_card_widths_deferred() -> void:
	call_deferred("sync_card_widths")

func _apply_column_metrics() -> void:
	if theme == null:
		return
	if not theme.has_constant("size_x", _COLUMN_THEME) or not theme.has_constant("size_y", _COLUMN_THEME):
		push_error("NotificationSystem theme is missing column size_x or size_y")
		return
	var width := theme.get_constant("size_x", _COLUMN_THEME)
	var inset := theme.get_constant("size_y", _COLUMN_THEME)
	if theme.has_constant("separation", _COLUMN_THEME):
		add_theme_constant_override("separation", theme.get_constant("separation", _COLUMN_THEME))
	var offsets := column_offsets(_top_bar_bottom, width, inset)
	offset_left = offsets.x
	offset_top = offsets.y
	offset_right = offsets.z
	offset_bottom = offsets.w

func _connection_state_change(_prev_state: FEAGINetworking.CONNECTION_STATE, new_state: FEAGINetworking.CONNECTION_STATE):
	match(new_state):
		FEAGINetworking.CONNECTION_STATE.HEALTHY:
			add_notification("Connected to FEAGI!")
		FEAGINetworking.CONNECTION_STATE.DISCONNECTED:
			add_notification("Disconnected from FEAGI!", NotificationSystemNotification.NOTIFICATION_TYPE.WARNING)
		FEAGINetworking.CONNECTION_STATE.RETRYING_HTTP:
			add_notification("Waiting for FEAGI API!", NotificationSystemNotification.NOTIFICATION_TYPE.WARNING)
		FEAGINetworking.CONNECTION_STATE.RETRYING_STREAM:
			add_notification("Waiting for the FEAGI data stream!", NotificationSystemNotification.NOTIFICATION_TYPE.WARNING)
		FEAGINetworking.CONNECTION_STATE.RETRYING_HTTP_STREAM:
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
