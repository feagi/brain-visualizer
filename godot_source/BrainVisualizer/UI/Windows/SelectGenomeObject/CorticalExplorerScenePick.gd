extends RefCounted
class_name CorticalExplorerScenePick
## While Cortical Area Explorer is open, a mouse pick in the 3D view chooses that
## object in the explorer. Quick Connect must leave the click to the explorer.


## Mouse picks from the 3D view and the circuit graph. List clicks inside this window are not scene picks.
static func accepts_mouse_context(context: SelectionSystem.SOURCE_CONTEXT) -> bool:
	return context == SelectionSystem.SOURCE_CONTEXT.FROM_3D_SCENE \
		or context == SelectionSystem.SOURCE_CONTEXT.FROM_3D_SCENE_ON_PLATE \
		or context == SelectionSystem.SOURCE_CONTEXT.FROM_CIRCUIT_BUILDER_CLICK \
		or context == SelectionSystem.SOURCE_CONTEXT.FROM_CIRCUIT_BUILDER_DRAG


## Quick Connect keeps its own destination click only while the explorer is closed.
static func quick_connect_should_yield_to_explorer(explorer_open: bool) -> bool:
	return explorer_open


## A hidden, disabled, or non-area/region object cannot be checked in the explorer.
static func is_chooser_eligible(is_cortical_area: bool, is_region: bool, shown: bool, disabled: bool) -> bool:
	if not is_cortical_area and not is_region:
		return false
	return shown and not disabled


## Single-area explorers keep one choice. Multi-select explorers add the clicked areas.
static func replaces_existing_choices(multiselect: bool) -> bool:
	return not multiselect
