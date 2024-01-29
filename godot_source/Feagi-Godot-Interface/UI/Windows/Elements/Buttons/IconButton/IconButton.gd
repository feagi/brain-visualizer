extends Button
class_name IconButton
## Button with icon and text. more configurable than the stock button system

var _margin: MarginContainer
var _box: BoxContainer
var _texture_rect: TextureRect
var _gap: Control
var _text: Label

## Paddings on the top, right, bottom, and right, in that order
@export var top_right_bottom_left_paddings: Vector4i

## IFf the button is laid out horizontally
@export var is_vertical: bool

@export var texture: Texture2D

## The dimensions of the texture
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
	
	_margin.add_theme_constant_override("margin_top", top_right_bottom_left_paddings.x)
	_margin.add_theme_constant_override("margin_left", top_right_bottom_left_paddings.w)
	_margin.add_theme_constant_override("margin_bottom", top_right_bottom_left_paddings.z)
	_margin.add_theme_constant_override("margin_right", top_right_bottom_left_paddings.y)
	
	_box.vertical = is_vertical
	if is_vertical:
		_gap.custom_minimum_size = Vector2(0, gap_between_text_and_texture)
	else:
		_gap.custom_minimum_size = Vector2(gap_between_text_and_texture, 0)
	
	_text.text = button_text
	_text.horizontal_alignment = text_alignment
	_text.clip_text = clip_text_label
	
	_texture_rect.texture = texture
	_texture_rect.custom_minimum_size = texture_size
	
	custom_minimum_size = _margin.custom_minimum_size
	_margin.minimum_size_changed.connect(_child_min_size_change)
	
func _child_min_size_change() -> void:
	custom_minimum_size = _margin.size
