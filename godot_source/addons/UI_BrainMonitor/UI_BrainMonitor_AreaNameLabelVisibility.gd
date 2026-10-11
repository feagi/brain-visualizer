extends RefCounted
## When a cortical area's 3D title is drawn.
## Every area, including invariant cores, shows its title while hovered or while the focus arrow points at it.


## True when the title stays on screen with no pointer over the area.
static func always_visible() -> bool:
	return false


## True when the 3D area title should be drawn this frame.
## [param focus_indicator_holding] is true for as long as the focus arrow points at this area.
static func should_show(volume_moused_over: bool, matches_bottom_hover_line: bool, focus_indicator_holding: bool = false) -> bool:
	if always_visible():
		return true
	return volume_moused_over or matches_bottom_hover_line or focus_indicator_holding
