extends PanelContainer
class_name BasePanelContainerButton
#TODO replace all references to me with the new one


signal pressed()

@export var moused_over: StyleBox
@export var clicked: StyleBox

var _unpressed_style: StyleBox

func _ready() -> void:
	_unpressed_style = get_theme_stylebox("panel")
	mouse_entered.connect(_mouse_entered)
	mouse_exited.connect(_mouse_exited)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		
		if mouse_event.pressed:
			add_theme_stylebox_override("panel", clicked)
			pressed.emit()
		else:
			add_theme_stylebox_override("panel", moused_over)
		
func _mouse_entered() -> void:
	add_theme_stylebox_override("panel", moused_over)

func _mouse_exited() -> void:
	add_theme_stylebox_override("panel", _unpressed_style)
