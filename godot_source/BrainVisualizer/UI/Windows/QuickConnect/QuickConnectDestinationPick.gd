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


## The live line follows a cortical volume behind a region shell or plate.
## An empty result means the pointer is not on an area, so the line must not stick to that shell.
static func guide_follows_cortical_hit(has_cortical_hit: bool) -> bool:
	return has_cortical_hit


## Cancel and window close must clear the monitor that drew the line.
## That monitor can be the region view showing an outside area on a plate, not the area's parent monitor.
static func must_stop_guide_on_scene(scene_started_guide: bool, scene_owns_source_area: bool, scene_is_visible: bool) -> bool:
	return scene_started_guide or scene_owns_source_area or scene_is_visible
