extends PanelContainer
class_name PanelContainerButton

signal pressed()

var _unpressed: StyleBoxFlat = StyleBoxFlat.new()
var _hover: StyleBoxFlat = StyleBoxFlat.new()
var _clicked: StyleBoxFlat = StyleBoxFlat.new()


func _ready() -> void:
	mouse_entered.connect(_mouse_entered)
	mouse_exited.connect(_mouse_exited)

## Called externally from [ScaleThemeApplier]
func update_theme(standard: StyleBoxFlat, hover: StyleBoxFlat, pressed_down: StyleBoxFlat) -> void:
		_unpressed = standard
		_hover = hover
		_clicked = pressed_down

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		
		if mouse_event.pressed:
			add_theme_stylebox_override("panel", _clicked)
			pressed.emit()
		else:
			add_theme_stylebox_override("panel", _hover)
		
func _mouse_entered() -> void:
	add_theme_stylebox_override("panel", _hover)

func _mouse_exited() -> void:
	add_theme_stylebox_override("panel", _unpressed)
