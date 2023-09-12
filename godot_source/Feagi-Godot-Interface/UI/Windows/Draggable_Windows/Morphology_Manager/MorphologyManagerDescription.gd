extends VBoxContainer
class_name MorphologyManagerDescription

const MORPHOLOGY_ICON_PATH: StringName = &"res://Feagi-Godot-Interface/UI/Resources/morphology_icons/"

var _available_morphology_images: PackedStringArray

var _texture_rect: TextureRect


func _ready() -> void:
	_available_morphology_images = DirAccess.get_files_at(MORPHOLOGY_ICON_PATH)
	_texture_rect = $Morphology_Texture

## Updates the image of the description 
func update_image_with_morphology(morphology_name: StringName) -> void:
	var morphology_image_name: StringName = morphology_name + &".png"
	var index: int = _available_morphology_images.find(morphology_image_name)

	if index == -1:
		# no image found
		_texture_rect.visible = false
		return
	_texture_rect.visible = true
	_texture_rect.texture = load(MORPHOLOGY_ICON_PATH + morphology_image_name)
