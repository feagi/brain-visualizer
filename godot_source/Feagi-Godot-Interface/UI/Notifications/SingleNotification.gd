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

func _ready():
	_fancyText = $Notification/RichTextLabel
	_timer = $Notification/notification_timer
	_move_timer = $Notification/move_timer
	_timer.one_shot = true
	_timer.timeout.connect(_closing)
	mouse_entered.connect(_pause_timer_on_mouse_over)
	mouse_exited.connect(_unpause_timer_on_mouse_off)

func set_notification(message: StringName, time_seconds, notification_type: NOTIFICATION_TYPE = NOTIFICATION_TYPE.INFO) -> void:
	_fancyText.text = message
	_timer.wait_time = time_seconds
	_timer.start()
	var stylebox: StyleBoxFlat = StyleBoxFlat.new()
	stylebox.bg_color = type_colors[notification_type]
	self.add_theme_stylebox_override("panel", stylebox)
	
func move_up_by(value: int):
	position = Vector2(position.x, value)

func _closing():
	notification_closed.emit(size.y)
	queue_free()
	
func _pause_timer_on_mouse_over() -> void:
	_timer.paused = true
	
func _unpause_timer_on_mouse_off() -> void:
	_timer.paused = false
