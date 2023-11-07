extends DraggableWindow
class_name WindowPopupInfo
## Creates a pop up window

enum ICON {
	DEFAULT
}

func _ready() -> void:
	super._ready()

## Set texts of window
func set_properties(title_text: StringName, message_text: StringName, button_text: StringName, icon: ICON = ICON.DEFAULT) -> void:
	_set_title_text(title_text)
	_set_message(message_text)
	_set_button_text(button_text)
	_set_texture(icon)
	$VBoxContainer.size = Vector2(0,0) # force window to shrink
	$TitleBar.close_pressed.connect(_close_popup)
	$TitleBar._auto_maintain_width() #TODO This is dumb, but I dont time to do a cleaner implementation


func _set_title_text(text: StringName) -> void:
	$TitleBar.title = text

func _set_message(text: StringName) -> void:
	$VBoxContainer/HBoxContainer/MESSAGE_TEXT.text = text

func _set_button_text(text: StringName) -> void:
	$VBoxContainer/TextButton_Element.text = text

func _set_texture(icon: ICON) -> void:
	$VBoxContainer/HBoxContainer/Texture_Element.texture = _get_texture_from_icon_enum(icon)

func _get_texture_from_icon_enum(icon: ICON) -> Texture2D:
	match icon:
		_:
			return load("res://Feagi-Godot-Interface/UI/Resources/Icons/setting.png") as Texture2D

func _close_popup():
	queue_free()
