extends BasePanelContainerButton
class_name DetailedPanelContainerButton

@export var icon: Texture
@export var icon_size: Vector2i
@export var main_label: StringName
@export var description_label: StringName
@export var is_vertical: bool



func _notification(what):
	if what == NOTIFICATION_THEME_CHANGED:
		external_update_theme_params()

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
	external_update_theme_params()

func external_update_theme_params():
	if !(has_theme_constant("gap_1", "DetailedPanelContainerButton") and has_theme_constant("gap_2", "DetailedPanelContainerButton") and 
	has_theme_constant("scale_times_16", "DetailedPanelContainerButton")):
		push_error("Theme is missing properties for DetailedPanelContainerButton!")
		return
	
	var texture_rect: TextureRect = $MarginContainer/BoxContainer/TextureRect
	var gap1: Control = $MarginContainer/BoxContainer/g1
	var gap2: Control = $MarginContainer/BoxContainer/g2
	
	texture_rect.custom_minimum_size = icon_size * (float(get_theme_constant("scale_times_16", "DetailedPanelContainerButton")) / 16.0)
	
	if is_vertical:
		gap1.custom_minimum_size.y = get_theme_constant("gap_1", "DetailedPanelContainerButton")
		gap2.custom_minimum_size.y = get_theme_constant("gap_2", "DetailedPanelContainerButton")
	else:
		gap1.custom_minimum_size.x = get_theme_constant("gap_1", "DetailedPanelContainerButton")
		gap2.custom_minimum_size.x = get_theme_constant("gap_2", "DetailedPanelContainerButton")

