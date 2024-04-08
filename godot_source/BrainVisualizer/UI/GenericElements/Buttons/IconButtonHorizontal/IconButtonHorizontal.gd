extends Button
class_name IconButtonHorizontal
## Button with icon and text. more configurable than the stock button system

var _margin: MarginContainer
var _box: BoxContainer
var _texture_rect: TextureRect
var _gap: Control
var _text: Label
var _default_font_size: int

## Paddings on the top, right, bottom, and right, in that order
@export var top_right_bottom_left_paddings: Vector4i

@export var texture: Texture2D

## The default dimensions of the texture
@export var texture_size: Vector2i

## The Text to start with
@export var button_text: StringName

@export var gap_between_text_and_texture: int

@export var text_alignment: HorizontalAlignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT

@export var clip_text_label: bool = false


func _ready() -> void:
	_margin = $MarginContainer
	_box = $MarginContainer/BoxContainer
	_texture_rect = $MarginContainer/BoxContainer/TextureRect
	_gap = $MarginContainer/BoxContainer/Gap
	_text = $MarginContainer/BoxContainer/Label
	
	_default_font_size = _text.get_theme_font_size(&"font_size")
	
	_text.text = button_text
	_text.horizontal_alignment = text_alignment
	_text.clip_text = clip_text_label
	
	_texture_rect.texture = texture
	
	custom_minimum_size = _margin.custom_minimum_size

