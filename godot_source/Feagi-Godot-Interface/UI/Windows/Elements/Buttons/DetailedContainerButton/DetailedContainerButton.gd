extends BasePanelContainerButton
class_name DetailedContainerButton

@export var icon: Texture
@export var icon_size: Vector2i
@export var main_label: StringName
@export var main_label_font_size: int = 28
@export var description_label: StringName
@export var description_label_font_size: int = 20
@export var top_padding: int
@export var right_padding: int
@export var bottom_padding: int
@export var left_padding: int
@export var is_vertical: bool
@export var gap_1: int
@export var gap_2: int


func _ready() -> void:
	super()
	var margins: MarginContainer = $MarginContainer
	var box: BoxContainer = $MarginContainer/BoxContainer
	var texture_rect: TextureRect = $MarginContainer/BoxContainer/TextureRect
	var main_text: Label = $MarginContainer/BoxContainer/Label
	var second_text: RichTextLabel = $MarginContainer/BoxContainer/RichTextLabel
	var gap1: Control = $MarginContainer/BoxContainer/g1
	var gap2: Control = $MarginContainer/BoxContainer/g2
	
	margins.add_theme_constant_override("margin_left", left_padding)
	margins.add_theme_constant_override("margin_right", right_padding)
	margins.add_theme_constant_override("margin_top", top_padding)
	margins.add_theme_constant_override("margin_bottom", bottom_padding)
	
	texture_rect.texture = icon
	texture_rect.custom_minimum_size = icon_size
	
	main_text.text = main_label
	main_text.add_theme_font_size_override("font_size", main_label_font_size)
	
	second_text.text = description_label
	second_text.add_theme_font_size_override("font_size", description_label_font_size)
	
	box.vertical = is_vertical
	if is_vertical:
		gap1.custom_minimum_size.y = gap_1
		gap2.custom_minimum_size.y = gap_2
	else:
		gap1.custom_minimum_size.x = gap_1
		gap2.custom_minimum_size.x = gap_2
