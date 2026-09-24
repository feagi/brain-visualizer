extends RefCounted
class_name ComboButtonStripStyler

## Shared spacing tokens for combo button strips.
const INNER_CONTENT_SEPARATION: int = 8
## One gap for every strip: root bar, Circuit Builder, and Brain Monitor.
const COMBO_PLATE_GAP: int = 2
## Side inset only. Vertical inset would make combo plates taller than the icon buttons.
const ROW_PAD_X: int = 12
const ROW_PAD_Y: int = 0
## Theme type whose size_x/size_y is the shared top-bar control height.
const TOP_BAR_CONTROL_THEME: StringName = &"TextureButton_TopBar"
## Category icons are smaller than TextureButton_TopBar. The button size itself stays in the theme.
const CATEGORY_ICON_SCALE: float = 0.8
## interconnected.png has no transparent margin, so the shared category box still looks full size.
const FULL_BLEED_ICON_SCALE: float = 0.64


## Size of a category icon. [param theme_button_size] is TextureButton_TopBar from the loaded theme.
static func category_icon_size(theme_button_size: Vector2, full_bleed: bool = false) -> Vector2:
	var factor: float = FULL_BLEED_ICON_SCALE if full_bleed else CATEGORY_ICON_SCALE
	return theme_button_size * factor


## Apply a consistent icon/label separation to list button content rows.
static func apply_list_hbox_spacing(root: Node, list_hbox_paths: Array, separation: int = INNER_CONTENT_SEPARATION) -> void:
	for path in list_hbox_paths:
		var hbox := root.get_node_or_null(path) as HBoxContainer
		if hbox == null:
			continue
		hbox.add_theme_constant_override("separation", separation)


## Apply a consistent fixed width to spacer controls between combo buttons.
static func apply_spacer_width(root: Node, spacer_paths: Array, width: float = COMBO_PLATE_GAP) -> void:
	for path in spacer_paths:
		var spacer := root.get_node_or_null(path) as Control
		if spacer == null:
			continue
		spacer.custom_minimum_size = Vector2(width, spacer.custom_minimum_size.y)


## Inset a combo-row plate. Shared by the root top bar and the tab strips.
static func apply_combo_row_plate_padding(row: PanelContainer, pad_x: int = ROW_PAD_X, pad_y: int = ROW_PAD_Y) -> void:
	if row == null:
		return
	var current: StyleBox = row.get_theme_stylebox("panel")
	if not current is StyleBoxFlat:
		return
	var plate := (current as StyleBoxFlat).duplicate() as StyleBoxFlat
	plate.content_margin_left = pad_x
	plate.content_margin_right = pad_x
	plate.content_margin_top = pad_y
	plate.content_margin_bottom = pad_y
	row.add_theme_stylebox_override("panel", plate)
