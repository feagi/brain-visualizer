extends RefCounted
class_name VisibleCaretStyle
## Shared caret presentation for LineEdit and TextEdit (blink, contrast, thickness).
## Tune defaults here only: [member DEFAULT_BLINK_INTERVAL], [member DEFAULT_CARET_WIDTH], [member DEFAULT_CARET_COLOR].
## Brain Visualizer applies this globally from [UIManager] (initial tree + [signal SceneTree.node_added]).

const DEFAULT_BLINK_INTERVAL: float = 0.4
const DEFAULT_CARET_WIDTH: int = 3
const DEFAULT_CARET_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)


## Depth-first: applies caret styling to every LineEdit, TextEdit, and SpinBox inner LineEdit under [param root].
static func apply_to_subtree(root: Node) -> void:
	if root == null:
		return
	if root is LineEdit:
		apply_to_line_edit(root as LineEdit)
	elif root is TextEdit:
		apply_to_text_edit(root as TextEdit)
	elif root is SpinBox:
		var le: LineEdit = (root as SpinBox).get_line_edit()
		if le != null:
			apply_to_line_edit(le)
	for child: Node in root.get_children():
		apply_to_subtree(child)


## Applies visible blinking caret styling to a single-line field.
static func apply_to_line_edit(
	line_edit: LineEdit,
	blink_interval: float = DEFAULT_BLINK_INTERVAL,
	caret_width: int = DEFAULT_CARET_WIDTH,
	caret_color: Color = DEFAULT_CARET_COLOR
) -> void:
	line_edit.caret_blink = true
	line_edit.caret_blink_interval = blink_interval
	line_edit.add_theme_color_override(&"caret_color", caret_color)
	line_edit.add_theme_constant_override(&"caret_width", caret_width)


## Applies the same visual language to a multi-line TextEdit.
static func apply_to_text_edit(
	text_edit: TextEdit,
	blink_interval: float = DEFAULT_BLINK_INTERVAL,
	caret_width: int = DEFAULT_CARET_WIDTH,
	caret_color: Color = DEFAULT_CARET_COLOR
) -> void:
	text_edit.caret_blink = true
	text_edit.caret_blink_interval = blink_interval
	text_edit.add_theme_color_override(&"caret_color", caret_color)
	text_edit.add_theme_constant_override(&"caret_width", caret_width)
