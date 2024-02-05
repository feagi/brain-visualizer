extends Object
class_name ConfigurablePopupDefinition


var title: StringName
var message: StringName
var buttons: Array[ConfigurableButtonDefinition]
var minimum_size: Vector2i

func _init(window_title: StringName, window_message: StringName, window_buttons: Array[ConfigurableButtonDefinition], window_minumum_size: Vector2i = Vector2i(0,0) ) -> void:
	title = window_title
	message = window_message
	buttons = window_buttons
	minimum_size = window_minumum_size

static func create_single_button_close_popup(window_title: StringName, window_message: StringName, button_text: StringName = "OK", window_minumum_size: Vector2i = Vector2i(0,0)) -> ConfigurablePopupDefinition:
	var button: ConfigurableButtonDefinition = ConfigurableButtonDefinition.create_close_button_definition(button_text)
	var buttons: Array[ConfigurableButtonDefinition] = []
	buttons.append(button)
	return ConfigurablePopupDefinition.new(window_title, window_message, buttons, window_minumum_size)
