extends Node
class_name WindowManager
## Coordinates all the visible windows

const _PREFAB_CREATE_MORPHOLOGY: PackedScene = preload("res://BrainVisualizer/UI/Windows/CreateMorphology/WindowCreateMorphology.tscn")
const _PREFAB_MAPPING_EDITOR: PackedScene = preload("res://BrainVisualizer/UI/Windows/MappingEditor/WindowMappingEditor.tscn")
const _PREFAB_MORPHOLOGY_MANAGER: PackedScene = preload("res://BrainVisualizer/UI/Windows/MorphologyManager/WindowMorphologyManager.tscn")
const _PREFAB_CREATE_CORTICAL: PackedScene = preload("res://BrainVisualizer/UI/Windows/CreateCorticalArea/WindowCreateCorticalArea.tscn")
const _PREFAB_QUICK_CONNECT: PackedScene = preload("res://BrainVisualizer/UI/Windows/QuickConnect/WindowQuickConnect.tscn")
const _PREFAB_QUICK_CONNECT_NEURON: PackedScene = preload("res://BrainVisualizer/UI/Windows/QuickConnectNeuron/WindowQuickConnectNeuron.tscn")
const _PREFAB_CORTICAL_VIEW: PackedScene = preload("res://BrainVisualizer/UI/Windows/View_Cortical_Areas/WindowViewCorticalArea.tscn")
const _PREFAB_QUICK_MENU: PackedScene = preload("res://BrainVisualizer/UI/Windows/QuickMenu/WindowQuickMenu.tscn")
const _PREFAB_CLONE_CORTICAL: PackedScene = preload("res://BrainVisualizer/UI/Windows/CloneCorticalArea/WindowCloneCorticalArea.tscn")
const _PREFAB_IMPORT_AMALGAMATION: PackedScene = preload("res://BrainVisualizer/UI/Windows/AmalgamationRequest/WindowAmalgamationRequest.tscn")
const _PREFAB_CONFIGURABLE_POPUP: PackedScene = preload("res://BrainVisualizer/UI/Windows/ConfigurablePopup/WindowConfigurablePopup.tscn")
const _PREFAB_DEVELOPER_OPTIONS: PackedScene = preload("res://BrainVisualizer/UI/Windows/Developer_Options/WindowDeveloperOptions.tscn")
const _PREFAB_SELECT_GENOME_OBJECT: PackedScene = preload("res://BrainVisualizer/UI/Windows/SelectGenomeObject/WindowSelectGenomeObject.tscn")
const _PREFAB_CREATE_REGION: PackedScene = preload("res://BrainVisualizer/UI/Windows/CreateRegion/WindowCreateRegion.tscn")
const _PREFAB_EDIT_REGION: PackedScene = preload("res://BrainVisualizer/UI/Windows/EditRegion/WindowEditRegion.tscn")
const _PREFAB_MOVE_TO_REGION: PackedScene = preload("res://BrainVisualizer/UI/Windows/AddToRegion/WindowAddToRegion.tscn")
const _PREFAB_CONFIRM_DELETION: PackedScene = preload("res://BrainVisualizer/UI/Windows/ConfirmDeletion/WindowConfirmDeletion.tscn")
const _PREFAB_ADV_CORTICAL_PROPERTIES: PackedScene = preload("res://BrainVisualizer/UI/Windows/AdvancedCorticalProperties/AdvancedCorticalProperties.tscn")
const _PREFAB_OPTIONS: PackedScene = preload("res://BrainVisualizer/UI/Windows/OptionsMenu/WindowOptionsMenu.tscn")
const _PREFAB_VIEW_PREVIEWS: PackedScene = preload("res://BrainVisualizer/UI/Windows/ViewPreviews/WindowViewPreviews.tscn")


var loaded_windows: Dictionary

var _window_memory_states: Dictionary = {
}

func spawn_options() -> void:
	var options_window: WindowOptionsMenu = _default_spawn_window(_PREFAB_OPTIONS, WindowOptionsMenu.WINDOW_NAME) as WindowOptionsMenu
	options_window.setup()

func spawn_adv_cortical_properties(cortical_areas: Array[AbstractCorticalArea]) -> void:
	var cortical_window: AdvancedCorticalProperties = _default_spawn_window(_PREFAB_ADV_CORTICAL_PROPERTIES, AdvancedCorticalProperties.WINDOW_NAME) as AdvancedCorticalProperties
	cortical_window.setup(cortical_areas)

func spawn_create_morphology() -> void:
	var create_morphology: WindowCreateMorphology = _default_spawn_window(_PREFAB_CREATE_MORPHOLOGY, WindowCreateMorphology.WINDOW_NAME) as WindowCreateMorphology
	create_morphology.setup()

func spawn_manager_morphology(morphology_to_preload: BaseMorphology = null) -> void:
	var morphology_manager: WindowMorphologyManager = _default_spawn_window(_PREFAB_MORPHOLOGY_MANAGER, WindowMorphologyManager.WINDOW_NAME) as WindowMorphologyManager
	morphology_manager.setup(morphology_to_preload)

func spawn_developer_options() -> void:
	var developer_window: WindowDeveloperOptions = _default_spawn_window(_PREFAB_DEVELOPER_OPTIONS, WindowDeveloperOptions.WINDOW_NAME)
	developer_window.setup()

func spawn_mapping_editor(source: GenomeObject, destination: GenomeObject, partial_mapping: PartialMappingSet = null) -> WindowMappingEditor:
	var mapping_editor: WindowMappingEditor = _default_spawn_window(_PREFAB_MAPPING_EDITOR, WindowMappingEditor.WINDOW_NAME) as WindowMappingEditor
	mapping_editor.setup(source, destination, partial_mapping)
	return mapping_editor

func spawn_create_cortical() -> void:
	var create_cortical: WindowCreateCorticalArea = _default_spawn_window(_PREFAB_CREATE_CORTICAL, WindowCreateCorticalArea.WINDOW_NAME) as WindowCreateCorticalArea
	create_cortical.setup()

func spawn_confirm_deletion(objects_to_delete: Array[GenomeObject], is_deleting_single_region_internals_instead_of_raising: bool = false) -> void:
	var confirm_deletion: WindowConfirmDeletion = _default_spawn_window(_PREFAB_CONFIRM_DELETION, WindowConfirmDeletion.WINDOW_NAME) as WindowConfirmDeletion
	confirm_deletion.setup(objects_to_delete, is_deleting_single_region_internals_instead_of_raising)

func spawn_clone_cortical(cloning_from: AbstractCorticalArea) -> void:
	var clone_cortical: WindowCloneCorticalArea = _default_spawn_window(_PREFAB_CLONE_CORTICAL, WindowCloneCorticalArea.WINDOW_NAME) as WindowCloneCorticalArea
	clone_cortical.setup(cloning_from)

func spawn_quick_connect(initial_source_area: AbstractCorticalArea = null) -> void:
	var quick_connect: WindowQuickConnect = _default_spawn_window(_PREFAB_QUICK_CONNECT, WindowQuickConnect.WINDOW_NAME) as WindowQuickConnect
	quick_connect.setup(initial_source_area)

func spawn_quick_connect_neuron(mode: WindowQuickConnectNeuron.MODE, initial_source_area: AbstractCorticalArea = null) -> void:
	var quick_connect_neuron: WindowQuickConnectNeuron = _default_spawn_window(_PREFAB_QUICK_CONNECT_NEURON, WindowQuickConnectNeuron.WINDOW_NAME) as WindowQuickConnectNeuron
	quick_connect_neuron.setup(mode, initial_source_area)

func spawn_cortical_view() -> void:
	var view_cortical: WindowViewCorticalArea = _default_spawn_window(_PREFAB_CORTICAL_VIEW, WindowViewCorticalArea.WINDOW_NAME) as WindowViewCorticalArea
	view_cortical.setup()

func spawn_select_genome_object(view_config: SelectGenomeObjectSettings) -> WindowSelectGenomeObject:
	var select_genome_object: WindowSelectGenomeObject = _default_spawn_window(_PREFAB_SELECT_GENOME_OBJECT, WindowSelectGenomeObject.WINDOW_NAME) as WindowSelectGenomeObject
	select_genome_object.setup(view_config)
	return select_genome_object

func spawn_popup(popup_definition: ConfigurablePopupDefinition) -> WindowConfigurablePopup:
	var configurable_popup: WindowConfigurablePopup = _default_spawn_window(_PREFAB_CONFIGURABLE_POPUP, popup_definition.window_name) as WindowConfigurablePopup
	configurable_popup.setup(popup_definition)
	return configurable_popup

func spawn_create_region(parent_region: BrainRegion, selected_objects: Array[GenomeObject]) -> void:
	var create_region: WindowCreateRegion = _default_spawn_window(_PREFAB_CREATE_REGION, WindowCreateRegion.WINDOW_NAME) as WindowCreateRegion
	create_region.setup(parent_region, selected_objects)

func spawn_edit_region(editing_region: BrainRegion) -> void:
	var edit_region: WindowEditRegion = _default_spawn_window(_PREFAB_EDIT_REGION, WindowEditRegion.WINDOW_NAME) as WindowEditRegion
	edit_region.setup(editing_region)

func spawn_3d_brain_monitor_tab(region: BrainRegion) -> void:
	print("🚨🚨🚨 WindowManager: spawn_3d_brain_monitor_tab() CALLED!")
	print("🚨🚨🚨 WindowManager: Method reached successfully!")
	print("🚨🚨🚨 WindowManager: Region parameter: %s" % (region.friendly_name if region else "NULL"))
	
	if region == null:
		push_error("WindowManager: spawn_3d_brain_monitor_tab called with NULL region!")
		return
		
	print("🧠 WindowManager: Spawning 3D brain monitor tab for region: %s" % region.friendly_name)
	print("🚨 SPLIT VIEW DEBUG: Starting spawn_3d_brain_monitor_tab process")
	print("  🔍 REGION ANALYSIS:")
	print("    - Region ID: %s" % region.region_ID)
	print("    - Is root region: %s" % region.is_root_region())
	print("    - Contains %d cortical areas" % region.contained_cortical_areas.size())
	print("    - Contains %d child regions" % region.contained_regions.size())
	print("    - Parent region: %s" % (region.current_parent_region.friendly_name if region.current_parent_region else "None"))
	
	# List the cortical areas in this region
	print("  📋 CORTICAL AREAS IN THIS REGION:")
	for i in region.contained_cortical_areas.size():
		var area = region.contained_cortical_areas[i]
		print("    %d. %s (type: %s)" % [i+1, area.cortical_ID, area.type_as_string])
	
	print("🚨 WindowManager: Getting root UI view...")
	print("🚨 WindowManager: BV.UI is: %s" % BV.UI)
	
	var root_UI_view: UIView = BV.UI.root_UI_view
	print("🚨 WindowManager: root_UI_view is: %s" % root_UI_view)
	
	if root_UI_view == null:
		push_error("WindowManager: Unable to spawn 3D brain monitor tab - no root UI view found!")
		return
	
	print("🧠 WindowManager: Root UI view mode: %s" % root_UI_view.mode)
	
	# Set up split view if not already in split mode
	print("🧠 WindowManager: Current UI view mode: %s" % root_UI_view.mode)
	if root_UI_view.mode != UIView.MODE.SPLIT:
		print("🧠 WindowManager: Switching to split view mode")
		root_UI_view.setup_as_split()
		print("🧠 WindowManager: Split view setup complete, new mode: %s" % root_UI_view.mode)
	else:
		print("🧠 WindowManager: Already in split view mode")
	
	# Get the secondary tab container for the brain monitor
	print("🧠 WindowManager: Getting secondary tab container...")
	var secondary_tab_container: UITabContainer = root_UI_view.get_secondary_tab_container()
	if secondary_tab_container == null:
		push_error("WindowManager: No secondary tab container found after split setup!")
		return
	print("🧠 WindowManager: ✅ Secondary tab container found: %s" % secondary_tab_container)
	
	print("🧠 WindowManager: Found secondary tab container with %d tabs" % secondary_tab_container.get_child_count())
	
	# Create the BM tab in the secondary container
	print("🧠 WindowManager: Creating brain monitor in secondary container...")
	print("🧠 WindowManager: FORCE creating new instance (not reusing existing)")
	print("🔥🔥🔥 ABOUT TO CALL spawn_BM_of_region 🔥🔥🔥")
	secondary_tab_container.spawn_BM_of_region(region)  # Direct call bypasses existing tab check
	print("🔥🔥🔥 FINISHED CALLING spawn_BM_of_region 🔥🔥🔥")
	print("🧠 WindowManager: Brain monitor tab created successfully")
	
	# 🚨 CRITICAL: Force focus on the new tab 
	print("🧠 WindowManager: Forcing focus on secondary container tab...")
	print("🔥🔥🔥 SECONDARY CONTAINER CHILD COUNT: %d 🔥🔥🔥" % secondary_tab_container.get_child_count())
	if secondary_tab_container.get_child_count() > 0:
		var last_tab_index = secondary_tab_container.get_child_count() - 1
		secondary_tab_container.current_tab = last_tab_index
		print("🧠 WindowManager: Set secondary container current_tab to: %d" % last_tab_index)
		
		# Log all children
		for i in secondary_tab_container.get_child_count():
			var child = secondary_tab_container.get_child(i)
			print("🔥 CHILD %d: %s (instance: %d) 🔥" % [i, child, child.get_instance_id()])
		
		# Add a UI notification to help the user
		BV.NOTIF.add_notification("🚨 SPLIT VIEW ACTIVE! Look for TWO separate 3D brain monitors. NEW tab '%s' is in SECONDARY panel. Look for yellow text label!" % region.friendly_name)
		
		# 🚨 CRITICAL DEBUG: Verify split view is actually visible
		print("🚨 CRITICAL VERIFICATION:")
		print("  📺 You should now see TWO separate 3D brain monitor panels side by side")
		print("  📺 PRIMARY panel (left/top): Shows main brain monitor with ALL cortical areas")
		print("  📺 SECONDARY panel (right/bottom): Shows NEW '%s' tab with %d cortical areas" % [region.friendly_name, region.contained_cortical_areas.size()])
		print("  🟡 Look for BRIGHT YELLOW text label saying 'TAB: %s' in the secondary panel!" % region.friendly_name)
		print("  🚨 If you only see ONE brain monitor, the split view is not working!")
		
		# Also check what's in primary vs secondary
		print("🧠 WindowManager: Primary container (should have main BM)")
		print("🧠 WindowManager: Secondary container has %d tabs (should have new BM for %s)" % [secondary_tab_container.get_child_count(), region.friendly_name])
		
		# Get the actual brain monitor instance that was just created
		if secondary_tab_container.get_child_count() > 0:
			var new_tab = secondary_tab_container.get_child(last_tab_index)
			if new_tab is UI_BrainMonitor_3DScene:
				var new_bm = new_tab as UI_BrainMonitor_3DScene
				print("🧠 WindowManager: New brain monitor created with name: %s" % new_bm.name)
				if new_bm.representing_region != null:
					print("🧠 WindowManager: New brain monitor represents region: %s" % new_bm.representing_region.friendly_name)
				else:
					print("🧠 WindowManager: New brain monitor setup is deferred - region will be set shortly")
				print("🧠 WindowManager: Target region was: %s" % region.friendly_name)
						
	print("🚨🚨🚨 WindowManager: spawn_3d_brain_monitor_tab() COMPLETED SUCCESSFULLY!")
	print("🚨🚨🚨 WindowManager: Method finished - returning to caller")

func spawn_move_to_region(objects: Array[GenomeObject], starting_region: BrainRegion) -> void:
	var move_to_region: WindowAddToRegion = _default_spawn_window(_PREFAB_MOVE_TO_REGION, WindowAddToRegion.WINDOW_NAME) as WindowAddToRegion
	move_to_region.setup(objects, starting_region)

func spawn_quick_cortical_menu(selected_objects: Array[GenomeObject]) -> void:
	var quick_cortical_menu: QuickCorticalMenu = _default_spawn_window(_PREFAB_QUICK_MENU, QuickCorticalMenu.WINDOW_NAME) as QuickCorticalMenu
	quick_cortical_menu.setup(selected_objects)

func spawn_view_previews() -> void:
	var view_previews: WindowViewPreviews = _default_spawn_window(_PREFAB_VIEW_PREVIEWS, WindowViewPreviews.WINDOW_NAME) as WindowViewPreviews
	view_previews.setup()

func spawn_amalgamation_window(amalgamation_ID: StringName, genome_title: StringName, circuit_size: Vector3i) -> void:
	if "import_amalgamation" in loaded_windows:
		return # no need to keep opening this window
	var import_amalgamation: WindowAmalgamationRequest = _default_spawn_window(_PREFAB_IMPORT_AMALGAMATION, WindowAmalgamationRequest.WINDOW_NAME) as WindowAmalgamationRequest
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

func _default_spawn_window(prefab: PackedScene, window_name: StringName, force_close_if_open: bool = true) -> BaseDraggableWindow:
	if (window_name in loaded_windows.keys()) && force_close_if_open:
		loaded_windows[window_name].close_window()
	var new_window: BaseDraggableWindow = prefab.instantiate()
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
	new_window.bring_window_to_top_request.connect(_bring_window_to_top_str)
	return new_window

func _bring_window_to_top_str(window_name: StringName) -> void:
	if !(window_name in loaded_windows):
		push_error("WindowManager: Unknown window %s!" % window_name)
		return
	bring_window_to_top(loaded_windows[window_name])
