extends BaseDraggableWindow
class_name WindowCameraAnimations

## Dedicated window for camera animation tooling.
## This window hosts the existing camera animation panel that was previously embedded in Settings.

const WINDOW_NAME: StringName = "camera_animations"


func _ready() -> void:
	super()


func setup() -> void:
	_setup_base_window(WINDOW_NAME)

