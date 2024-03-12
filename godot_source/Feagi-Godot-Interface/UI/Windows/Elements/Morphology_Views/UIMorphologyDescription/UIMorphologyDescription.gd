extends TextEdit
class_name UIMorphologyDescription

var _loaded_morphology: Morphology
var _default_font_size: int
var _default_min_size: Vector2

func _ready() -> void:
	_default_font_size = get_theme_font_size(&"font_size")
	_default_min_size = custom_minimum_size
	_update_size(VisConfig.UI_manager.UI_scale)
	VisConfig.UI_manager.UI_scale_changed.connect(_update_size)

func load_morphology(morphology: Morphology) -> void:
	if _loaded_morphology != null:
		if _loaded_morphology.retrieved_description.is_connected(_description_updated):
			_loaded_morphology.retrieved_description.disconnect(_description_updated)
	_loaded_morphology = morphology
	text = morphology.description
	#TODO enable editing?

func clear_morphology() -> void:
	_loaded_morphology = null
	text = ""
	editable = false

func _description_updated(new_description: StringName, _self_reference: Morphology) -> void:
	text = new_description

func _update_size(multiplier: float) -> void:
	add_theme_font_size_override(&"font_size", int(float(_default_font_size) * multiplier))
	custom_minimum_size = _default_min_size * multiplier
	size = Vector2(0,0)
