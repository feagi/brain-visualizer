extends Node
class_name WindowManager
## Coordinates all the visible windows

const _PREFAB_CREATE_MORPHOLOGY: PackedScene = preload("res://BrainVisualizer/UI/Windows/CreateMorphology/WindowCreateMorphology.tscn")
const _PREFAB_MAPPING_EDITOR: PackedScene = preload("res://BrainVisualizer/UI/Windows/MappingEditor/WindowMappingEditor.tscn")
const _PREFAB_MORPHOLOGY_MANAGER: PackedScene = preload("res://BrainVisualizer/UI/Windows/MorphologyManager/WindowMorphologyManager.tscn")
const _PREFAB_CREATE_CORTICAL: PackedScene = preload("res://BrainVisualizer/UI/Windows/CreateCorticalArea/WindowCreateCorticalArea.tscn")
const _PREFAB_SELECT_CORTICAL_TEMPLATE: PackedScene = preload("res://BrainVisualizer/UI/Windows/SelectCorticalTemplate/WindowSelectCorticalTemplate.tscn")
const _PREFAB_QUICK_CONNECT: PackedScene = preload("res://BrainVisualizer/UI/Windows/QuickConnect/WindowQuickConnect.tscn")
const _PREFAB_QUICK_CONNECT_NEURON: PackedScene = preload("res://BrainVisualizer/UI/Windows/QuickConnectNeuron/WindowQuickConnectNeuron.tscn")
const _PREFAB_CORTICAL_VIEW: PackedScene = preload("res://BrainVisualizer/UI/Windows/View_Cortical_Areas/WindowViewCorticalArea.tscn")
const _PREFAB_BRAIN_REGIONS_VIEW: PackedScene = preload("res://BrainVisualizer/UI/Windows/View_Brain_Regions/WindowViewBrainRegions.tscn")
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

func spawn_create_cortical_with_type(cortical_type: int) -> void:
    var selector: WindowSelectCorticalTemplate = _default_spawn_window(_PREFAB_SELECT_CORTICAL_TEMPLATE, WindowSelectCorticalTemplate.WINDOW_NAME) as WindowSelectCorticalTemplate
    selector.setup_for_type(cortical_type)
    selector.template_chosen.connect(func(template: CorticalTemplate):
        var create_cortical: WindowCreateCorticalArea = _default_spawn_window(_PREFAB_CREATE_CORTICAL, WindowCreateCorticalArea.WINDOW_NAME) as WindowCreateCorticalArea
        create_cortical.setup_with_type(cortical_type)
        create_cortical._IOPU_definition.apply_preselected_template(template)
    )

func spawn_create_cortical_for_region(context_region: BrainRegion) -> void:
	var create_cortical: WindowCreateCorticalArea = _default_spawn_window(_PREFAB_CREATE_CORTICAL, WindowCreateCorticalArea.WINDOW_NAME) as WindowCreateCorticalArea
	create_cortical.setup_for_region(context_region)
	bring_window_to_top(create_cortical)

func spawn_create_cortical_with_type_for_region(context_region: BrainRegion, cortical_type: int) -> void:
    var selector: WindowSelectCorticalTemplate = _default_spawn_window(_PREFAB_SELECT_CORTICAL_TEMPLATE, WindowSelectCorticalTemplate.WINDOW_NAME) as WindowSelectCorticalTemplate
    selector.setup_for_type(cortical_type, context_region)
    selector.template_chosen.connect(func(template: CorticalTemplate):
        var create_cortical: WindowCreateCorticalArea = _default_spawn_window(_PREFAB_CREATE_CORTICAL, WindowCreateCorticalArea.WINDOW_NAME) as WindowCreateCorticalArea
        create_cortical.setup_with_type_for_region(context_region, cortical_type)
        create_cortical._IOPU_definition.apply_preselected_template(template)
    )

func spawn_confirm_deletion(objects_to_delete: Array[GenomeObject], is_deleting_single_region_internals_instead_of_raising: bool = false) -> void:
	var confirm_deletion: WindowConfirmDeletion = _default_spawn_window(_PREFAB_CONFIRM_DELETION, WindowConfirmDeletion.WINDOW_NAME) as WindowConfirmDeletion
	confirm_deletion.setup(objects_to_delete, is_deleting_single_region_internals_instead_of_raising)

func spawn_clone_cortical(cloning_from: AbstractCorticalArea) -> void:
	var clone_cortical: WindowCloneCorticalArea = _default_spawn_window(_PREFAB_CLONE_CORTICAL, WindowCloneCorticalArea.WINDOW_NAME) as WindowCloneCorticalArea
	clone_cortical.setup(cloning_from)

func spawn_clone_region(source_region: BrainRegion) -> void:
	var import_amalgamation: WindowAmalgamationRequest = _default_spawn_window(_PREFAB_IMPORT_AMALGAMATION, WindowAmalgamationRequest.WINDOW_NAME) as WindowAmalgamationRequest
	
	# Calculate default position: same Y and Z as source, X = rightmost edge + 10 unit gap
	var default_position = _calculate_clone_default_position(source_region)
	
	import_amalgamation.setup_for_clone(source_region, source_region.friendly_name + &"_clone", default_position)

func spawn_quick_connect(initial_source_area: AbstractCorticalArea = null) -> void:
	var quick_connect: WindowQuickConnect = _default_spawn_window(_PREFAB_QUICK_CONNECT, WindowQuickConnect.WINDOW_NAME) as WindowQuickConnect
	quick_connect.setup(initial_source_area)

func spawn_quick_connect_neuron(mode: WindowQuickConnectNeuron.MODE, initial_source_area: AbstractCorticalArea = null) -> void:
	var quick_connect_neuron: WindowQuickConnectNeuron = _default_spawn_window(_PREFAB_QUICK_CONNECT_NEURON, WindowQuickConnectNeuron.WINDOW_NAME) as WindowQuickConnectNeuron
	quick_connect_neuron.setup(mode, initial_source_area)

func spawn_cortical_view() -> void:
	var view_cortical: WindowViewCorticalArea = _default_spawn_window(_PREFAB_CORTICAL_VIEW, WindowViewCorticalArea.WINDOW_NAME) as WindowViewCorticalArea
	view_cortical.setup()

func spawn_brain_regions_view() -> void:
	var view_regions: WindowViewBrainRegions = _default_spawn_window(_PREFAB_BRAIN_REGIONS_VIEW, WindowViewBrainRegions.WINDOW_NAME) as WindowViewBrainRegions
	view_regions.setup()

func spawn_brain_regions_view_with_context(context_region: BrainRegion, on_focus: Callable) -> void:
	var view_regions: WindowViewBrainRegions = _default_spawn_window(_PREFAB_BRAIN_REGIONS_VIEW, WindowViewBrainRegions.WINDOW_NAME) as WindowViewBrainRegions
	view_regions.setup_with_context(context_region, on_focus)

func spawn_cortical_view_with_context(context_region: BrainRegion, on_focus: Callable) -> void:
	var view_cortical: WindowViewCorticalArea = _default_spawn_window(_PREFAB_CORTICAL_VIEW, WindowViewCorticalArea.WINDOW_NAME) as WindowViewCorticalArea
	view_cortical.setup_with_context(context_region, on_focus)

func spawn_cortical_view_filtered(type_filter: int) -> void:
	var view_cortical: WindowViewCorticalArea = _default_spawn_window(_PREFAB_CORTICAL_VIEW, WindowViewCorticalArea.WINDOW_NAME) as WindowViewCorticalArea
	view_cortical.setup_filtered(type_filter)

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
	if region == null:
		push_error("WindowManager: spawn_3d_brain_monitor_tab called with NULL region!")
		return
	
	var root_UI_view: UIView = BV.UI.root_UI_view
	if root_UI_view == null:
		push_error("WindowManager: Unable to spawn 3D brain monitor tab - no root UI view found!")
		return
	
	# Automatically activate split view if not already active
	if root_UI_view.mode != UIView.MODE.SPLIT:
		root_UI_view.setup_as_split()
	
	# CRITICAL: Also activate the VISUAL TempSplit system if it's closed
	var temp_split = BV.UI.get_node("CB_Holder") as TempSplit
	if temp_split != null and temp_split.current_state == TempSplit.STATES.CB_CLOSED:
		temp_split.set_view(TempSplit.STATES.CB_HORIZONTAL)
	
	# Get both tab containers
	var primary_tab_container: UITabContainer = root_UI_view._get_primary_child() as UITabContainer
	var secondary_tab_container: UITabContainer = root_UI_view.get_secondary_tab_container()
	
	if primary_tab_container == null or secondary_tab_container == null:
		push_error("WindowManager: Tab containers not found after split setup!")
		return
	
	# Create both CB and BM tabs for the same region
	primary_tab_container.spawn_CB_of_region(region)
	secondary_tab_container.spawn_BM_of_region(region)
	
	# Focus on both new tabs
	if primary_tab_container.get_child_count() > 0:
		var primary_last_tab = primary_tab_container.get_child_count() - 1
		primary_tab_container.current_tab = primary_last_tab
	
	if secondary_tab_container.get_child_count() > 0:
		var secondary_last_tab = secondary_tab_container.get_child_count() - 1
		secondary_tab_container.current_tab = secondary_last_tab
	
	BV.NOTIF.add_notification("Opened Circuit Builder and 3D Brain Monitor tabs for region '%s'" % region.friendly_name)

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

## Calculate default position for cloned region: same Y/Z as source, X = rightmost edge + 10 unit gap
func _calculate_clone_default_position(source_region: BrainRegion) -> Vector3i:
	var source_coords = source_region.coordinates_3D
	
	# Calculate the rightmost X coordinate of the source region
	var rightmost_x = _calculate_region_rightmost_x(source_region)
	
	print("🎯 CLONE POSITIONING DEBUG:")
	print("  Source region: %s at %s" % [source_region.friendly_name, source_coords])
	print("  Calculated rightmost X: %d" % rightmost_x)
	print("  New position will be: (%d, %d, %d)" % [rightmost_x + 10, source_coords.y, source_coords.z])
	
	# Default position: same Y and Z, X = rightmost + 10 unit gap
	return Vector3i(rightmost_x + 10, source_coords.y, source_coords.z)

## Calculate the rightmost X coordinate of a brain region (including all its plates)
func _calculate_region_rightmost_x(region: BrainRegion) -> int:
	var region_x = region.coordinates_3D.x
	
	# We need to calculate the total width of the region's plates
	# This mimics the logic from UI_BrainMonitor_BrainRegion3D.generate_io_coordinates_for_brain_region
	
	# Get I/O areas for this region (we need to access the partial mappings)
	var input_areas: Array[AbstractCorticalArea] = []
	var output_areas: Array[AbstractCorticalArea] = []
	var conflict_areas: Array[AbstractCorticalArea] = []
	
	# Get areas from the region's partial mappings
	print("  🔍 DEBUG: Region has %d partial mappings" % region.partial_mappings.size())
	for partial_mapping in region.partial_mappings:
		var target_area = partial_mapping.internal_target_cortical_area
		if target_area != null:
			if partial_mapping.is_region_input:
				# This is an input to the region (external -> internal)
				if target_area not in input_areas:
					input_areas.append(target_area)
					print("    📥 Added input area: %s (dims: %s)" % [target_area.cortical_ID, target_area.dimensions_3D])
			else:
				# This is an output from the region (internal -> external)
				if target_area not in output_areas:
					output_areas.append(target_area)
					print("    📤 Added output area: %s (dims: %s)" % [target_area.cortical_ID, target_area.dimensions_3D])
	
	# Check for conflicts (areas in both input and output)
	for area in input_areas:
		if area in output_areas:
			conflict_areas.append(area)
	
	# Remove conflict areas from input/output lists
	for area in conflict_areas:
		input_areas.erase(area)
		output_areas.erase(area)
	
	# Calculate plate sizes using the same constants as UI_BrainMonitor_BrainRegion3D
	const PLATE_SIDE_MARGIN = 1.0
	const AREA_BUFFER_DISTANCE = 1.0
	const PLATE_FRONT_BACK_MARGIN = 1.0
	const PLATE_GAP = 2.0
	const PLACEHOLDER_PLATE_SIZE = Vector3(5.0, 1.0, 5.0)
	
	print("  📊 Found %d inputs, %d outputs, %d conflicts" % [input_areas.size(), output_areas.size(), conflict_areas.size()])
	
	var input_plate_size = _calculate_plate_size_for_areas_helper(input_areas)
	var output_plate_size = _calculate_plate_size_for_areas_helper(output_areas)
	var conflict_plate_size = _calculate_plate_size_for_areas_helper(conflict_areas)
	
	print("  📐 Plate sizes - Input: %s, Output: %s, Conflict: %s" % [input_plate_size, output_plate_size, conflict_plate_size])
	
	# Calculate the rightmost edge by finding the end of the last plate
	# This matches the exact logic in UI_BrainMonitor_BrainRegion3D:
	
	var rightmost_edge: float
	
	if conflict_areas.size() > 0:
		# Conflict plate exists - it's the rightmost
		var conflict_plate_x = input_plate_size.x + PLATE_GAP + output_plate_size.x + PLATE_GAP
		rightmost_edge = conflict_plate_x + conflict_plate_size.x
		print("  🔴 Conflict plate at X=%f, rightmost edge: %f" % [conflict_plate_x, rightmost_edge])
	else:
		# No conflict plate - output plate is rightmost
		var output_plate_x = input_plate_size.x + PLATE_GAP
		rightmost_edge = output_plate_x + output_plate_size.x
		print("  🔵 Output plate at X=%f, rightmost edge: %f" % [output_plate_x, rightmost_edge])
	
	# Rightmost X = region's starting X + rightmost edge position
	var final_rightmost = int(region_x + rightmost_edge)
	print("  ➡️ Final calculation: %d + %f = %d" % [region_x, rightmost_edge, final_rightmost])
	return final_rightmost

## Helper function to calculate plate size for areas (mimics UI_BrainMonitor_BrainRegion3D logic)
func _calculate_plate_size_for_areas_helper(areas: Array[AbstractCorticalArea]) -> Vector3:
	const PLATE_SIDE_MARGIN = 1.0
	const AREA_BUFFER_DISTANCE = 1.0
	const PLATE_FRONT_BACK_MARGIN = 1.0
	const PLACEHOLDER_PLATE_SIZE = Vector3(5.0, 1.0, 5.0)
	
	# If no areas, use placeholder size
	if areas.size() == 0:
		return PLACEHOLDER_PLATE_SIZE
	
	# Calculate width: sum of all area widths + buffers + margins
	var total_width = 0.0
	var max_depth = 0.0
	
	for area in areas:
		total_width += area.dimensions_3D.x  # Sum all widths
		max_depth = max(max_depth, area.dimensions_3D.z)  # Find max depth
	
	# Width calculation: sum_of_widths + (count-1)*BUFFER + SIDE_MARGINS
	var plate_width = total_width + (areas.size() - 1) * AREA_BUFFER_DISTANCE + (PLATE_SIDE_MARGIN * 2.0)
	
	# Depth calculation: max_depth + FRONT_BACK_MARGINS  
	var plate_depth = max_depth + (PLATE_FRONT_BACK_MARGIN * 2.0)
	
	# Height is always 1.0 for plates
	return Vector3(plate_width, 1.0, plate_depth)
