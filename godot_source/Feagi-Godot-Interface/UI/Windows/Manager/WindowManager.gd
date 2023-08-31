extends Node
class_name WindowManager
## Coordinates all the visible windows

var _prefab_left_bar: PackedScene = preload("res://Feagi-Godot-Interface/UI/Windows/Draggable_Windows/Left_Bar/WindowLeftPanel.tscn")

var loaded_windows: Dictionary

func _ready():
	VisConfig.window_manager = self


## Opens a left pane allowing the user to view and edit details of a particular cortical area
func spawn_left_panel(cortical_area: CorticalArea) -> void:
	if "left_bar" in loaded_windows.keys():

		loaded_windows["left_bar"].queue_free()
	
	var left_panel: WindowLeftPanel = _prefab_left_bar.instantiate()
	add_child(left_panel)
	left_panel.setup_from_FEAGI(cortical_area)
	loaded_windows["left_bar"] = left_panel

func force_close_window(window_name: StringName) -> void:
	if window_name in loaded_windows.keys():
		loaded_windows[window_name].queue_free()
		loaded_windows.erase(window_name)
