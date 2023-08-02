extends TextureButton
class_name TextureButton_Sub

signal value_edited(bool)

var editable: bool:
	get: return !disabled
	set(v): disabled = !v

func _ready():
	pressed.connect(_PressProxy)

func _PressProxy():
	value_edited.emit(true) # we need some sort of value in here

# built in vars
# flip_h: bool
# flip_v: bool
# ignore_texture_size: bool
# stretch_mode: StretchMode (int)
# texture_click_mask: BitMap
# texture_disabled: Texture2D
# texture_focused: Texture2D
# texture_hover: Texture2D
# texture_normal: Texture2D
# texture_pressed: Texture2D
