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
		if !get_global_rect().has_point(get_global_mouse_position()): # check if mouse is in button. WARNING: Does not check if control is on top, so in that case this fails!
			return
		
		if mouse_event.pressed:
			if has_theme_stylebox("panel_pressed", "PanelContainerButton"):
				add_theme_stylebox_override("panel", get_theme_stylebox("panel_pressed", "PanelContainerButton"))
			else:
				push_error("Missing panel_pressed for PanelContainerButton")
			pressed.emit()
		else:
			if has_theme_stylebox("panel_hover", "PanelContainerButton"):
				add_theme_stylebox_override("panel", get_theme_stylebox("panel_hover", "PanelContainerButton"))
			else:
				push_error("Missing panel_hover for PanelContainerButton")
		
func _mouse_entered() -> void:
	if has_theme_stylebox("panel_hover", "PanelContainerButton"):
		add_theme_stylebox_override("panel", get_theme_stylebox("panel_hover", "PanelContainerButton"))
	else:
		push_error("Missing panel_hover for PanelContainerButton")

func _mouse_exited() -> void:
	if has_theme_stylebox("panel", "PanelContainerButton"):
		add_theme_stylebox_override("panel", get_theme_stylebox("panel", "PanelContainerButton"))
	else:
		push_error("Missing panel for PanelContainerButton")
