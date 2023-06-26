extends LineEdit
class_name LineEdit_int_Sub

#TODO - minimum, maximum, prefix, suffix

signal value_edited(val: int)

var minWidth: float:
	get: return get_theme_font("font").get_string_size(text).x

var value: int:
	get: return int(_cachedText)
	set(v): text = str(v); _cachedText = str(v)

var min_value: int = -INF
var max_value: int = INF

var _cachedText: String = "0"

func _ready():
	text_changed.connect(_TextChangedRelay)

func _TextChangedRelay(input: String) -> void:
	if !input.is_valid_int(): return
	_cachedText = input
	
	value_edited.emit(int(input))

# built in vars
# text: String
# size: Vector2
# editable: bool
# expand_to_text_length: bool
# max_length: int
# text_changed: Signal
# text_submitted: Signal
# placeholder_text: String
