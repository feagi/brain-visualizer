extends Button
class_name GuideTopicButton

signal topic_selected(topic_path: String, heading: String)

var _topic_path: String = ""
var _heading: String = ""

## Configure the button label, markdown path, and optional in-page heading.
## `compact` is the nested section size used under a guide topic.
func setup(title: String, topic_path: String, heading: String = "", compact: bool = false) -> void:
	text = title
	_topic_path = topic_path
	_heading = heading
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	theme_type_variation = &"Button_List"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_text = true
	text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var header_size := get_theme_font_size("font_size", "Label_Header")
	if header_size <= 0:
		header_size = 24
	if compact:
		add_theme_font_size_override("font_size", header_size)
	else:
		add_theme_font_size_override("font_size", int(header_size * 1.6))

## Mark the section that is currently open.
func set_selected(selected: bool) -> void:
	if selected:
		add_theme_color_override("font_color", Color("8ab4f8"))
		add_theme_color_override("font_hover_color", Color("8ab4f8"))
		add_theme_color_override("font_pressed_color", Color("8ab4f8"))
	else:
		remove_theme_color_override("font_color")
		remove_theme_color_override("font_hover_color")
		remove_theme_color_override("font_pressed_color")

## Emit the topic selection when the button is pressed.
func _ready() -> void:
	pressed.connect(_on_pressed)

## Notify listeners about the selected topic.
func _on_pressed() -> void:
	if _topic_path == "":
		push_error("GuideTopicButton: Missing topic path.")
		return
	topic_selected.emit(_topic_path, _heading)
