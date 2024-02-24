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
	_setup_base_window(popup_definition.window_name) #TODO: come up witha  better method later
	_title_bar.title = popup_definition.title
	_message_box.text = popup_definition.message
	_generate_buttons(popup_definition.buttons)
	custom_minimum_size = popup_definition.minimum_size


func _generate_buttons(button_definitions: Array[ConfigurableButtonDefinition]) -> void:
	for definition in button_definitions:
		var button = Button.new()
		button.text = definition.text
		button.custom_minimum_size = definition.custom_minimum_size_at_100_scale
		if definition.is_close_button:
			button.pressed.connect(close_window)
		else:
			button.pressed.connect(definition.pressed_action)
			if definition.close_after_press:
				button.pressed.connect(close_window)
		_button_container.add_child(button)
