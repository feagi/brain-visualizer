extends RefCounted
class_name QuickConnectDestinationPick
## Rules for choosing a Quick Connect destination by mouse click.
## Cortical Area Explorer stays available from the Edit button.


enum STEP {
	SOURCE,
	DESTINATION,
	MORPHOLOGY,
	EDIT_MORPHOLOGY,
	IDLE,
}


## Source picking is a separate step. Destination, rule, and review steps still accept a click.
static func accepts_mouse_destination_click(state: int) -> bool:
	return state == STEP.DESTINATION or state == STEP.MORPHOLOGY or state == STEP.IDLE


## Region plate colliders sit in front of areas. Quick Connect must hit the area instead.
static func click_prefers_cortical_volume(area_quick_connect: bool, neuron_quick_connect: bool) -> bool:
	return area_quick_connect or neuron_quick_connect
