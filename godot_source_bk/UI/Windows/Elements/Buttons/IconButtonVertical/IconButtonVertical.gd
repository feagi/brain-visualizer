extends Button
class_name IconButtonVertical
## Button with icon and text. more configurable than the stock button system

## Paddings on the top, right, bottom, and right, in that order
@export var top_right_bottom_left_paddings: Vector4i

@export var texture: Texture2D

## The dimensions of the texture
@export var texture_size: Vector2i

## The Text to start with
@export var button_text: StringName

@export var gap_between_text_and_texture: int

@export var text_alignment: HorizontalAlignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT

@export var clip_text_label: bool = false


func _ready() -> void:
	#Set gaps
	$VBoxContainer/topgap.custom_minimum_size.y = top_right_bottom_left_paddings.x
	$VBoxContainer/bottomgap.custom_minimum_size.y = top_right_bottom_left_paddings.z
	$VBoxContainer/BoxContainer/MarginContainer.add_theme_constant_override("margin_left", top_right_bottom_left_paddings.w)
	$VBoxContainer/BoxContainer/MarginContainer.add_theme_constant_override("margin_right", top_right_bottom_left_paddings.y)
	
	
	var label: Label = $VBoxContainer/BoxContainer/Label
	var texture_icon: TextureRect = $VBoxContainer/BoxContainer/MarginContainer/TextureRect
	var top_container: VBoxContainer = $VBoxContainer
	
	label.text = button_text
	label.horizontal_alignment = text_alignment
	label.clip_text = clip_text_label
	
	texture_icon.texture = texture
	texture_icon.custom_minimum_size = texture_size
	
	top_container.resized.connect(_child_resized)

func _child_resized():
	size = Vector2i(0,0)
	custom_minimum_size = $VBoxContainer.size
