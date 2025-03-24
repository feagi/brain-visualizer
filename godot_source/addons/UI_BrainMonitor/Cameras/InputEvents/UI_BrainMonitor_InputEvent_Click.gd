extends UI_BrainMonitor_InputEvent_Abstract
class_name UI_BrainMonitor_InputEvent_Click
## Emitted as pointer changes "click" state somewhere

var button: CLICK_BUTTON # NOTE: In the case of release, will not be set to "NONE", instead this will be the button that was released!
var button_pressed: bool # is the button starting to be pressed (false if being released)
var button_double_clicked: bool # was the button being double clicked (only possible if being pressed)
var was_dragging: bool = false # were we dragging this button before this event? Only true when the last held button is released!

func _init(buttons_being_held: Array[CLICK_BUTTON], start_position: Vector3, end_position: Vector3, is_pressed: bool, is_double_clicked: bool, button_involved: CLICK_BUTTON, was_previously_dragging: bool = false):
	all_buttons_being_held = buttons_being_held
	ray_start_point = start_position
	ray_end_point = end_position
	button_pressed = is_pressed
	button_double_clicked = is_double_clicked
	button = button_involved
	was_dragging = was_previously_dragging
