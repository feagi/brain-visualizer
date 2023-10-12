extends Node
class_name WindowManager
## Coordinates all the visible windows

var _prefab_left_bar: PackedScene = preload("res://Feagi-Godot-Interface/UI/Windows/Draggable_Windows/Left_Bar/WindowLeftPanel.tscn")
var _prefab_create_morphology: PackedScene = preload("res://Feagi-Godot-Interface/UI/Windows/Draggable_Windows/Create_Morphology/WindowCreateMorphology.tscn")
var _prefab_edit_mappings: PackedScene = preload("res://Feagi-Godot-Interface/UI/Windows/Draggable_Windows/Mapping_Definition/WindowEditMappingDefinition.tscn")
var _prefab_morphology_manager: PackedScene = preload("res://Feagi-Godot-Interface/UI/Windows/Draggable_Windows/Morphology_Manager/WindowMorphologyManager.tscn")
var _prefab_create_cortical: PackedScene = preload("res://Feagi-Godot-Interface/UI/Windows/Draggable_Windows/Create_Cortical_Area/WindowCreateCorticalArea.tscn")
var _prefab_import_circuit: PackedScene = preload("res://Feagi-Godot-Interface/UI/Windows/Draggable_Windows/Import_Circuit/Import_Circuit.tscn")
var _prefab_popup_info: PackedScene = preload("res://Feagi-Godot-Interface/UI/Windows/Draggable_Windows/Popups/Info/WindowPopupInfo.tscn")

var loaded_windows: Dictionary

var _window_memory_states: Dictionary = {
	"left_bar": {"position": Vector2(100,100)},
	"create_morphology": {"position": Vector2(50,100)},
	"morphology_manager": {"position": Vector2(50,100)},
	"edit_mappings": {"position": Vector2(50,100)},
	"create_cortical": {"position": Vector2(50,100)},
	"import_circuit": {"position": Vector2(50,100)}
}

## Opens a left pane allowing the user to view and edit details of a particular cortical area
func spawn_left_panel(cortical_area: CorticalArea) -> void:
	if "left_bar" in loaded_windows.keys():
		force_close_window("left_bar")
	
	var left_panel: WindowLeftPanel = _prefab_left_bar.instantiate()
	add_child(left_panel)
	left_panel.setup_from_FEAGI(cortical_area)
	left_panel.load_from_memory(_window_memory_states["left_bar"])
	left_panel.closed_window.connect(force_close_window)
	loaded_windows["left_bar"] = left_panel

func spawn_create_morphology() -> void:
	if "create_morphology" in loaded_windows.keys():
		force_close_window("create_morphology")
	
	var create_morphology: WindowCreateMorphology = _prefab_create_morphology.instantiate()
	add_child(create_morphology)
	create_morphology.load_from_memory(_window_memory_states["create_morphology"])
	create_morphology.closed_window.connect(force_close_window)
	loaded_windows["create_morphology"] = create_morphology

func spawn_manager_morphology(morphology_to_preload: Morphology = null) -> void:
	#TODO add morphology preloading support
	if "morphology_manager" in loaded_windows.keys():
		force_close_window("morphology_manager")
	
	var morphology_manager: WindowMorphologyManager = _prefab_morphology_manager.instantiate()
	add_child(morphology_manager)
	morphology_manager.load_from_memory(_window_memory_states["morphology_manager"])
	morphology_manager.closed_window.connect(force_close_window)
	loaded_windows["morphology_manager"] = morphology_manager

func spawn_edit_mappings(source: CorticalArea = null, destination: CorticalArea = null):
	if "edit_mappings" in loaded_windows.keys():
		force_close_window("edit_mappings")
	
	print("user requests edit mappings window")
	var edit_mappings: WindowEditMappingDefinition = _prefab_edit_mappings.instantiate()
	add_child(edit_mappings)
	edit_mappings.load_from_memory(_window_memory_states["edit_mappings"])
	edit_mappings.closed_window.connect(force_close_window)
	edit_mappings.setup(source, destination)
	loaded_windows["edit_mappings"] = edit_mappings

func spawn_create_cortical() -> void:
	if "create_cortical" in loaded_windows.keys():
		force_close_window("create_cortical")
	
	print("user requests create cortical window")
	var create_cortical: WindowCreateCorticalArea = _prefab_create_cortical.instantiate()
	add_child(create_cortical)
	create_cortical.load_from_memory(_window_memory_states["create_cortical"])
	create_cortical.closed_window.connect(force_close_window)
	loaded_windows["create_cortical"] = create_cortical

func spawn_import_circuit() -> void:
	if "import_circuit" in loaded_windows.keys():
		force_close_window("import_circuit")
	
	print("user requests create import circuit window")
	var import_circuit: WindowImportCircuit = _prefab_import_circuit.instantiate()
	add_child(import_circuit)
	import_circuit.load_from_memory(_window_memory_states["import_circuit"])
	import_circuit.closed_window.connect(force_close_window)
	loaded_windows["import_circuit"] = import_circuit

func spawn_info_popup(title_text: StringName, message_text: StringName, button_text: StringName, icon: WindowPopupInfo.ICON = WindowPopupInfo.ICON.DEFAULT) -> void:
	var popup: WindowPopupInfo = _prefab_popup_info.instantiate()
	add_child(popup)
	popup.position = Vector2(200,200)
	popup.set_properties(title_text, message_text, button_text, icon)
	

func force_close_window(window_name: StringName) -> void:
	if window_name in loaded_windows.keys():
		_window_memory_states[window_name] = loaded_windows[window_name].save_to_memory()
		loaded_windows[window_name].queue_free()
		loaded_windows.erase(window_name)

func force_close_all_windows() -> void:
	print("UI: All windows being forced closed")
	for window in loaded_windows.keys():
		force_close_window(window)
