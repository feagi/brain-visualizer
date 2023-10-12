extends PanelContainer
class_name SingleNotification

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

func set_notification(message: StringName, time_seconds) -> void:
	_fancyText.text = message
	_timer.wait_time = time_seconds
	_timer.start()

func move_up_by(value: int):
	position = Vector2(position.x, value)

func _closing():
	notification_closed.emit(size.y)
	queue_free()
	
