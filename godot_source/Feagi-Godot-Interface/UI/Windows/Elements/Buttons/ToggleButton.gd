extends ScalingTextureButton
class_name ToggleButton

const TEX_DISABLED_ON: Texture = preload("res://Feagi-Godot-Interface/UI/Resources/Icons/toggle_on_disabled.png")
const TEX_DISABLED_OFF: Texture = preload("res://Feagi-Godot-Interface/UI/Resources/Icons/toggle_disabled.png")
const TEX_ENABLED_ON: Texture = preload("res://Feagi-Godot-Interface/UI/Resources/Icons/toggle_on.png")
const TEX_ENABLED_OFF: Texture = preload("res://Feagi-Godot-Interface/UI/Resources/Icons/toggle_off.png")

# Called when the node enters the scene tree for the first time.
func _ready():
	super()
	toggle_mode = true
	toggled.connect(_set_enable_toggle)
	_set_enable_toggle(button_pressed)
	

## USE THIS INSTEAD OF SET_PRESSED_NO_SIGNAL! If only I could actually override this shit
func set_toggle_no_signal(val: bool) -> void:
	_set_enable_toggle(val)
	set_pressed_no_signal(val)

func _set_enable_toggle(is_press: bool) -> void:
	if is_press:
		texture_disabled = TEX_DISABLED_ON
		texture_hover = TEX_ENABLED_ON
		texture_normal = TEX_ENABLED_ON
		texture_pressed = TEX_ENABLED_ON
	else:
		texture_disabled = TEX_DISABLED_OFF
		texture_hover = TEX_ENABLED_OFF
		texture_normal = TEX_ENABLED_OFF
		texture_pressed = TEX_ENABLED_OFF
