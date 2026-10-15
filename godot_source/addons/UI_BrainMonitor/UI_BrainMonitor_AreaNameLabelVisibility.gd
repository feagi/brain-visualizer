extends RefCounted
## When a cortical area's 3D title is drawn.
## Every area, including invariant cores, shows its title while hovered, while the focus arrow points at it, or while Shift is held over this 3D view.


## True when the title stays on screen with no pointer over the area.
static func always_visible() -> bool:
	return false


## True when the 3D area title should be drawn this frame.
## [param focus_indicator_holding] is true for as long as the focus arrow points at this area.
## [param reveal_all] draws every title in the 3D view the pointer is over, for as long as Shift is held there.
static func should_show(volume_moused_over: bool, matches_bottom_hover_line: bool, focus_indicator_holding: bool = false, reveal_all: bool = false) -> bool:
	if always_visible() or reveal_all:
		return true
	return volume_moused_over or matches_bottom_hover_line or focus_indicator_holding


## Shift reveals titles only in the 3D view the pointer is inside.
static func shift_reveals_titles_in_this_view(shift_held: bool, pointer_over_this_view: bool) -> bool:
	return shift_held and pointer_over_this_view
