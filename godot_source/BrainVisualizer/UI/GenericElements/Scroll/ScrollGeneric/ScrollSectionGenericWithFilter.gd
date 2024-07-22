extends VBoxContainer
class_name ScrollSectionGenericWithFilter

var scroll_section: ScrollSectionGeneric:
	get: return _scroll_section

var _filter: LineEdit
var _scroll_section: ScrollSectionGeneric

func _ready():
	_filter = $LineEdit
	_scroll_section = $ScrollSectionGeneric
	_filter.text_changed.connect(_on_text_entered)

func _on_text_entered(text: String) -> void:
	if text == "":
		_scroll_section.toggle_all_visiblity(true)
		return
	_scroll_section.filter_by_friendly_name(text)

