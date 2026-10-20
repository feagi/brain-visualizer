extends RefCounted
class_name KeybindCatalog
## Keyboard and modifier shortcuts shown in the shortcuts window.
##
## The K key opens that window. Text fields keep the letter.


const KEY_SECTION := "section"
const KEY_KEYS := "keys"
const KEY_ACTION := "action"
const KEY_CONTEXT := "context"


## Bare K, including the physical key so a non-US layout still opens the window.
static func is_keybinds_shortcut(
	keycode: Key,
	physical_keycode: Key,
	with_command: bool,
	shift_pressed: bool,
	alt_pressed: bool,
	pressed: bool,
	echo: bool,
) -> bool:
	if not pressed or echo or with_command or shift_pressed or alt_pressed:
		return false
	return keycode == KEY_K or physical_keycode == KEY_K


## A focused text field should receive K as a character.
static func focus_blocks_keybinds(focus_owner: Control) -> bool:
	return focus_owner is LineEdit or focus_owner is TextEdit


## Rows in display order. Each row is one shortcut.
static func entries() -> Array[Dictionary]:
	return [
		_row("App", "K", "Open or close this shortcuts window", "Anywhere except a text field"),
		_row("App", "Ctrl/Cmd + S", "Search the genome by name", "Anywhere except a text field"),
		_row("App", "Ctrl/Cmd + Z", "Undo the last genome change", "Anywhere except a text field"),
		_row("App", "Shift + Ctrl/Cmd + Z", "Redo", "Anywhere except a text field"),
		_row("App", "Escape", "Stop Inspector when that button is showing. Otherwise close the front window, or cancel a move, a box select, or the current selection", "Anywhere"),
		_row("App", "Enter", "Confirm the open dialog, or confirm a move or resize", "Dialogs and Brain Monitor"),
		_row("App", "`", "Open the developer menu", "When the developer menu is enabled"),
		_row("Selection", "Ctrl/Cmd + C", "Copy the selected voxels", "At least one voxel is selected"),
		_row("Selection", "Ctrl/Cmd + V", "Paste copied voxels into the area under the pointer", "Brain Monitor"),
		_row("Selection", "Ctrl/Cmd + click", "Add or remove that cortical area from the selection", "Brain Monitor"),
		_row("Selection", "Ctrl/Cmd or Shift + click", "Add that node to the selection", "Circuit Builder"),
		_row("Selection", "Shift + click", "Select or clear neurons under the pointer", "Brain Monitor"),
		_row("Selection", "Shift + drag", "Box-select cortical areas", "Brain Monitor"),
		_row("Selection", "Ctrl/Cmd + Shift + click", "Open the floating inspect view for that area", "Brain Monitor"),
		_row("Selection", "Delete", "Clear the selected neurons", "Brain Monitor"),
		_row("Selection", "Space", "Fire the selected neurons", "Brain Monitor"),
		_row("Camera", "W or Up", "Move the camera forward", "Pointer over a Brain Monitor"),
		_row("Camera", "S or Down", "Move the camera back", "Pointer over a Brain Monitor"),
		_row("Camera", "A or Left", "Move the camera left", "Pointer over a Brain Monitor"),
		_row("Camera", "D or Right", "Move the camera right", "Pointer over a Brain Monitor"),
		_row("Camera", "Shift", "Move and zoom faster", "Pointer over a Brain Monitor"),
		_row("Camera", "T", "Top view", "Pointer over a Brain Monitor"),
		_row("Camera", "B", "Bottom view", "Pointer over a Brain Monitor"),
		_row("Camera", "F", "Front view", "Pointer over a Brain Monitor"),
		_row("Camera", "L", "Left view", "Pointer over a Brain Monitor"),
		_row("Camera", "R", "Right view", "Pointer over a Brain Monitor"),
		_row("Camera", "Home", "Frame the whole brain from the front", "Pointer over a Brain Monitor"),
		_row("Camera", "Ctrl/Cmd + 1 + click", "Frame that area on the XY plane", "Brain Monitor"),
		_row("Camera", "Ctrl/Cmd + 2 + click", "Frame that area on the XZ plane", "Brain Monitor"),
		_row("Camera", "Ctrl/Cmd + 3 + click", "Frame that area on the YZ plane", "Brain Monitor"),
		_row("Camera", "Alt/Option + drag", "Orbit around the selection", "Brain Monitor"),
		_row("Camera", "Middle drag", "Orbit around the selection", "Brain Monitor"),
	]


static func _row(section: String, keys: String, action: String, context: String) -> Dictionary:
	return {
		KEY_SECTION: section,
		KEY_KEYS: keys,
		KEY_ACTION: action,
		KEY_CONTEXT: context,
	}
