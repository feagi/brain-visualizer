extends Node
## AUTOLOADED
## Contains any general info about the state of the visualizer

signal screen_size_changed(new_screen_size: Vector2)
signal UI_settings_changed()

var screen_size: Vector2:  # keep as float for easy division
	get: return _screen_size

var minimum_button_size_pixel: Vector2i:
	get: return _minimum_button_size_pixel
	set(v):
		_minimum_button_size_pixel = v
		UI_settings_changed.emit()


var _screen_size: Vector2
var _minimum_button_size_pixel: Vector2i = Vector2i(40,40)


func _init():
	pass

func _ready():
	_screen_size = get_viewport().get_visible_rect().size
	get_viewport().size_changed.connect(_update_screen_size)





## Updates the screensize 
func _update_screen_size():
	_screen_size = get_viewport().get_visible_rect().size
	screen_size_changed.emit(screen_size)


