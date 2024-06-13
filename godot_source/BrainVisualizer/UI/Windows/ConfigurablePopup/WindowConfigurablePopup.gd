extends BaseDraggableWindow
class_name WindowConfigurablePopup

var _message_box: Label
var _button_container: HBoxContainer

func _ready() -> void:
	super()
	_message_box = _window_internals.get_node("Message")
	_button_container = _window_internals.get_node("HBoxContainer")

func setup(popup_definition: ConfigurablePopupDefinition) -> void:
	_setup_base_window(popup_definition.window_name)
	_titlebar.title = popup_definition.title
	_message_box.text = popup_definition.message
	_generate_buttons(popup_definition.buttons)
	_theme_custom_scaler.search_for_matching_children(_window_internals)
	custom_minimum_size = popup_definition.minimum_size
	_theme_updated(BV.UI.loaded_theme) # to scale generated buttons

func _generate_buttons(button_defs: Array[ConfigurablePopupButtonDefinition]) -> void:
	for button_def in button_defs:
		var button: Button = Button.new()
		button.text = button_def.text
		for call in button_def.pressed_callables:
			button.pressed.connect(call)
		button.pressed.connect(close_window)
		_button_container.add_child(button)
		_button_container.theme_type_variation = "Button_big"
