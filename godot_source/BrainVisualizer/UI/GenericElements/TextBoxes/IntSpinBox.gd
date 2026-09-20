extends SpinBox
class_name IntSpinBox

## Emitted when the user types in the spin LineEdit or commits a new value (arrows/wheel).
## Programmatic [method set_value_no_signal] does not emit this.
signal user_interacted()

var _default_min_size: Vector2

func _ready():
	if custom_minimum_size != Vector2(0,0):
		_default_min_size = custom_minimum_size
	var line: LineEdit = get_line_edit()
	if line != null:
		line.text_changed.connect(_on_line_text_changed)
	value_changed.connect(_on_value_changed_user)

func _apply_theme(new_theme: Theme) -> void:
	set_theme(new_theme)

func _on_line_text_changed(new_text: String) -> void:
	# Godot updates the LineEdit during set_value_no_signal; skip when text matches the committed value.
	if new_text.strip_edges() == str(int(value)):
		return
	user_interacted.emit()

func _on_value_changed_user(_val: float) -> void:
	user_interacted.emit()
