extends RefCounted
class_name ConfigurablePopupDefinition


var title: StringName
var message: StringName
var buttons: Array[ConfigurablePopupButtonDefinition]
var minimum_size: Vector2i
var window_name: StringName

func _init(window_title: StringName, window_message: StringName, window_buttons: Array[ConfigurablePopupButtonDefinition], window_minumum_size: Vector2i = Vector2i(0,0) ) -> void:
	title = window_title
	message = window_message
	buttons = window_buttons
	minimum_size = window_minumum_size
	window_name = "popup_" + window_title + _generate_random_letters(4)

## Creates a Button that only closes the popup window. Works by the fact that all buttons will close the window
static func create_close_button(text: StringName = "OK") -> ConfigurablePopupButtonDefinition:
	var button: ConfigurablePopupButtonDefinition = ConfigurablePopupButtonDefinition.new()
	button.text = text
	return button

## Creates a Button that does an action
static func create_action_button(action: Callable, text: StringName) -> ConfigurablePopupButtonDefinition:
	var button: ConfigurablePopupButtonDefinition = ConfigurablePopupButtonDefinition.new()
	button.text = text
	button.pressed_callable = [action]
	return button

## Generates a definition of a window with a simple window and a single button to close it
static func create_single_button_close_popup(window_title: StringName, window_message: StringName, button_text: StringName = "OK", window_minumum_size: Vector2i = Vector2i(0,0)) -> ConfigurablePopupDefinition:
	var button: ConfigurablePopupButtonDefinition = ConfigurablePopupDefinition.create_close_button(button_text)
	var button_arr: Array[ConfigurablePopupButtonDefinition] = [button]
	return ConfigurablePopupDefinition.new(window_title, window_message, button_arr, window_minumum_size)


static func create_cancel_and_action_popup(window_title: StringName, window_message: StringName, accept_action: Callable, accept_text: StringName = "OK",  cancel_text: StringName = "Cancel", window_minumum_size: Vector2i = Vector2i(0,0)) -> ConfigurablePopupDefinition:
	var button_ok: ConfigurablePopupButtonDefinition = ConfigurablePopupDefinition.create_action_button(accept_action, accept_text)
	var button_close: ConfigurablePopupButtonDefinition = ConfigurablePopupDefinition.create_close_button(cancel_text)
	var button_arr: Array[ConfigurablePopupButtonDefinition] = [button_ok, button_close]
	return ConfigurablePopupDefinition.new(window_title, window_message, button_arr, window_minumum_size)

func _generate_random_letters(num_letters: int) -> StringName:
	var result: String = ""
	for i in range(num_letters):
		# Generate a random integer between 65 (A) and 90 (Z)
		var random_ascii: int = randi() % (90 - 65 + 1) + 65
		var random_letter: String = char(random_ascii)
		result += random_letter
	return result
