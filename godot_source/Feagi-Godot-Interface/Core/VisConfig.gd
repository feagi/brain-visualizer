extends Node
## AUTOLOADED
## Contains any general info about the state of the visualizer

signal screen_size_changed(new_screen_size: Vector2)

var screen_size: Vector2:  # keep as float for easy division
	get: return _screen_size

var _screen_size: Vector2

func _init():
	pass

func _ready():
	_screen_size = get_viewport().get_visible_rect().size
	get_viewport().size_changed.connect(_update_screen_size)



## Updates the screensize 
func _update_screen_size():
	_screen_size = get_viewport().get_visible_rect().size
	screen_size_changed.emit(screen_size)
