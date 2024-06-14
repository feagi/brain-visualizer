extends TextureRect
class_name ButtonTextureRectScaling
## Essentially a recreation of [TextureButton] using [TextureRect] as a base so we get access for its better scaling funcitonality. A stand in until the scalaing features are ported natively
#TODO Toggle Support

@export var texture_normal: Texture2D = null
@export var texture_pressed: Texture2D = null
@export var texture_hover: Texture2D = null
@export var texture_disabled: Texture2D = null
@export var disabled: bool:
	get: return _disabled
	set(v):
		_disabled = v
		_set_appropriate_texture(_disabled, _hovered, Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))

signal pressed()

var _pressed: bool = false
var _hovered: bool = false
var _disabled: bool = false

func _init():
	disabled = disabled # The wonders of OOP!

func _ready() -> void:
	mouse_entered.connect(_mouse_entered)
	mouse_exited.connect(_mouse_exited)
	_set_appropriate_texture(disabled, false, false)

func _gui_input(event: InputEvent) -> void:
	if _disabled:
		return
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if !_hovered:
			return
		_set_appropriate_texture(_disabled, _hovered, mouse_event.pressed)
		pressed.emit()

func is_hovered() -> bool:
	return _hovered

func is_clicking() -> bool:
	if !_hovered:
		return false
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

func _mouse_entered() -> void:
	_hovered = true
	_set_appropriate_texture(_disabled, _hovered, Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))

func _mouse_exited() -> void:
	_hovered = false
	_set_appropriate_texture(_disabled, _hovered, Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))

func _set_appropriate_texture(is_disabled: bool, is_hovering: bool, is_clicking: bool) -> void:
	if is_disabled:
		if texture_disabled == null:
			push_error("Missing texture_disabled for ButtonTextureRectScaling")
		else:
			texture = texture_disabled
		return
	if is_hovering:
		if is_clicking:
			if texture_pressed == null:
				push_error("Missing texture_pressed for ButtonTextureRectScaling")
			else:
				texture = texture_pressed
			return
		if texture_hover == null:
			push_error("Missing texture_hover for ButtonTextureRectScaling")
		else:
			texture = texture_hover
		return
	if texture_normal == null:
		push_error("Missing texture_normal for ButtonTextureRectScaling")
	else:
		texture = texture_normal

