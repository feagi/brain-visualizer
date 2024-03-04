extends BasePanelContainerButton
class_name DetailedContainerButton

@export var icon: Texture
@export var icon_size: Vector2i
@export var main_label: StringName
@export var main_label_font_size: int = 28
@export var description_label: StringName
@export var description_label_font_size: int = 20
@export var top_padding: int = 16
@export var right_padding: int = 16
@export var bottom_padding: int = 16
@export var left_padding: int = 16
@export var is_vertical: bool
@export var gap_1: int
@export var gap_2: int

var _margins: MarginContainer
var _box: BoxContainer
var _texture_rect: TextureRect
var _main_text: Label
var _second_text: RichTextLabel
var _gap1: Control
var _gap2: Control


func _ready() -> void:
	super()
	_margins = $MarginContainer
	_box = $MarginContainer/BoxContainer
	_texture_rect = $MarginContainer/BoxContainer/TextureRect
	_main_text = $MarginContainer/BoxContainer/Label
	_second_text = $MarginContainer/BoxContainer/RichTextLabel
	_gap1 = $MarginContainer/BoxContainer/g1
	_gap2 = $MarginContainer/BoxContainer/g2
	
	_texture_rect.texture = icon
	
	_main_text.text = main_label
	
	if description_label == &"":
		_second_text.queue_free()
	else:
		_second_text.text = description_label
	
	_box.vertical = is_vertical
	if is_vertical:
		_gap1.custom_minimum_size.y = gap_1
		_gap2.custom_minimum_size.y = gap_2
	else:
		_gap1.custom_minimum_size.x = gap_1
		_gap2.custom_minimum_size.x = gap_2
	
	_update_size(VisConfig.UI_manager.UI_scale)
	VisConfig.UI_manager.UI_scale_changed.connect(_update_size)
	

func _update_size(multiplier: float) -> void:
	_main_text.add_theme_font_size_override(&"font_size", int(float(main_label_font_size) * multiplier))
	
	_texture_rect.custom_minimum_size = Vector2i(Vector2(icon_size) * multiplier)
	_texture_rect.size = Vector2(0,0)
	
	if is_vertical:
		_gap1.custom_minimum_size.y = int(float(gap_1) * multiplier)
		_gap2.custom_minimum_size.y = int(float(gap_2) * multiplier)
		_gap1.size = Vector2(0,0)
		_gap2.size = Vector2(0,0)
	else:
		_gap1.custom_minimum_size.x = int(float(gap_1) * multiplier)
		_gap2.custom_minimum_size.x = int(float(gap_2) * multiplier)
		_gap1.size = Vector2(0,0)
		_gap2.size = Vector2(0,0)
	
	_second_text.add_theme_font_size_override(&"normal_font_size", int(float(description_label_font_size) * multiplier))
	
	_margins.add_theme_constant_override("margin_top", int(float(top_padding) * multiplier))
	_margins.add_theme_constant_override("margin_left", int(float(left_padding) * multiplier))
	_margins.add_theme_constant_override("margin_bottom", int(float(bottom_padding) * multiplier))
	_margins.add_theme_constant_override("margin_right", int(float(right_padding) * multiplier))
