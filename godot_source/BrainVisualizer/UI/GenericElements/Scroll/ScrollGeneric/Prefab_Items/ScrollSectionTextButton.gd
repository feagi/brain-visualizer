extends Node
class_name ScrollSectionTextButton

const HOVER_THEME_VARIATION_AFFIX: StringName = "_highlighted"

var _text_button_ref: Button
var _default_theme_variation: StringName

func _ready():
	_text_button_ref = get_child(0)
	_default_theme_variation = _text_button_ref.theme_type_variation

func set_text(text: StringName) -> void:
	_text_button_ref.text = text

func set_highlighting(is_higlighted: bool) -> void:
	if is_higlighted:
		_text_button_ref.theme_type_variation = _default_theme_variation
	else:
		_text_button_ref.theme_type_variation = _default_theme_variation + HOVER_THEME_VARIATION_AFFIX

