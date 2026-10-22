extends GraphElement
## An area box or a region frame: one GraphElement with a styled Panel and a Label (3 nodes per box).

const TYPE_COLORS: Dictionary = {
	"IPU": Color(0.259, 0.259, 0.259),
	"OPU": Color(0.580, 0.322, 0.0),
	"MEMORY": Color(0.580, 0.067, 0.0),
	"CUSTOM": Color(0.0, 0.329, 0.576),
}
const FRAME_TINTS: Array[Color] = [Color(0.14, 0.15, 0.18), Color(0.19, 0.20, 0.24)]

static var _styles: Dictionary = {}


func setup_area(title_text: String, area_type: String, box_size: Vector2) -> void:
	_build(title_text, _style("area_" + area_type, TYPE_COLORS.get(area_type, Color.GRAY), 0), box_size, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)


func setup_frame(title_text: String, depth: int, box_size: Vector2) -> void:
	_build(title_text, _style("frame_%d" % (depth % 2), FRAME_TINTS[depth % 2], 2), box_size, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)


func _build(title_text: String, style: StyleBox, box_size: Vector2, h_align: HorizontalAlignment, v_align: VerticalAlignment) -> void:
	custom_minimum_size = box_size
	size = box_size
	var panel: Panel = Panel.new()
	panel.add_theme_stylebox_override(&"panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size = box_size
	add_child(panel)
	# GraphElement is a Container and stretches its direct children, so the label lives inside the Panel.
	var label: Label = Label.new()
	label.text = title_text
	label.horizontal_alignment = h_align
	label.vertical_alignment = v_align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = Vector2(10, 6) if h_align == HORIZONTAL_ALIGNMENT_LEFT else Vector2.ZERO
	label.size = box_size if h_align != HORIZONTAL_ALIGNMENT_LEFT else Vector2(box_size.x - 20, 24)
	label.clip_text = true
	panel.add_child(label)


static func _style(key: String, color: Color, border: int) -> StyleBoxFlat:
	if not _styles.has(key):
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = color
		style.set_corner_radius_all(6)
		style.set_border_width_all(border)
		style.border_color = Color(0.45, 0.5, 0.6)
		_styles[key] = style
	return _styles[key]
