extends BaseDraggableWindow
class_name WindowViewCorticalArea

func _ready() -> void:
	super()
	var cortical_list: CorticalAreaScroll = _window_internals.get_node("CorticalAreaScroll")
	###cortical_list.cortical_area_selected.connect(VisConfig.UI_manager.snap_camera_to_cortical_area)

func setup() -> void:
	_setup_base_window("view_cortical")

func _press_add_cortical_area() -> void:
	pass
	###VisConfig.UI_manager.window_manager.spawn_create_cortical()
	close_window()
 
