extends BaseDraggableWindow
class_name WindowMorphologyManager

var _UI_morphology_overviews: UIMorphologyOverviews

func _ready() -> void:
	super()
	_UI_morphology_overviews = _window_internals.get_node("UIMorphologyOverviews")
	###_UI_morphology_overviews.request_close.connect(VisConfig.UI_manager.window_manager.force_close_window.bind("morphology_manager"))

func setup(morphology: BaseMorphology = null) -> void:
	_setup_base_window("morphology_manager")
	if morphology != null:
		load_morphology(morphology)

func load_morphology(morphology: BaseMorphology) -> void:
	_UI_morphology_overviews.load_morphology(morphology, true)


