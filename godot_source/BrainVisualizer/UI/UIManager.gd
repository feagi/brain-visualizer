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
var selected_cortical_areas: Array[BaseCorticalArea]:
	get: return _selected_cortical_areas

var _screen_size: Vector2
var _UI_scale: float = 1.0
var _selected_cortical_areas: Array[BaseCorticalArea] = []

func set_user_selected_cortical_areas(selected: Array[BaseCorticalArea]) -> void:
	pass

func user_selected_single_cortical_area_independently(area: BaseCorticalArea) -> void:
	pass

func user_selected_single_cortical_area_appending(area: BaseCorticalArea) -> void:
	pass
