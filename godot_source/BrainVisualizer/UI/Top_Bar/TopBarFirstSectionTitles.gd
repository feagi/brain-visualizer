extends RefCounted
## Decides how far the root bar compresses when it is wider than the window.
## Order: icon-only category chips, then hide neuron and synapse counts, then shorten the refresh label.


const STAGE_FULL: int = 0
const STAGE_ICONS: int = 1
const STAGE_NO_COUNTS: int = 2
const STAGE_SHORT_HZ: int = 3

const REFRESH_LABEL_FULL: String = "Refresh Rate (Hz)"
## Appended inside the value field when the refresh title is hidden. Editing shows the number alone.
const REFRESH_VALUE_SUFFIX: String = "Hz"


## Least-compressed stage whose width fits. An unknown window width keeps the full bar.
static func compression_stage(
	available_width: float,
	full_width: float,
	title_width: float,
	count_width: float,
	refresh_label_savings: float
) -> int:
	if available_width <= 1.0:
		return STAGE_FULL
	if full_width <= available_width:
		return STAGE_FULL
	if full_width - title_width <= available_width:
		return STAGE_ICONS
	if full_width - title_width - count_width <= available_width:
		return STAGE_NO_COUNTS
	if refresh_label_savings < 0.0:
		refresh_label_savings = 0.0
	return STAGE_SHORT_HZ


## True when the labeled bar is wider than the space it has. Exact fit keeps the titles.
static func should_hide(full_bar_width: float, available_width: float) -> bool:
	return compression_stage(available_width, full_bar_width, 0.0, 0.0, 0.0) != STAGE_FULL


## Width a control takes in its parent row, including the gap before it.
static func control_slot_width(control: Control) -> float:
	if control == null:
		return 0.0
	var slot: float = control.get_combined_minimum_size().x
	var parent_box := control.get_parent() as BoxContainer
	if parent_box != null:
		slot += float(parent_box.get_theme_constant("separation"))
	return slot


## Width a hidden control still occupies in the expanded bar, including the gap beside it.
static func hidden_title_slot_width(control: Control) -> float:
	if control == null or control.visible:
		return 0.0
	return control_slot_width(control)


## Width to add back while the refresh title is hidden.
## The value field grows by "Hz" on its own. That growth is left in the measured bar so the
## compact stage stays put at the breakpoint. Subtracting it makes the next measurement fit
## the longer title again, and the resize handler flips stages until the engine crashes.
static func compact_refresh_extra_width(label: Label, _value_field: Control) -> float:
	return hidden_title_slot_width(label)


## Title label inside a category chip. The chip keeps its icon when this label is hidden.
static func category_title_label(row: Node, list_node_name: String) -> Label:
	if row == null:
		return null
	return row.get_node_or_null("HBoxContainer/%s/HBoxContainer/Label" % list_node_name) as Label
