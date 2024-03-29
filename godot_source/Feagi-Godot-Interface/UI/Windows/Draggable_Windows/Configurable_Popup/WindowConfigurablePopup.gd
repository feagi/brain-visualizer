extends BaseDraggableWindow
class_name WindowConfigurablePopup

var _message_box: Label
var _button_container: HBoxContainer

func _ready() -> void:
	super()
	_message_box = _window_internals.get_node("Message")
	_button_container = _window_internals.get_node("HBoxContainer")

func setup(popup_definition: ConfigurablePopupDefinition) -> void:
	_setup_base_window(popup_definition.window_name) #TODO: come up witha  better method later
	_titlebar.title = popup_definition.title
	_message_box.text = popup_definition.message
	_generate_buttons(popup_definition.buttons)
	custom_minimum_size = popup_definition.minimum_size # TODO proper scaling support


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
