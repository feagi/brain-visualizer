extends RefCounted
## When a cortical area's 3D title is drawn.
## Every area, including invariant cores, shows its title only while hovered.


## True when the title stays on screen with no pointer over the area.
static func always_visible() -> bool:
	return false


## True when the 3D area title should be drawn this frame.
static func should_show(volume_moused_over: bool, matches_bottom_hover_line: bool) -> bool:
	if always_visible():
		return true
	return volume_moused_over or matches_bottom_hover_line
