extends BaseDraggableWindow
class_name WindowDeveloperOptions

var _camera_animation_section: VerticalCollapsible

func setup() -> void:
	_setup_base_window("developer_options")
	_camera_animation_section = _window_internals.get_node("Camera_Animation")
	
	_camera_animation_section.setup()
