extends PanelContainer
class_name PanelContainerButton
## Essentially a replica of [BaseButton] but as a [PanelCOntainer] you can put items inside of
#TODO toggle support

signal pressed()

@export var disabled: bool:
	get: return _disabled
	set(v):
		_disabled = v
		_set_appropriate_stylebox(_disabled, _hovered, Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))

var _pressed: bool = false
var _hovered: bool = false
var _disabled: bool = false


func _init():
	disabled = disabled # cursed property shenigans lol

func _ready() -> void:
	mouse_entered.connect(_mouse_entered)
	mouse_exited.connect(_mouse_exited)
	_set_appropriate_stylebox(disabled, false, false)

func _gui_input(event: InputEvent) -> void:
	if _disabled:
		return
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if !_hovered:
			return
		_set_appropriate_stylebox(_disabled, _hovered, mouse_event.pressed)
		pressed.emit()

func is_hovered() -> bool:
	return _hovered

func is_clicking() -> bool:
	if !_hovered:
		return false
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

func _mouse_entered() -> void:
	_hovered = true
	_set_appropriate_stylebox(_disabled, _hovered, Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))

func _mouse_exited() -> void:
	_hovered = false
	_set_appropriate_stylebox(_disabled, _hovered, Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))

func _set_appropriate_stylebox(is_button_disabled: bool, is_mouse_hovering: bool, is_user_clicking_down: bool) -> void:
	if is_button_disabled:
		if has_theme_stylebox("panel_disabled", "PanelContainerButton"):
			add_theme_stylebox_override("panel", get_theme_stylebox("panel_disabled", "PanelContainerButton"))
		else:
			push_error("Missing panel_disabled for PanelContainerButton")
		return
	if is_mouse_hovering:
		if is_user_clicking_down:
			if has_theme_stylebox("panel_pressed", "PanelContainerButton"):
				add_theme_stylebox_override("panel", get_theme_stylebox("panel_pressed", "PanelContainerButton"))
			else:
				push_error("Missing panel_pressed for PanelContainerButton")
			return
		if has_theme_stylebox("panel_hover", "PanelContainerButton"):
			add_theme_stylebox_override("panel", get_theme_stylebox("panel_hover", "PanelContainerButton"))
		else:
			push_error("Missing panel_hover for PanelContainerButton")
		return

	# button just chilling
	if has_theme_stylebox("panel", "PanelContainerButton"):
		add_theme_stylebox_override("panel", get_theme_stylebox("panel", "PanelContainerButton"))
	else:
		push_error("Missing panel for PanelContainerButton")
