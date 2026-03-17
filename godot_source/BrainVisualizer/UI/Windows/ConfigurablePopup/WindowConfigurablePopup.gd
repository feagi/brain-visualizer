extends BaseDraggableWindow
class_name WindowConfigurablePopup

var _message_box: RichTextLabel
var _button_container: HBoxContainer
var _enter_confirms_button_text: String = ""

func _ready() -> void:
	super()
	_message_box = _window_internals.get_node("Message")
	_button_container = _window_internals.get_node("HBoxContainer")

func setup(popup_definition: ConfigurablePopupDefinition) -> void:
	_setup_base_window(popup_definition.window_name)
	_titlebar.title = popup_definition.title
	_message_box.text = popup_definition.message
	_generate_buttons(popup_definition.buttons)
	custom_minimum_size = popup_definition.minimum_size

func _generate_buttons(button_defs: Array[ConfigurablePopupButtonDefinition]) -> void:
	for button_def in button_defs:
		var button: Button = Button.new()
		button.text = button_def.text
		for call in button_def.pressed_callables:
			button.pressed.connect(call)
		button.pressed.connect(close_window)
		_button_container.add_child(button)
		_button_container.theme_type_variation = "Button_big"
		button.custom_minimum_size = BV.UI.get_minimum_size_from_loaded_theme_variant_given_control(button, "Button_big")

func _input(event: InputEvent) -> void:
	super(event)
	if _enter_confirms_button_text == "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
			accept_event()
			_press_button_with_text(_enter_confirms_button_text)

func set_enter_confirms_button(button_text: String) -> void:
	_enter_confirms_button_text = button_text

func focus_button_with_text(button_text: String) -> bool:
	for child in _button_container.get_children():
		var button := child as Button
		if button and button.text == button_text:
			button.grab_focus()
			return true
	return false

func _press_button_with_text(button_text: String) -> bool:
	for child in _button_container.get_children():
		var button := child as Button
		if button and button.text == button_text:
			button.emit_signal("pressed")
			return true
	return false
