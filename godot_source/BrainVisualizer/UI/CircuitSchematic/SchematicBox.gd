extends GraphElement
class_name SchematicBox
## One schematic item drawn in a single _draw(): an area or classifier box, a closed region block, or
## an open region frame. Read-only: not draggable and not selectable. Pressing a box makes GraphEdit
## raise it; [CircuitSchematic] puts the order back right after.

signal double_clicked(item_index: int)
signal shift_clicked(item_index: int)

enum LOOK { LEAF, BLOCK, FRAME }

const FRAME_TINTS: Array[Color] = [Color(0.16, 0.17, 0.21, 0.92), Color(0.21, 0.22, 0.27, 0.92)]
const BLOCK_COLOR: Color = Color(0.24, 0.27, 0.34)
const BORDER_COLOR: Color = Color(0.48, 0.53, 0.63)
const TEXT_COLOR: Color = Color(0.94, 0.95, 0.97)
const SUBTEXT_COLOR: Color = Color(0.72, 0.75, 0.82)
const TITLE_FONT_SIZE: int = 18
const SUBTITLE_FONT_SIZE: int = 14
const LEAF_FONT_SIZE: int = 16

var item_index: int = -1
var look: LOOK = LOOK.LEAF

var _title: String = ""
var _subtitle: String = ""
var _badge: String = ""
var _style: StyleBoxFlat


func setup(index: int, item: Dictionary, box_look: LOOK, hidden_mappings: int) -> void:
	item_index = index
	look = box_look
	name = "Item_%d" % index
	selectable = false
	draggable = false
	mouse_filter = Control.MOUSE_FILTER_PASS
	position_offset = item["global"]
	custom_minimum_size = item["size"]
	size = item["size"]
	_title = item["name"]
	_style = StyleBoxFlat.new()
	_style.set_corner_radius_all(8)
	match look:
		LOOK.LEAF:
			_style.bg_color = item["color"]
		LOOK.BLOCK:
			_style.bg_color = BLOCK_COLOR
			_style.border_color = BORDER_COLOR
			_style.set_border_width_all(2)
			_subtitle = _counts_text(item)
			if item["closed_only"]:
				_subtitle = "integrated circuit"
			if hidden_mappings > 0:
				_badge = "%d inside" % hidden_mappings
		LOOK.FRAME:
			_style.bg_color = FRAME_TINTS[int(item["depth"]) % 2]
			_style.border_color = BORDER_COLOR
			_style.set_border_width_all(2)
			_subtitle = _counts_text(item)
	var tip: String = _title
	if item["object"] is BrainRegion:
		var description: String = String((item["object"] as BrainRegion).description).strip_edges()
		if not description.is_empty():
			tip += "\n" + description
	if look == LOOK.BLOCK and not item["closed_only"]:
		tip += "\nDouble-click to open"
	elif look == LOOK.FRAME and int(item["parent"]) != -1:
		tip += "\nDouble-click the header to close"
	if look != LOOK.LEAF and not item["closed_only"]:
		tip += "\nShift-click to open in Circuit Builder and Brain Monitor"
	tooltip_text = tip
	queue_redraw()


func _draw() -> void:
	draw_style_box(_style, Rect2(Vector2.ZERO, size))
	var font: Font = get_theme_default_font()
	match look:
		LOOK.LEAF:
			var baseline: float = size.y * 0.5 + LEAF_FONT_SIZE * 0.35
			draw_string(font, Vector2(10, baseline), _title, HORIZONTAL_ALIGNMENT_CENTER, size.x - 20, LEAF_FONT_SIZE, TEXT_COLOR, TextServer.JUSTIFICATION_NONE)
		LOOK.BLOCK:
			draw_string(font, Vector2(14, size.y * 0.5 - 4), _title, HORIZONTAL_ALIGNMENT_CENTER, size.x - 28, TITLE_FONT_SIZE, TEXT_COLOR)
			draw_string(font, Vector2(14, size.y * 0.5 + 20), _subtitle, HORIZONTAL_ALIGNMENT_CENTER, size.x - 28, SUBTITLE_FONT_SIZE, SUBTEXT_COLOR)
			if not _badge.is_empty():
				draw_string(font, Vector2(14, size.y - 14), _badge, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 28, SUBTITLE_FONT_SIZE, SUBTEXT_COLOR)
		LOOK.FRAME:
			draw_string(font, Vector2(14, 30), _title, HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.6, TITLE_FONT_SIZE, TEXT_COLOR)
			draw_string(font, Vector2(size.x * 0.6, 30), _subtitle, HORIZONTAL_ALIGNMENT_RIGHT, size.x * 0.4 - 14, SUBTITLE_FONT_SIZE, SUBTEXT_COLOR)


func _gui_input(event: InputEvent) -> void:
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse == null or mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.pressed:
		return
	# Shift takes precedence so a shift double-click opens the tabs once and doesn't also toggle the box.
	if mouse.shift_pressed:
		if look != LOOK.LEAF and not mouse.double_click:
			shift_clicked.emit(item_index)
		accept_event()
		return
	if not mouse.double_click:
		return
	if look == LOOK.FRAME and mouse.position.y > SchematicModel.HEADER:
		return
	double_clicked.emit(item_index)
	accept_event()


static func _counts_text(item: Dictionary) -> String:
	var parts: Array[String] = []
	if int(item["area_count"]) > 0:
		parts.append("%d area%s" % [item["area_count"], "" if int(item["area_count"]) == 1 else "s"])
	if int(item["region_count"]) > 0:
		parts.append("%d circuit%s" % [item["region_count"], "" if int(item["region_count"]) == 1 else "s"])
	return " · ".join(parts) if not parts.is_empty() else "empty"
