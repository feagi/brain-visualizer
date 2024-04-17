extends BasePanelContainerButton
class_name DetailedPanelContainerButton

@export var icon: Texture
@export var icon_size: Vector2i
@export var main_label: StringName
@export var description_label: StringName
@export var is_vertical: bool


func _ready() -> void:
	super()
	var box: BoxContainer = $MarginContainer/BoxContainer
	var texture_rect: TextureRect = $MarginContainer/BoxContainer/TextureRect
	var main_text: Label = $MarginContainer/BoxContainer/Label
	var second_text: RichTextLabel = $MarginContainer/BoxContainer/RichTextLabel
	texture_rect.texture = icon
	main_text.text = main_label
	second_text.text = description_label #NOTE: Not queuing free if empty due to gap in boxcontainer
	box.vertical = is_vertical
	update_theme_params()
	BV.UI.theme_changed.connect(update_theme_params)
	

func update_theme_params(_new_theme = null):
	var texture_rect: TextureRect = $MarginContainer/BoxContainer/TextureRect
	var gap1: Control = $MarginContainer/BoxContainer/g1
	var gap2: Control = $MarginContainer/BoxContainer/g2
	
	texture_rect.custom_minimum_size = icon_size * BV.UI.loaded_theme_scale.x
	if is_vertical:
		gap1.custom_minimum_size.y = BV.UI.get_minimum_size_from_loaded_theme("Gap_medium").y
		gap2.custom_minimum_size.y = BV.UI.get_minimum_size_from_loaded_theme("Gap_medium").y
	else:
		gap1.custom_minimum_size.x = BV.UI.get_minimum_size_from_loaded_theme("Gap_medium").x
		gap2.custom_minimum_size.x = BV.UI.get_minimum_size_from_loaded_theme("Gap_medium").x
	
