extends Node
class_name UIManager

# TODO dev menu - build_settings_object

signal screen_size_changed(new_screen_size: Vector2)
signal theme_changed(theme: Theme)
signal toggle_keyboard_controls(enable_controls: bool) # True if keyboard controls (such as for camera) should be enabled. False in cases such as user typing

var screen_size: Vector2:  # keep as float for easy division
	get: return _screen_size

var screen_center: Vector2:
	get: return _screen_size / 2.0

var _screen_size: Vector2
var _UI_scale: float = 1.0

func set_user_selected_cortical_areas(selected: Array[BaseCorticalArea]) -> void:
	pass
