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

var _label: Label
var _timer: Timer
var _icon
var _theme_sclar: ScaleThemeApplier

## Initialize notification UI references and theme scaling.
func _ready():
	_label = $MarginContainer/HBoxContainer/message_label
	_timer = $Timer
	_icon = $MarginContainer/HBoxContainer/icon
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.max_lines_visible = 2
	_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timer.autostart = false
	_theme_sclar = ScaleThemeApplier.new()
	_theme_sclar.setup(self, [], BV.UI.loaded_theme)
	# The stack assigns one shared width. Cards stay on the right.
	size_flags_horizontal = Control.SIZE_SHRINK_END
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
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
			if has_theme_stylebox("panel", "NotificationSystemNotification_Error"):
				theme_type_variation = "NotificationSystemNotification_Error"
				_icon.texture = load(ERROR_ICON_PATH)
				_timer.start(FeagiCore.feagi_settings.seconds_error_notification)
			else:
				push_error("Unable to locate theme variation 'NotificationSystemNotification_Error'! Notification colors may be wrong!")
	call_deferred("_refresh_row_minimum_size")

## Width of this card with its own message, before the stack evens the row.
func content_width() -> float:
	return _text_width() + _chrome_width()

## Apply the stack's shared width. The close control stays on the right edge.
func apply_shared_width(card_width: float) -> void:
	size_flags_horizontal = Control.SIZE_SHRINK_END
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var chrome := _chrome_width()
	var inner := maxf(card_width - chrome, 0.0)
	_label.custom_minimum_size.x = inner
	if inner > 0.0 and _text_width() > inner:
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	custom_minimum_size.x = card_width
	var min_size: Vector2 = get_combined_minimum_size()
	if min_size.y > 0.0:
		custom_minimum_size.y = min_size.y
	update_minimum_size()

func _refresh_row_minimum_size() -> void:
	var host := get_parent()
	if host is NotificationSystem:
		host.sync_card_widths()

func _text_width() -> float:
	if _label == null:
		return 0.0
	var font: Font = _label.get_theme_font("font")
	if font == null:
		return 0.0
	return font.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _label.get_theme_font_size("font_size")).x

## Icon, close control, the gaps between them, and the card padding.
func _chrome_width() -> float:
	var margin := $MarginContainer as MarginContainer
	var hbox := $MarginContainer/HBoxContainer as HBoxContainer
	var button := $MarginContainer/HBoxContainer/TextureButton as Control
	var horizontal_padding: float = float(margin.get_theme_constant("margin_left") + margin.get_theme_constant("margin_right"))
	var gaps: float = float(hbox.get_theme_constant("separation")) * 2.0
	return horizontal_padding + gaps + _icon.get_combined_minimum_size().x + button.get_combined_minimum_size().x

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
