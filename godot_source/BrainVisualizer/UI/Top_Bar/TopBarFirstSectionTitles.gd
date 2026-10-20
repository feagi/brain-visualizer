extends RefCounted
## Decides when the root bar's first section drops its titles.
## Circuits, Inputs, Outputs, Connectivity Rules, and Modulators keep their icons.


## True when the labeled bar is wider than the space it has. Exact fit keeps the titles.
static func should_hide(full_bar_width: float, available_width: float) -> bool:
	if available_width <= 1.0:
		return false
	return full_bar_width > available_width


## Width a hidden title still occupies in the labeled bar, including the gap beside its icon.
static func hidden_title_slot_width(label: Label) -> float:
	if label == null or label.visible:
		return 0.0
	var slot: float = label.get_combined_minimum_size().x
	var parent_box := label.get_parent() as BoxContainer
	if parent_box != null:
		slot += float(parent_box.get_theme_constant("separation"))
	return slot


## Title label inside a category chip. The chip keeps its icon when this label is hidden.
static func category_title_label(row: Node, list_node_name: String) -> Label:
	if row == null:
		return null
	return row.get_node_or_null("HBoxContainer/%s/HBoxContainer/Label" % list_node_name) as Label
