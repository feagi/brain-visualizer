extends Node
class_name UIManager

# TODO dev menu - build_settings_object

signal screen_size_changed(new_screen_size: Vector2)
signal theme_changed(theme: Theme)
signal toggle_keyboard_controls(enable_controls: bool) ## True if keyboard controls (such as for camera) should be enabled. False in cases such as user typing #TODO is needed?
signal user_selected_single_cortical_area(area: BaseCorticalArea) ## User selected a single cortical area specifically (IE doesn't fire when a user drag selects multiple)

var screen_size: Vector2:  # keep as float for easy division
	get: return _screen_size

var screen_center: Vector2:
	get: return _screen_size / 2.0
var selected_cortical_areas: Array[BaseCorticalArea]:
	get: return _selected_cortical_areas

var _screen_size: Vector2
var _selected_cortical_areas: Array[BaseCorticalArea] = []

func _ready():
	_screen_size = get_viewport().get_visible_rect().size
	get_viewport().size_changed.connect(_update_screen_size)

func set_user_selected_cortical_areas(selected: Array[BaseCorticalArea]) -> void:
	pass

func user_selected_single_cortical_area_independently(area: BaseCorticalArea) -> void:
	user_selected_single_cortical_area.emit(area)
	
	pass

func user_selected_single_cortical_area_appending(area: BaseCorticalArea) -> void:
	pass

func snap_camera_to_cortical_area(cortical_area: BaseCorticalArea) -> void:
	#TODO change behavior depending on BV / CB
	$Brain_Visualizer.snap_camera_to_cortical_area(cortical_area)

func load_new_theme(theme: Theme) -> void:
	theme_changed.emit(theme)

## Updates the screensize 
func _update_screen_size():
	_screen_size = get_viewport().get_visible_rect().size
	screen_size_changed.emit(screen_size)
	if OS.is_debug_build():
		print("UI: Window Size Change Detected!")
