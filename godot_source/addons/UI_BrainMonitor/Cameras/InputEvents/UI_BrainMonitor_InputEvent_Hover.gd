extends UI_BrainMonitor_InputEvent_Abstract
class_name UI_BrainMonitor_InputEvent_Hover
## Emitted as pointer moves across the screen, possibly dragging


var is_dragging: bool = false # is a click button being held down?
var dragging_buttons: Array[CLICK_BUTTON] # only relevant if a button is being clicked, otherwise will be NONE

func _init(start_position: Vector3, end_position: Vector3, dragging_buttons_clicked: Array[CLICK_BUTTON] = []):
	ray_start_point = start_position
	ray_end_point = end_position
	dragging_buttons = dragging_buttons_clicked
	is_dragging = !dragging_buttons_clicked.is_empty()
