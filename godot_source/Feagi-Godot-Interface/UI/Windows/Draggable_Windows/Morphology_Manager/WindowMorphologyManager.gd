extends DraggableWindow
class_name WindowMorphologyManager

var _UI_morphology_overviews: UIMorphologyOverviews

func _ready() -> void:
	super()
	_UI_morphology_overviews = $UIMorphologyOverviews
	_UI_morphology_overviews.minimum_size_changed.connect(_update_size)
	_UI_morphology_overviews.request_close.connect(VisConfig.UI_manager.window_manager.force_close_window.bind("morphology_manager"))

func _update_size() -> void:
	size = _UI_morphology_overviews.size
