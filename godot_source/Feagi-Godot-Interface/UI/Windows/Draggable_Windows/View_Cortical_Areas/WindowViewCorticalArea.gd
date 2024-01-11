extends DraggableWindow
class_name WindowViewCorticalArea

func _ready() -> void:
	super._ready()
	var cortical_list: CorticalAreaScroll = $VBoxContainer/CorticalAreaScroll
	cortical_list.cortical_area_selected.connect(VisConfig.UI_manager.snap_camera_to_cortical_area)

func _press_add_cortical_area() -> void:
	VisConfig.UI_manager.window_manager.spawn_create_cortical()
