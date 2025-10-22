extends UI_BrainMonitor_InputEvent_Abstract
class_name UI_BrainMonitor_InputEvent_Hover
## Emitted as pointer moves across the screen, possibly dragging



func _init(buttons_being_held: Array[CLICK_BUTTON], start_position: Vector3, end_position: Vector3):
	all_buttons_being_held = buttons_being_held
	ray_start_point = start_position
	ray_end_point = end_position
