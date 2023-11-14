extends DraggableWindow
class_name WindowViewCorticalArea

func _ready() -> void:
	super._ready()
	var cortical_list: CorticalAreaScroll = $CorticalAreaScroll
	cortical_list.cortical_area_selected.connect(VisConfig.UI_manager.snap_camera_to_cortical_area)
