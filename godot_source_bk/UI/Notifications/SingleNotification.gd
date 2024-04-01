extends PanelContainer
class_name SingleNotification

const type_colors: Dictionary = {
	NOTIFICATION_TYPE.INFO : Color(0.32, 0.32, 0.32, 0.65),
	NOTIFICATION_TYPE.WARNING: Color(0.98, 0.85, 0.39, 0.65),
	NOTIFICATION_TYPE.ERROR: Color(0.84, 0.0, 0.0, 0.65)
}

const DEFAULT_TIME: float = 5.0

enum NOTIFICATION_TYPE {
	INFO,
	WARNING,
	ERROR
}

signal notification_closed(height: int)

var _fancyText: RichTextLabel
var _timer: Timer
var _move_timer: Timer
var _gap: int
var _default_font_size: int
var _default_text_section_size: Vector2
var _left_side_offset: int


func _ready():
	_fancyText = $Notification/RichTextLabel
	_timer = $Notification/notification_timer
	_move_timer = $Notification/move_timer
	_left_side_offset = position.x - size.x
	_default_font_size = _fancyText.get_theme_font_size(&"normal_font_size")
	_default_text_section_size = _fancyText.custom_minimum_size
	_timer.one_shot = true
	_timer.timeout.connect(_closing)
	mouse_entered.connect(_pause_timer_on_mouse_over)
	mouse_exited.connect(_unpause_timer_on_mouse_off)
	_update_size(VisConfig.UI_manager.UI_scale)
	VisConfig.UI_manager.UI_scale_changed.connect(_update_size)


func set_notification(message: StringName, y_gap: int, time_seconds, notification_type: NOTIFICATION_TYPE) -> void:
	_fancyText.text = message
	_timer.wait_time = time_seconds
	_timer.start()
	var stylebox: StyleBoxFlat = StyleBoxFlat.new()
	stylebox.bg_color = type_colors[notification_type]
	self.add_theme_stylebox_override("panel", stylebox)
	_gap = y_gap
	
func move_up_by(value: int):
	position.y -= value + _gap

func _closing():
	notification_closed.emit(size.y)
	queue_free()
	
func _pause_timer_on_mouse_over() -> void:
	_timer.paused = true
	
func _unpause_timer_on_mouse_off() -> void:
	_timer.paused = false

func _update_size(multiplier: float) -> void:
	_fancyText.add_theme_font_size_override(&"normal_font_size", int(float(_default_font_size) * multiplier))
	_fancyText.custom_minimum_size = _default_text_section_size * multiplier
	position.x = _left_side_offset# + size.x
	size = Vector2(0,0)
