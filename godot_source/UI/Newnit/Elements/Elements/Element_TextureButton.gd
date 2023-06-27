extends Element_Base
class_name Element_TextureButton
# Yes, you can technically enable the sideButton for this Button element if you wanted to

const D_editable = true
const D_flip_h = false
const D_flip_v = false
const D_ignore_texture_size = true
const D_stretch_mode = 0
const D_manual_size_flags_vertical = 8
const D_manual_size_flags_horizontal = 8
const D_internal_custom_minimum_size = Vector2(20,20)

const _specificSettableProps := {
	"editable": TYPE_BOOL,
	"text": TYPE_STRING,
	"flip_h": TYPE_BOOL,
	"flip_v": TYPE_BOOL,
	"ignore_texture_size": TYPE_BOOL,
	"stretch_mode": TYPE_INT,
	"manual_size_flags_vertical": TYPE_INT,
	"manual_size_flags_horizontal": TYPE_INT
}

var value: bool:
	get: return _Button.button_pressed

var editable: bool:
	get: return _Button.editable
	set(v): _Button.editable = v

var flip_h: bool:
	get: return _Button.flip_h
	set(v): _Button.flip_h = v

var flip_v: bool:
	get: return _Button.flip_v
	set(v): _Button.flip_v = v

var ignore_texture_size: bool:
	get: return _Button.ignore_texture_size
	set(v): _Button.ignore_texture_size = v

var stretch_mode: int:
	get: return _Button.stretch_mode
	set(v): _Button.stretch_mode = v

var manual_size_flags_vertical: int:
	get: return _Button.size_flags_vertical
	set(v): _Button.size_flags_vertical = v

var manual_size_flags_horizontal: int:
	get: return _Button.size_flags_horizontal
	set(v): _Button.size_flags_horizontal = v

var internal_custom_minimum_size: Vector2:
	get: return _Button.custom_minimum_size
	set(v): _Button.custom_minimum_size = v

var _Button: TextureButton_Sub

func LoadTextureFromPath(path: String) -> void:
	_Button.texture_normal = load(path)

func SetClickMask(clickMask: BitMap) -> void:
	_Button.texture_click_mask = clickMask

func _ActivationSecondary(settings: Dictionary) -> void:
	if(_has_label): _Button = get_children()[1]
	else: _Button = get_children()[0]
	editable = HelperFuncs.GetIfCan(settings, "editable", D_editable)
	flip_h = HelperFuncs.GetIfCan(settings, "flip_h", D_flip_h)
	flip_v = HelperFuncs.GetIfCan(settings, "flip_v", D_flip_v)
	ignore_texture_size = HelperFuncs.GetIfCan(settings, "ignore_texture_size", D_ignore_texture_size)
	stretch_mode = HelperFuncs.GetIfCan(settings, "stretch_mode", D_stretch_mode)
	manual_size_flags_vertical = HelperFuncs.GetIfCan(settings, "manual_size_flags_vertical", D_manual_size_flags_vertical)
	manual_size_flags_horizontal = HelperFuncs.GetIfCan(settings, "manual_size_flags_horizontal", D_manual_size_flags_horizontal)
	internal_custom_minimum_size = HelperFuncs.GetIfCan(settings, "internal_custom_minimum_size", D_internal_custom_minimum_size)
	if "default_texture_path" in settings.keys():
		LoadTextureFromPath(settings["default_texture_path"])
	_runtimeSettableProperties.merge(_specificSettableProps)

func _PopulateSubElements() -> Array:
	# used during Activation Primary to add Counter
	return ["textureButton"]

func _getChildData() -> Dictionary:
	return {
		"value": value,
	}

func _DataUpProxy(_data) -> void:
	DataUp.emit({"value": true}, ID, self)
