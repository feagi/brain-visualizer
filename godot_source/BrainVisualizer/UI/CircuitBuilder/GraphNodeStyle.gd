extends RefCounted
class_name GraphNodeStyle
## Tints a GraphNode style without dropping its padding. A new StyleBoxFlat that
## only sets bg_color has zero content margin, so the title and the first row
## draw on top of each other and the type color shows through the gap between
## a port and its label.


static func tinted(node: Control, style_name: StringName, color: Color) -> StyleBox:
	var source: StyleBox = node.get_theme_stylebox(style_name, &"GraphNode")
	var copy: StyleBox = source.duplicate()
	var flat := copy as StyleBoxFlat
	if flat == null:
		push_error("GraphNode style '%s' is not a StyleBoxFlat" % style_name)
		return copy
	flat.bg_color = color
	return flat
