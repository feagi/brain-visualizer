extends RefCounted
## Chooses what Escape does to a Brain Visualizer selection.
## Callers run this from _input. The 3D view is a SubViewportContainer, which disables
## _unhandled_input while it has focus, so an unhandled-key handler never sees Escape
## after a voxel or cortical-area click.


enum ACTION {
	NONE,
	CANCEL_MANIPULATION,
	CANCEL_BOX_SELECT,
	CLEAR_SELECTION,
}


static func resolve(
	keycode: Key,
	physical_keycode: Key,
	pressed: bool,
	echo: bool,
	manipulation_active: bool,
	box_select_active: bool,
	has_genome_object_selection: bool,
	has_voxel_selection: bool,
) -> ACTION:
	if not pressed or echo:
		return ACTION.NONE
	if keycode != KEY_ESCAPE and physical_keycode != KEY_ESCAPE:
		return ACTION.NONE
	if manipulation_active:
		return ACTION.CANCEL_MANIPULATION
	if box_select_active:
		return ACTION.CANCEL_BOX_SELECT
	if has_genome_object_selection or has_voxel_selection:
		return ACTION.CLEAR_SELECTION
	return ACTION.NONE
