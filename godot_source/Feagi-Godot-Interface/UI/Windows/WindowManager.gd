extends Node
class_name WindowManager
## Coordinates all the visible windows

const _prefab_cortical_properties: PackedScene = preload("res://Feagi-Godot-Interface/UI/Windows/Draggable_Windows/Cortical_Properties/WindowCorticalProperties.tscn")
const _prefab_create_morphology: PackedScene = preload("res://Feagi-Godot-Interface/UI/Windows/Draggable_Windows/Create_Morphology/WindowCreateMorphology.tscn")
const _prefab_edit_mappings: PackedScene = preload("res://Feagi-Godot-Interface/UI/Windows/Draggable_Windows/Mapping_Definition/WindowEditMappingDefinition.tscn")
const _prefab_morphology_manager: PackedScene = preload("res://Feagi-Godot-Interface/UI/Windows/Draggable_Windows/Morphology_Manager/WindowMorphologyManager.tscn")
const _prefab_create_cortical: PackedScene = preload("res://Feagi-Godot-Interface/UI/Windows/Draggable_Windows/Create_Cortical_Area/WindowCreateCorticalArea.tscn")
const _prefab_quick_connect: PackedScene = preload("res://Feagi-Godot-Interface/UI/Windows/Draggable_Windows/QuickConnect/WindowQuickConnect.tscn")
const _prefab_tutorial: PackedScene = preload("res://Feagi-Godot-Interface/UI/Windows/Draggable_Windows/Tutorial/TutorialDisplay.tscn")
const _prefab_cortical_view: PackedScene = preload("res://Feagi-Godot-Interface/UI/Windows/Draggable_Windows/View_Cortical_Areas/WindowViewCorticalArea.tscn")
const _prefab_quick_cortical_menu: PackedScene = preload("res://Feagi-Godot-Interface/UI/Windows/Draggable_Windows/Quick_Cortical_Menu/QuickCorticalMenu.tscn")
const _prefab_clone_cortical: PackedScene = preload("res://Feagi-Godot-Interface/UI/Windows/Draggable_Windows/Clone_Cortical_Area/WindowCloneCorticalArea.tscn")
const _prefab_import_amalgamation: PackedScene = preload("res://Feagi-Godot-Interface/UI/Windows/Draggable_Windows/Amalgamation_Request/WindowAmalgamationRequest.tscn")
const _prefab_configurable_popup: PackedScene = preload("res://Feagi-Godot-Interface/UI/Windows/Draggable_Windows/Configurable_Popup/WindowConfigurablePopup.tscn")


var loaded_windows: Dictionary

var _window_memory_states: Dictionary = {
	"import_circuit": {"position": Vector2(400,850)},
}

## Opens a left pane allowing the user to view and edit details of a particular cortical area
func spawn_cortical_properties(cortical_area: BaseCorticalArea) -> void:
	var left_bar: WindowCorticalProperties = _default_spawn_window(_prefab_cortical_properties, "left_bar") as WindowCorticalProperties
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

func spawn_quick_connect(initial_source_area: BaseCorticalArea = null) -> void:
	var quick_connect: WindowQuickConnect = _default_spawn_window(_prefab_quick_connect, "quick_connect") as WindowQuickConnect
	quick_connect.setup(initial_source_area)

func spawn_tutorial() -> void:
	var tutorial: TutorialDisplay = _default_spawn_window(_prefab_tutorial, "tutorial") as TutorialDisplay
	tutorial.setup()

func spawn_cortical_view() -> void:
	var view_cortical: WindowViewCorticalArea = _default_spawn_window(_prefab_cortical_view, "view_cortical") as WindowViewCorticalArea
	view_cortical.setup()

func spawn_popup(popup_definition: ConfigurablePopupDefinition) -> void:
	var configurable_popup: WindowConfigurablePopup = _default_spawn_window(_prefab_configurable_popup, popup_definition.window_name) as WindowConfigurablePopup
	configurable_popup.setup(popup_definition)

func spawn_quick_cortical_menu(cortical_area: BaseCorticalArea) -> void:
	if "quick_connect" in loaded_windows:
		return # dont open this window if quick connect is open!
	var quick_cortical_menu: QuickCorticalMenu = _default_spawn_window(_prefab_quick_cortical_menu, "quick_cortical_menu") as QuickCorticalMenu
	quick_cortical_menu.setup(cortical_area)
	
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
