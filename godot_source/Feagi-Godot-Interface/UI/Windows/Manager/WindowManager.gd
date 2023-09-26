extends Node
class_name WindowManager
## Coordinates all the visible windows

var _prefab_left_bar: PackedScene = preload("res://Feagi-Godot-Interface/UI/Windows/Draggable_Windows/Left_Bar/WindowLeftPanel.tscn")
var _prefab_create_morphology: PackedScene = preload("res://Feagi-Godot-Interface/UI/Windows/Draggable_Windows/Create_Morphology/WindowCreateMorphology.tscn")
var _prefab_edit_mappings: PackedScene = preload("res://Feagi-Godot-Interface/UI/Windows/Draggable_Windows/Mapping_Definition/WindowEditMappingDefinition.tscn")
var _prefab_morphology_manager: PackedScene = preload("res://Feagi-Godot-Interface/UI/Windows/Draggable_Windows/Morphology_Manager/WindowMorphologyManager.tscn")
var _prefab_create_cortical: PackedScene = preload("res://Feagi-Godot-Interface/UI/Windows/Draggable_Windows/Create_Cortical_Area/WindowCreateCorticalArea.tscn")

var loaded_windows: Dictionary


## Opens a left pane allowing the user to view and edit details of a particular cortical area
func spawn_left_panel(cortical_area: CorticalArea) -> void:
	if "left_bar" in loaded_windows.keys():
		loaded_windows["left_bar"].queue_free()
	
	var left_panel: WindowLeftPanel = _prefab_left_bar.instantiate()
	add_child(left_panel)
	left_panel.setup_from_FEAGI(cortical_area)
	loaded_windows["left_bar"] = left_panel

func spawn_create_morphology() -> void:
	if "create_morphology" in loaded_windows.keys():
		loaded_windows["create_morphology"].queue_free()
	
	var create_morphology: WindowCreateMorphology = _prefab_create_morphology.instantiate()
	add_child(create_morphology)
	loaded_windows["create_morphology"] = create_morphology

func spawn_manager_morphology(morphology_to_preload: Morphology = null) -> void:
	if "morphology_manager" in loaded_windows.keys():
		loaded_windows["morphology_manager"].queue_free()
	
	var morphology_manager: WindowMorphologyManager = _prefab_morphology_manager.instantiate()
	add_child(morphology_manager)
	loaded_windows["morphology_manager"] = morphology_manager

func spawn_edit_mappings(source: CorticalArea = null, destination: CorticalArea = null):
	if "edit_mappings" in loaded_windows.keys():
		loaded_windows["edit_mappings"].queue_free()
	
	print("user requests edit mappings window")
	var edit_mappings: WindowEditMappingDefinition = _prefab_edit_mappings.instantiate()
	add_child(edit_mappings)
	edit_mappings.setup(source, destination)
	loaded_windows["edit_mappings"] = edit_mappings

func spawn_create_cortical() -> void:
	print("hi")
	if "create_cortical" in loaded_windows.keys():
		loaded_windows["create_cortical"].queue_free()
	
	print("user requests create cortical window")
	var create_cortical: WindowCreateCorticalArea = _prefab_create_cortical.instantiate()
	add_child(create_cortical)
	loaded_windows["create_cortical"] = create_cortical

func force_close_window(window_name: StringName) -> void:
	if window_name in loaded_windows.keys():
		loaded_windows[window_name].queue_free()
		loaded_windows.erase(window_name)

func force_close_all_windows() -> void:
	print("UI: All windows being forced closed")
	for window in loaded_windows.keys():
		force_close_window(window)
