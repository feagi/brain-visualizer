extends RefCounted
class_name ComboButtonStripStyler

## Shared spacing tokens for combo button strips.
const INNER_CONTENT_SEPARATION: int = 8
## Gap before rearrange / monitor tools. Not the gap between combo plates.
const INTER_BUTTON_GAP: float = 8.0
## Divider between combo plates. One pixel wider than a bare seam so it matches the icon-strip buttons.
const COMBO_PLATE_GAP: int = 2
## Side inset only. Vertical inset would make combo plates taller than the icon buttons.
const ROW_PAD_X: int = 12
const ROW_PAD_Y: int = 0
## Theme type whose size_x/size_y is the shared top-bar control height.
const TOP_BAR_CONTROL_THEME: StringName = &"TextureButton_TopBar"


## Apply a consistent icon/label separation to list button content rows.
static func apply_list_hbox_spacing(root: Node, list_hbox_paths: Array, separation: int = INNER_CONTENT_SEPARATION) -> void:
	for path in list_hbox_paths:
		var hbox := root.get_node_or_null(path) as HBoxContainer
		if hbox == null:
			continue
		hbox.add_theme_constant_override("separation", separation)


## Apply a consistent fixed width to spacer controls between combo buttons.
static func apply_spacer_width(root: Node, spacer_paths: Array, width: float = INTER_BUTTON_GAP) -> void:
	for path in spacer_paths:
		var spacer := root.get_node_or_null(path) as Control
		if spacer == null:
			continue
		spacer.custom_minimum_size = Vector2(width, spacer.custom_minimum_size.y)


## Inset a combo-row plate. Shared by the root top bar and the tab strips.
static func apply_combo_row_plate_padding(row: PanelContainer) -> void:
	if row == null:
		return
	var current: StyleBox = row.get_theme_stylebox("panel")
	if not current is StyleBoxFlat:
		return
	var plate := (current as StyleBoxFlat).duplicate() as StyleBoxFlat
	plate.content_margin_left = ROW_PAD_X
	plate.content_margin_right = ROW_PAD_X
	plate.content_margin_top = ROW_PAD_Y
	plate.content_margin_bottom = ROW_PAD_Y
	row.add_theme_stylebox_override("panel", plate)
