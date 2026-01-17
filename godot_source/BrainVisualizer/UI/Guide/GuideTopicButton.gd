extends Button
class_name GuideTopicButton

signal topic_selected(topic_path: String)

var _topic_path: String = ""

## Configure the button label and target markdown path.
func setup(title: String, topic_path: String) -> void:
	text = title
	_topic_path = topic_path
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	theme_type_variation = &"Button_List"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_text = true
	text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var header_size := get_theme_font_size("font_size", "Label_Header")
	if header_size <= 0:
		header_size = 24
	add_theme_font_size_override("font_size", int(header_size * 1.6))
	print("GuideTopicButton: Setup with title='%s' path='%s' font_size=%d" % [title, topic_path, int(header_size * 1.6)])

## Emit the topic selection when the button is pressed.
func _ready() -> void:
	pressed.connect(_on_pressed)
	print("GuideTopicButton: Ready for '%s'" % text)

## Notify listeners about the selected topic.
func _on_pressed() -> void:
	print("GuideTopicButton: Pressed '%s' -> %s" % [text, _topic_path])
	if _topic_path == "":
		push_error("GuideTopicButton: Missing topic path.")
		return
	topic_selected.emit(_topic_path)
