extends TextureButton_Element
class_name CloseButton_Element

const CLOSE_LOGO = "res://Feagi-Godot-Interface/UI/Resources/Icons/close_S.png"

func _ready():
	texture_normal = preload(CLOSE_LOGO)
