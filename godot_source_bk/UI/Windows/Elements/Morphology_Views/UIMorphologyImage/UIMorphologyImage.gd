extends TextureRect
class_name UIMorphologyImage

const MORPHOLOGY_ICON_PATH: StringName = &"res://Feagi-Godot-Interface/UI/Resources/morphology_icons/"

var _loaded_morphology: Morphology
var _available_morphology_images: PackedStringArray
var _default_custom_minimum_size: Vector2i


func _ready() -> void:
	_available_morphology_images = DirAccess.get_files_at(MORPHOLOGY_ICON_PATH)
	_default_custom_minimum_size = custom_minimum_size
	_update_size(VisConfig.UI_manager.UI_scale)
	VisConfig.UI_manager.UI_scale_changed.connect(_update_size)

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

func _update_size(multiplier: float) -> void:
	custom_minimum_size = Vector2i(_default_custom_minimum_size * multiplier)
	size = Vector2(0,0)
