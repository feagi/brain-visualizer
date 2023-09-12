extends Node
## AUTOLOADED
## Contains any general info about the state of the visualizer

enum STATES {
	LOADING_INITIAL,
	READY,
}

signal screen_size_changed(new_screen_size: Vector2)
signal UI_settings_changed()
signal user_changed_typing_status(is_typing: bool) ## Emits whenever a user starts / stops interaction with a text box
signal user_changed_window_drag_status(is_dragging_a_window: bool) ## Emits whenever a user starts / stops dragging a window

var screen_size: Vector2:  # keep as float for easy division
	get: return _screen_size

var minimum_button_size_pixel: Vector2i:
	get: return _minimum_button_size_pixel
	set(v):
		_minimum_button_size_pixel = v
		UI_settings_changed.emit()

## Reference to the window manager
var window_manager: WindowManager # set from the window manager itself when it is ready, otherwise this is null!\

var is_premium: bool = true
var left_bar_allow_premium_monitoring: bool = true # todo: should probably tie in with above

var visualizer_state: STATES:
	get: return _visualizer_state
	set(v):
		print("STATE: SWITCH TO " + STATES.find_key(v))
		_visualizer_state = v

## Is the user currently typing in a textbox somewhere
var is_user_typing: bool:
	get: return _is_user_typing
	set(v):
		_is_user_typing = v
		user_changed_typing_status.emit(v)

## Is the user currently dragging a window somewhere
var is_user_dragging_a_window: bool:
	get: return _is_user_dragging_a_window
	set(v):
		_is_user_dragging_a_window = v
		user_changed_window_drag_status.emit(v)

var _screen_size: Vector2
var _minimum_button_size_pixel: Vector2i = Vector2i(40,40) # HINT: number should be divisible by 4
var _is_user_typing: bool = false
var _is_user_dragging_a_window: bool = false

var _visualizer_state: STATES = STATES.LOADING_INITIAL

func _ready():
	_screen_size = get_viewport().get_visible_rect().size
	get_viewport().size_changed.connect(_update_screen_size)

## Updates the screensize 
func _update_screen_size():
	_screen_size = get_viewport().get_visible_rect().size
	screen_size_changed.emit(screen_size)


