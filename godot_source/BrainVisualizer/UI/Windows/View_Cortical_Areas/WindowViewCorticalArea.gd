extends BaseDraggableWindow
class_name WindowViewCorticalArea

const WINDOW_NAME: StringName = "view_cortical"

func _ready() -> void:
	super()
	var cortical_list: CorticalAreaScroll = _window_internals.get_node("CorticalAreaScroll")
	cortical_list.cortical_area_selected.connect(BV.UI.snap_camera_to_cortical_area)

func setup() -> void:
	_setup_base_window(WINDOW_NAME)

func _press_add_cortical_area() -> void:
	BV.WM.spawn_create_cortical()
	close_window()
 
