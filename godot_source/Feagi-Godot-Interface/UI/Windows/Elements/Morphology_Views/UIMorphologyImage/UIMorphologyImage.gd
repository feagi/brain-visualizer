extends TextureRect
class_name UIMorphologyImage

const MORPHOLOGY_ICON_PATH: StringName = &"res://Feagi-Godot-Interface/UI/Resources/morphology_icons/"

var _loaded_morphology: Morphology
var _available_morphology_images: PackedStringArray


func _ready() -> void:
	_available_morphology_images = DirAccess.get_files_at(MORPHOLOGY_ICON_PATH)


func load_morphology(morphology: Morphology) -> void:
	_loaded_morphology = morphology
	_update_image_with_morphology(_loaded_morphology.name)

func clear_morphology() -> void:
	_loaded_morphology = null
	visible = false

# TODO maybe instead render an empty area? as an option?




## Updates the image of the morphology (if no image, just hides this object)
func _update_image_with_morphology(morphology_name: StringName) -> void:
	var morphology_image_name: StringName = morphology_name + &".png"
	var index: int = _available_morphology_images.find(morphology_image_name)
	if index == -1:
		# no image found
		visible = false
		return

	visible = true
	texture = load(MORPHOLOGY_ICON_PATH + morphology_image_name)
