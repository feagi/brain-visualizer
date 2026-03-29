extends BaseDraggableWindow
class_name WindowCameraAnimations

## Dedicated window for camera animation tooling.
## This window hosts the existing camera animation panel that was previously embedded in Settings.

const WINDOW_NAME: StringName = "camera_animations"


func _ready() -> void:
	super()


func setup(host_brain_monitor: UI_BrainMonitor_3DScene = null) -> void:
	_setup_base_window(WINDOW_NAME)
	var part: WindowDeveloperOptionsPartCameraAnimations = $WindowPanel/WindowMargin/WindowInternals/CameraAnimations as WindowDeveloperOptionsPartCameraAnimations
	if part != null:
		var bm: UI_BrainMonitor_3DScene = host_brain_monitor if host_brain_monitor != null else BV.UI.get_active_brain_monitor()
		part.configure_from_brain_monitor(bm)

