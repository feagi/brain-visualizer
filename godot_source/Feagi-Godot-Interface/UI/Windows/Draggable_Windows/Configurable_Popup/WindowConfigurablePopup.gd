extends BaseWindowPanel
class_name WindowConfigurablePopup

var _message_box: Label
var _title_bar: TitleBar
var _button_container: HBoxContainer

func _ready() -> void:
	_message_box = $VBoxContainer/Message
	_title_bar = $TitleBar
	_button_container = $VBoxContainer/HBoxContainer

func setup(popup_definition: ConfigurablePopupDefinition) -> void:
	_setup_base_window("popup_" + _generate_random_letters(4)) # The popup should a unique ID TODO: come up witha  better method later
	_title_bar.title = popup_definition.title
	_message_box.text = popup_definition.message
	_generate_buttons(popup_definition.buttons)
	custom_minimum_size = popup_definition.minimum_size
	
#TODO this should probably be somewhere else, like in utils?
func _generate_random_letters(num_letters: int) -> StringName:
	var result: String = ""
	for i in range(num_letters):
		# Generate a random integer between 65 (A) and 90 (Z)
		var random_ascii: int = randi() % (90 - 65 + 1) + 65
		var random_letter: String = char(random_ascii)
		result += random_letter
	return result

func _generate_buttons(button_definitions: Array[ConfigurableButtonDefinition]) -> void:
	for definition in button_definitions:
		var button = Button.new()
		button.text = definition.text
		button.custom_minimum_size = definition.custom_minimum_size_at_100_scale
		if definition.is_close_button:
			button.pressed.connect(close_window)
		else:
			button.pressed.connect(definition.pressed_action)
		_button_container.add_child(button)
