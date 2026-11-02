extends RefCounted
class_name GraphNodeStyle
## Tints a GraphNode style without dropping its padding, and draws one port per
## connection row. A new StyleBoxFlat that only sets bg_color has zero content
## margin, so the title and the first row draw on top of each other.

## Drawn size of a row port. The source images are 64px and 32px; the row used to show them at 20px.
const PORT_ICON_PX: int = 20

const ICON_FULL: Texture2D = preload("res://BrainVisualizer/UI/CircuitBuilder/Resources/Ports/cb-port.png")
const ICON_RING: Texture2D = preload("res://BrainVisualizer/UI/CircuitBuilder/Resources/Ports/cb-port-ring.png")
const ICON_RECURSIVE: Texture2D = preload("res://BrainVisualizer/UI/CircuitBuilder/Resources/Ports/cb-port-recursive.png")

static var _scaled_icons: Dictionary = {}


static func tinted(node: Control, style_name: StringName, color: Color) -> StyleBox:
	var source: StyleBox = node.get_theme_stylebox(style_name, &"GraphNode")
	var copy: StyleBox = source.duplicate()
	var flat := copy as StyleBoxFlat
	if flat == null:
		push_error("GraphNode style '%s' is not a StyleBoxFlat" % style_name)
		return copy
	flat.bg_color = color
	return flat


## Full, ring, or recursive port art at [constant PORT_ICON_PX].
static func port_icon(kind: StringName) -> Texture2D:
	var source: Texture2D = ICON_FULL
	match kind:
		&"ring":
			source = ICON_RING
		&"recursive":
			source = ICON_RECURSIVE
	if _scaled_icons.has(source):
		return _scaled_icons[source]
	var image: Image = source.get_image()
	if image == null:
		push_error("Circuit builder port icon has no image data")
		return source
	image.resize(PORT_ICON_PX, PORT_ICON_PX, Image.INTERPOLATE_LANCZOS)
	var scaled: Texture2D = ImageTexture.create_from_image(image)
	_scaled_icons[source] = scaled
	return scaled


## Enables the left or right port on one row and turns the slot background off.
static func configure_row_slot(node: GraphNode, slot_index: int, left: bool, right: bool, icon: Texture2D) -> void:
	var left_icon: Texture2D = icon if left else null
	var right_icon: Texture2D = icon if right else null
	node.set_slot(slot_index, left, 0, Color.WHITE, right, 0, Color.WHITE, left_icon, right_icon, false)


## Child index among visible controls. GraphNode does not give hidden children a slot.
static func visible_slot_index(node: Node, target: Node) -> int:
	var index := 0
	for child: Node in node.get_children():
		if child == target:
			return index
		var control := child as Control
		if control != null and control.visible:
			index += 1
	return -1


## Graph-space center of one port. Same sum GraphEdit uses for its own wires.
static func graph_port_position(node: GraphNode, input_side: bool, port_index: int) -> Vector2:
	# The engine has no port positions while the node is not visible in the tree (empty port cache).
	var count: int = node.get_input_port_count() if input_side else node.get_output_port_count()
	if port_index < 0 or port_index >= count:
		return node.position_offset
	var local: Vector2 = node.get_input_port_position(port_index) if input_side else node.get_output_port_position(port_index)
	return local + node.position_offset
