extends PanelContainer
class_name BasePanelContainerButton

signal pressed()

func _ready() -> void:
	mouse_entered.connect(_mouse_entered)
	mouse_exited.connect(_mouse_exited)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if !get_global_rect().has_point(get_global_mouse_position()): # check if mouse is in button. FIXME: Does not check if control is on top, so in that case this fails!
			return
		
		if mouse_event.pressed:
			if has_theme_stylebox("panel_pressed", "BasePanelContainerButton"):
				add_theme_stylebox_override("panel", get_theme_stylebox("panel_pressed", "BasePanelContainerButton"))
			else:
				push_error("Missing panel_pressed for BasePanelContainerButton")
			pressed.emit()
		else:
			if has_theme_stylebox("panel_hover", "BasePanelContainerButton"):
				add_theme_stylebox_override("panel", get_theme_stylebox("panel_hover", "BasePanelContainerButton"))
			else:
				push_error("Missing panel_hover for BasePanelContainerButton")
		
func _mouse_entered() -> void:
	if has_theme_stylebox("panel_hover", "BasePanelContainerButton"):
		add_theme_stylebox_override("panel", get_theme_stylebox("panel_hover", "BasePanelContainerButton"))
	else:
		push_error("Missing panel_hover for PanelContainerButton")

func _mouse_exited() -> void:
	if has_theme_stylebox("panel", "BasePanelContainerButton"):
		add_theme_stylebox_override("panel", get_theme_stylebox("panel", "BasePanelContainerButton"))
	else:
		push_error("Missing panel for BasePanelContainerButton")
