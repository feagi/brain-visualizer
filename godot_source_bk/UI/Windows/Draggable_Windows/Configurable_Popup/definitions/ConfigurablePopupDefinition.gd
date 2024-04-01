extends Object
class_name ConfigurablePopupDefinition


var title: StringName
var message: StringName
var buttons: Array[ConfigurableButtonDefinition]
var minimum_size: Vector2i
var window_name: StringName

func _init(window_title: StringName, window_message: StringName, window_buttons: Array[ConfigurableButtonDefinition], window_minumum_size: Vector2i = Vector2i(0,0) ) -> void:
	title = window_title
	message = window_message
	buttons = window_buttons
	minimum_size = window_minumum_size
	window_name = "popup_" + _generate_random_letters(4)

## Generates a definition of a window with a simple window and a single button to close it
static func create_single_button_close_popup(window_title: StringName, window_message: StringName, button_text: StringName = "OK", window_minumum_size: Vector2i = Vector2i(0,0)) -> ConfigurablePopupDefinition:
	var button: ConfigurableButtonDefinition = ConfigurableButtonDefinition.create_close_button_definition(button_text)
	var button_arr: Array[ConfigurableButtonDefinition] = []
	button_arr.append(button)
	return ConfigurablePopupDefinition.new(window_title, window_message, button_arr, window_minumum_size)

func _generate_random_letters(num_letters: int) -> StringName:
	var result: String = ""
	for i in range(num_letters):
		# Generate a random integer between 65 (A) and 90 (Z)
		var random_ascii: int = randi() % (90 - 65 + 1) + 65
		var random_letter: String = char(random_ascii)
		result += random_letter
	return result
