extends Button
class_name GuideTopicButton

signal topic_selected(topic_path: String)

var _topic_path: String = ""

## Configure the button label and target markdown path.
func setup(title: String, topic_path: String) -> void:
	text = title
	_topic_path = topic_path

## Emit the topic selection when the button is pressed.
func _ready() -> void:
	pressed.connect(_on_pressed)

## Notify listeners about the selected topic.
func _on_pressed() -> void:
	if _topic_path == "":
		push_error("GuideTopicButton: Missing topic path.")
		return
	topic_selected.emit(_topic_path)
