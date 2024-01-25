extends BaseWindowPanel
class_name WindowMorphologyManager

var _UI_morphology_overviews: UIMorphologyOverviews

func _ready() -> void:
	_UI_morphology_overviews = $UIMorphologyOverviews
	_UI_morphology_overviews.request_close.connect(VisConfig.UI_manager.window_manager.force_close_window.bind("morphology_manager"))

func setup_window(window_name: StringName, morphology: Morphology = null) -> void:
	super(window_name)
	if morphology != null:
		load_morphology(morphology)

func load_morphology(morphology: Morphology) -> void:
	_UI_morphology_overviews.load_morphology(morphology, true)


