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
	"left_bar": {"position": Vector2(50,300)},
	"create_morphology": {"position": Vector2(400,300)},
	"edit_mappings": {"position": Vector2(900,150)},
	"create_cortical": {"position": Vector2(400,550)},
	"import_circuit": {"position": Vector2(400,850)},
	"quick_connect": {"position": Vector2(500,100)},
	"tutorial": {"position": Vector2(900,500)},
	"view_cortical": {"position": Vector2(50,100)},
	"clone_cortical": {"position": Vector2(400,550)},
	"import_amalgamation": {"position": Vector2(500,550)},
}

## Opens a left pane allowing the user to view and edit details of a particular cortical area
func spawn_left_panel(cortical_area: BaseCorticalArea) -> void:
	if "left_bar" in loaded_windows.keys():
		force_close_window("left_bar")
	
	var left_panel: WindowLeftPanel = _prefab_left_bar.instantiate()
	add_child(left_panel)
	left_panel.setup_single_area_from_FEAGI(cortical_area)
	left_panel.load_from_memory(_window_memory_states["left_bar"])
	left_panel.closed_window.connect(force_close_window)
	loaded_windows["left_bar"] = left_panel
	bring_window_to_top(left_panel)

func spawn_create_morphology() -> void:
	if "create_morphology" in loaded_windows.keys():
		force_close_window("create_morphology")
	
	var create_morphology: WindowCreateMorphology = _prefab_create_morphology.instantiate()
	add_child(create_morphology)
	create_morphology.load_from_memory(_window_memory_states["create_morphology"])
	create_morphology.closed_window.connect(force_close_window)
	loaded_windows["create_morphology"] = create_morphology
	bring_window_to_top(create_morphology)

func spawn_manager_morphology(morphology_to_preload: Morphology = null) -> void:
	var morphology_manager: WindowMorphologyManager = _default_spawn_window(_prefab_morphology_manager, "morphology_manager") as WindowMorphologyManager
	morphology_manager.setup("morphology_manager", morphology_to_preload)
	

func spawn_edit_mappings(source: BaseCorticalArea = null, destination: BaseCorticalArea = null, spawn_default_mapping_if_applicable_on_spawn = false):
	if "edit_mappings" in loaded_windows.keys():
		force_close_window("edit_mappings")
	
	print("user requests edit mappings window")
	var edit_mappings: WindowEditMappingDefinition = _prefab_edit_mappings.instantiate()
	add_child(edit_mappings)
	edit_mappings.load_from_memory(_window_memory_states["edit_mappings"])
	edit_mappings.closed_window.connect(force_close_window)
	edit_mappings.setup(source, destination, spawn_default_mapping_if_applicable_on_spawn)
	loaded_windows["edit_mappings"] = edit_mappings
	bring_window_to_top(edit_mappings)

func spawn_create_cortical() -> void:
	if "create_cortical" in loaded_windows.keys():
		force_close_window("create_cortical")
	
	print("user requests create cortical window")
	var create_cortical: WindowCreateCorticalArea = _prefab_create_cortical.instantiate()
	add_child(create_cortical)
	create_cortical.load_from_memory(_window_memory_states["create_cortical"])
	create_cortical.closed_window.connect(force_close_window)
	loaded_windows["create_cortical"] = create_cortical
	bring_window_to_top(create_cortical)

func spawn_clone_cortical(cloning_from: BaseCorticalArea) -> void:
	if "clone_cortical" in loaded_windows.keys():
		force_close_window("clone_cortical")
	
	print("user requests clone cortical window")
	var clone_cortical: WindowCloneCorticalArea = _prefab_clone_cortical.instantiate()
	add_child(clone_cortical)
	clone_cortical.load_from_memory(_window_memory_states["clone_cortical"])
	clone_cortical.closed_window.connect(force_close_window)
	clone_cortical.setup(cloning_from)
	loaded_windows["clone_cortical"] = clone_cortical
	bring_window_to_top(clone_cortical)

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
	if "quick_connect" in loaded_windows.keys():
		force_close_window("quick_connect")
	
	print("user requests create quick connect window")
	var quick_connect: WindowQuickConnect = _prefab_quick_connect.instantiate()
	add_child(quick_connect)
	quick_connect.load_from_memory(_window_memory_states["quick_connect"])
	quick_connect.closed_window.connect(force_close_window)
	loaded_windows["quick_connect"] = quick_connect
	quick_connect.setup(initial_source_area)
	bring_window_to_top(quick_connect)


func spawn_tutorial() -> void:
	if "tutorial" in loaded_windows.keys():
		force_close_window("tutorial")
	
	var tutorial: TutorialDisplay = _prefab_tutorial.instantiate()
	add_child(tutorial)
	tutorial.load_from_memory(_window_memory_states["tutorial"])
	tutorial.closed_window.connect(force_close_window)
	loaded_windows["tutorial"] = tutorial
	bring_window_to_top(tutorial)

func spawn_cortical_view() -> void:
	if "view_cortical" in loaded_windows.keys():
		force_close_window("view_cortical")	
	var view_cortical: WindowViewCorticalArea = _prefab_cortical_view.instantiate()
	add_child(view_cortical)
	view_cortical.load_from_memory(_window_memory_states["view_cortical"])
	view_cortical.closed_window.connect(force_close_window)
	loaded_windows["view_cortical"] = view_cortical
	bring_window_to_top(view_cortical)

func spawn_info_popup(title_text: StringName, message_text: StringName, button_text: StringName, icon: WindowPopupInfo.ICON = WindowPopupInfo.ICON.DEFAULT) -> void:
	var popup: WindowPopupInfo = _prefab_popup_info.instantiate()
	add_child(popup)
	popup.position = Vector2(200,200)
	popup.set_properties(title_text, message_text, button_text, icon)

func spawn_quick_cortical_menu(cortical_area: BaseCorticalArea) -> void:
	var quick_cortical_menu: QuickCorticalMenu = _default_spawn_window(_prefab_quick_cortical_menu, "quick_cortical_menu") as QuickCorticalMenu
	quick_cortical_menu.setup(cortical_area)

func spawn_delete_confirmation(cortical_area: BaseCorticalArea) -> void:
	if "delete_confirmation" in loaded_windows.keys():
		loaded_windows["delete_confirmation"].queue_free()
	
	var delete_confirmation: DeleteConfirmation = _prefab_confirm_deletion.instantiate()
	add_child(delete_confirmation)
	loaded_windows["delete_confirmation"] = delete_confirmation
	delete_confirmation.setup(cortical_area)
	delete_confirmation.closed_window.connect(force_close_window)
	bring_window_to_top(delete_confirmation)
	
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
		_window_memory_states[_window_memory_states] = new_window.export_default_window_details()
	else:
		new_window.import_window_details(_window_memory_states[window_name])
	bring_window_to_top(new_window)
	return new_window
