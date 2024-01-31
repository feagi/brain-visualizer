extends BaseWindowPanel
class_name WindowMorphologyManager

var _UI_morphology_overviews: UIMorphologyOverviews

func _ready() -> void:
	_UI_morphology_overviews = $UIMorphologyOverviews
	_UI_morphology_overviews.request_close.connect(VisConfig.UI_manager.window_manager.force_close_window.bind("morphology_manager"))

func setup(morphology: Morphology = null) -> void:
	_setup_base_window("morphology_manager")
	if morphology != null:
		load_morphology(morphology)

func load_morphology(morphology: Morphology) -> void:
	_UI_morphology_overviews.load_morphology(morphology, true)


