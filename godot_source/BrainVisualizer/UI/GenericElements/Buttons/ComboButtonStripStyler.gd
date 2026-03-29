extends RefCounted
class_name ComboButtonStripStyler

## Shared spacing tokens for combo button strips.
const INNER_CONTENT_SEPARATION: int = 6
const INTER_BUTTON_GAP: float = 5.0


## Apply a consistent icon/label separation to list button content rows.
static func apply_list_hbox_spacing(root: Node, list_hbox_paths: Array[NodePath], separation: int = INNER_CONTENT_SEPARATION) -> void:
	for path in list_hbox_paths:
		var hbox := root.get_node_or_null(path) as HBoxContainer
		if hbox == null:
			continue
		hbox.add_theme_constant_override("separation", separation)


## Apply a consistent fixed width to spacer controls between combo buttons.
static func apply_spacer_width(root: Node, spacer_paths: Array[NodePath], width: float = INTER_BUTTON_GAP) -> void:
	for path in spacer_paths:
		var spacer := root.get_node_or_null(path) as Control
		if spacer == null:
			continue
		spacer.custom_minimum_size = Vector2(width, spacer.custom_minimum_size.y)
