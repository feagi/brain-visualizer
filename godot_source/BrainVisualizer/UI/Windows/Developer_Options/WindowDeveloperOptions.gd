extends BaseDraggableWindow
class_name WindowDeveloperOptions

const WINDOW_NAME: StringName = "developer_options"

var _camera_animation_section: VerticalCollapsible

func setup() -> void:
	_setup_base_window(WINDOW_NAME)
	_camera_animation_section = _window_internals.get_node("Camera_Animation")
	
	_camera_animation_section.setup()
