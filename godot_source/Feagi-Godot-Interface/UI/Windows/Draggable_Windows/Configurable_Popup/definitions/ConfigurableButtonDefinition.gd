extends Object
class_name ConfigurableButtonDefinition
## Used by [ConfigurablePopupDefinition] to add a button

const DEFAULT_MIN_SIZE: Vector2i = Vector2i(128, 64)

var text: StringName
var pressed_action: Callable
var is_close_button: bool
var custom_minimum_size_at_100_scale: Vector2i
var close_after_press: bool # for in use in custom buttons if they should close after

func _init(button_text: StringName, button_action: Callable,  button_closes_window: bool, button_closes_after_action: bool, button_min_size: Vector2i) -> void:
	text = button_text
	pressed_action = button_action
	is_close_button = button_closes_window
	custom_minimum_size_at_100_scale = button_min_size
	close_after_press = button_closes_after_action

## Create a button witha  specific action
static func create_custom_button_definition(button_text: StringName, button_action: Callable, callable_arguments: Array = [], close_after: bool = true,  button_min_size: Vector2i = DEFAULT_MIN_SIZE) -> ConfigurableButtonDefinition:
	if len(callable_arguments) > 0:
		button_action.bindv(callable_arguments)
	return ConfigurableButtonDefinition.new(button_text, button_action, false, close_after, button_min_size)
	
## Create a button that closes the popup
static func create_close_button_definition(button_text: StringName, button_min_size: Vector2i = DEFAULT_MIN_SIZE) -> ConfigurableButtonDefinition:
	return ConfigurableButtonDefinition.new(button_text, Callable(), true, false, button_min_size)
