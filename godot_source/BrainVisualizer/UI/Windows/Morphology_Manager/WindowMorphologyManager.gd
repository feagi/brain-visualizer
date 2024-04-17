extends BaseDraggableWindow
class_name WindowMorphologyManager

var _UI_morphology_overviews: UIMorphologyOverviews

func _ready() -> void:
	super()
	_UI_morphology_overviews = _window_internals.get_node("UIMorphologyOverviews")

func setup(morphology: BaseMorphology = null) -> void:
	_setup_base_window("morphology_manager")
	if morphology != null:
		load_morphology(morphology)

func load_morphology(morphology: BaseMorphology) -> void:
	_UI_morphology_overviews.load_morphology(morphology, true)


