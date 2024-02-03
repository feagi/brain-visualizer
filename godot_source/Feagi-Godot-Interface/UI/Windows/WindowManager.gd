extends Node
class_name WindowManager
## Coordinates all the visible windows

var _prefab_left_bar: PackedScene = preload("res://Feagi-Godot-Interface/UI/Windows/Draggable_Windows/Left_Bar/WindowLeftPanel.tscn")
var _prefab_create_morphology: PackedScene = preload("res://Feagi-Godot-Interface/UI/Windows/Draggable_Windows/Create_Morphology/WindowCreateMorphology.tscn")
var _prefab_edit_mappings: PackedScene = preload("res://Feagi-Godot-Interface/UI/Windows/Draggable_Windows/Mapping_Definition/WindowEditMappingDefinition.tscn")
var _prefab_morphology_manager: PackedScene = preload("res://Feagi-Godot-Interface/UI/Windows/Draggable_Windows/Morphology_Manager/WindowMorphologyManager.tscn")
var _prefab_create_cortical: PackedScene = preload("res://Feagi-Godot-Interface/UI/Windows/Draggable_Windows/Create_Cortical_Area/WindowCreateCorticalArea.tscn")
var _prefab_import_circuit: PackedScene = preload("res://Feagi-Godot-Interface/UI/Windows/Draggable_Windows/Import_Circuit/Import_Circuit.tscn")
var _prefab_quick_connect: PackedScene = preload("res://Feagi-Godot-Interface/UI/Windows/Draggable_Windows/QuickConnect/WindowQuickConnect.tscn")
var _prefab_popup_info: PackedScene = preload("res://Feagi-Godot-Interface/UI/Windows/Draggable_Windows/Popups/Info/WindowPopupInfo.tscn")
var _prefab_tutorial: PackedScene = preload("res://Feagi-Godot-Interface/UI/Windows/Draggable_Windows/Tutorial/TutorialDisplay.tscn")
var _prefab_cortical_view: PackedScene = preload("res://Feagi-Godot-Interface/UI/Windows/Draggable_Windows/View_Cortical_Areas/WindowViewCorticalArea.tscn")
var _prefab_quick_cortical_menu: PackedScene = preload("res://Feagi-Godot-Interface/UI/Windows/Draggable_Windows/Quick_Cortical_Menu/QuickCorticalMenu.tscn")
var _prefab_confirm_deletion: PackedScene = preload("res://Feagi-Godot-Interface/UI/Windows/Draggable_Windows/Delete_Confirmation/DeleteConfirmation.tscn")
var _prefab_clone_cortical: PackedScene = preload("res://Feagi-Godot-Interface/UI/Windows/Draggable_Windows/Clone_Cortical_Area/WindowCloneCorticalArea.tscn")
var _prefab_import_amalgamation: PackedScene = preload("res://Feagi-Godot-Interface/UI/Windows/Draggable_Windows/Amalgamation_Request/WindowAmalgamationRequest.tscn")

var loaded_windows: Dictionary

var _window_memory_states: Dictionary = {
	"import_circuit": {"position": Vector2(400,850)},
}

## Opens a left pane allowing the user to view and edit details of a particular cortical area
func spawn_left_panel(cortical_area: BaseCorticalArea) -> void:
	var left_bar: WindowLeftPanel = _default_spawn_window(_prefab_left_bar, "left_bar") as WindowLeftPanel
	left_bar.setup(cortical_area)

func spawn_create_morphology() -> void:
	var create_morphology: WindowCreateMorphology = _default_spawn_window(_prefab_create_morphology, "create_morphology") as WindowCreateMorphology
	create_morphology.setup()

func spawn_manager_morphology(morphology_to_preload: Morphology = null) -> void:
	var morphology_manager: WindowMorphologyManager = _default_spawn_window(_prefab_morphology_manager, "morphology_manager") as WindowMorphologyManager
	morphology_manager.setup(morphology_to_preload)
	
func spawn_edit_mappings(source: BaseCorticalArea = null, destination: BaseCorticalArea = null, spawn_default_mapping_if_applicable_on_spawn = false):
	var edit_mappings: WindowEditMappingDefinition = _default_spawn_window(_prefab_edit_mappings, "edit_mappings") as WindowEditMappingDefinition
	edit_mappings.setup(source, destination, spawn_default_mapping_if_applicable_on_spawn)

func spawn_create_cortical() -> void:
	var create_cortical: WindowCreateCorticalArea = _default_spawn_window(_prefab_create_cortical, "create_cortical") as WindowCreateCorticalArea
	create_cortical.setup()

func spawn_clone_cortical(cloning_from: BaseCorticalArea) -> void:
	var clone_cortical: WindowCloneCorticalArea = _default_spawn_window(_prefab_clone_cortical, "clone_cortical") as WindowCloneCorticalArea
	clone_cortical.setup(cloning_from)

#TODO DELETE
func spawn_import_circuit() -> void:
	if "import_circuit" in loaded_windows.keys():
		force_close_window("import_circuit")
	
	print("user requests create import circuit window")
	var import_circuit: WindowImportCircuit = _prefab_import_circuit.instantiate()
	add_child(import_circuit)
	import_circuit.load_from_memory(_window_memory_states["import_circuit"])
	import_circuit.closed_window.connect(force_close_window)
	loaded_windows["import_circuit"] = import_circuit
	bring_window_to_top(import_circuit)

func spawn_quick_connect(initial_source_area: BaseCorticalArea = null) -> void:
	var quick_connect: WindowQuickConnect = _default_spawn_window(_prefab_quick_connect, "quick_connect") as WindowQuickConnect
	quick_connect.setup(initial_source_area)

func spawn_tutorial() -> void:
	var tutorial: TutorialDisplay = _default_spawn_window(_prefab_tutorial, "tutorial") as TutorialDisplay
	tutorial.setup()

func spawn_cortical_view() -> void:
	var view_cortical: WindowViewCorticalArea = _default_spawn_window(_prefab_cortical_view, "view_cortical") as WindowViewCorticalArea
	view_cortical.setup()

func spawn_info_popup(title_text: StringName, message_text: StringName, button_text: StringName, icon: WindowPopupInfo.ICON = WindowPopupInfo.ICON.DEFAULT) -> void:
	var popup: WindowPopupInfo = _prefab_popup_info.instantiate()
	add_child(popup)
	popup.position = Vector2(200,200)
	popup.set_properties(title_text, message_text, button_text, icon)

func spawn_quick_cortical_menu(cortical_area: BaseCorticalArea) -> void:
	var quick_cortical_menu: QuickCorticalMenu = _default_spawn_window(_prefab_quick_cortical_menu, "quick_cortical_menu") as QuickCorticalMenu
	quick_cortical_menu.setup(cortical_area)

func spawn_delete_confirmation(cortical_area: BaseCorticalArea) -> void:
	var delete_confirmation: DeleteConfirmation = _default_spawn_window(_prefab_confirm_deletion, "delete_confirmation") as DeleteConfirmation
	delete_confirmation.setup(cortical_area)
	
func spawn_amalgamation_window(amalgamation_ID: StringName, genome_title: StringName, circuit_size: Vector3i) -> void:
	var import_amalgamation: WindowAmalgamationRequest = _default_spawn_window(_prefab_import_amalgamation, "import_amalgamation") as WindowAmalgamationRequest
	import_amalgamation.setup(amalgamation_ID, genome_title, circuit_size)

func force_close_window(window_name: StringName) -> void:
	if window_name in loaded_windows.keys():
		_window_memory_states[window_name] = loaded_windows[window_name].export_window_details()
		loaded_windows[window_name].queue_free()
		loaded_windows.erase(window_name)

func bring_window_to_top(window: Control) -> void:
		print("UI: WINDOW: Changing window order...")
		move_child(window, -1)

func force_close_all_windows() -> void:
	print("UI: All windows being forced closed")
	for window in loaded_windows.keys():
		force_close_window(window)

func _default_spawn_window(prefab: PackedScene, window_name: StringName, force_close_if_open: bool = true) -> BaseWindowPanel:
	if (window_name in loaded_windows.keys()) && force_close_if_open:
		force_close_window(window_name)
	var new_window: BaseWindowPanel = prefab.instantiate()
	add_child(new_window)
	loaded_windows[window_name] = new_window
	new_window.close_window_requested.connect(force_close_window)
	# if we have no memopry of the window, load the defaults from the window itself
	if window_name not in _window_memory_states:
		_window_memory_states[window_name] = new_window.export_default_window_details()
	else:
		new_window.import_window_details(_window_memory_states[window_name])
	new_window.position = _window_memory_states[window_name]["position"]
	bring_window_to_top(new_window)
	return new_window