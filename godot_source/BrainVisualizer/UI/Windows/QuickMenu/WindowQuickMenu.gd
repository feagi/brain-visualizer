extends BaseDraggableWindow
class_name QuickCorticalMenu

const WINDOW_NAME: StringName = "quick_menu"
const _ICON_TOOLTIP_TRIGGER_SCRIPT: Script = preload("res://BrainVisualizer/UI/GenericElements/CustomTooltip/CustomTooltipTrigger.gd")
## Native tooltips draw under FloatingWindowsLayer. This manager draws above it.
const _TOP_BAR_TOOLTIP_MANAGER_PATH: NodePath = ^"/root/BrainVisualizer/UIManager/TopBar/CustomTooltipManager"
const SPAWN_DISTANCE_PX: float = 50.0
var _mode: GenomeObject.ARRAY_MAKEUP
var _selection: Array[GenomeObject]
var _selection_context: SelectionSystem.SOURCE_CONTEXT = SelectionSystem.SOURCE_CONTEXT.UNKNOWN
var _btn_move_3d: TextureButton
var _btn_resize_3d: TextureButton
var _btn_relocate_2d: TextureButton
var _btn_arrange: ArrangeDropDown
var _arrange_in_progress: bool = false
var _close_requested_during_arrange: bool = false
var _close_requested_clear_selection: bool = true


func _ready() -> void:
	var grid := get_node_or_null("WindowPanel/WindowMargin/WindowInternals/ToolbarGrid")
	if grid != null and grid not in theme_scalar_nodes_to_not_include_or_search:
		theme_scalar_nodes_to_not_include_or_search.append(grid)
	super._ready()
	apply_condensed_chrome()
	_apply_toolbar_icon_size()
	if BV.UI != null and not BV.UI.theme_changed.is_connected(_apply_toolbar_icon_size):
		BV.UI.theme_changed.connect(_apply_toolbar_icon_size)


func setup(selection: Array[GenomeObject], context: SelectionSystem.SOURCE_CONTEXT = SelectionSystem.SOURCE_CONTEXT.UNKNOWN) -> void:
	print("🔍 QuickMenu: setup() called with %d objects" % selection.size())
	_mode = GenomeObject.get_makeup_of_array(selection)
	_selection = selection
	_selection_context = context
	print("🔍 QuickMenu: _selection assigned, size: %d, mode: %s" % [_selection.size(), _mode])
	
	var details_button: TextureButton = _window_internals.get_node('ToolbarGrid/Details')
	var open_3d_tab_button: TextureButton = _window_internals.get_node('ToolbarGrid/Open3DTab')
	var quick_connect_button: TextureButton = _window_internals.get_node('ToolbarGrid/QuickConnect')
	var quick_connect_CA_N_button: TextureButton = _window_internals.get_node("ToolbarGrid/QuickConnect_CA_N")
	var quick_connect_N_CA_button: TextureButton = _window_internals.get_node("ToolbarGrid/QuickConnect_N_CA")
	var quick_connect_N_N_button: TextureButton = _window_internals.get_node("ToolbarGrid/QuickConnect_N_N")
	var move_to_region_button: TextureButton = _window_internals.get_node('ToolbarGrid/AddToRegion')
	var clone_button: TextureButton = _window_internals.get_node('ToolbarGrid/Clone')
	_btn_relocate_2d = _window_internals.get_node_or_null("ToolbarGrid/Relocate2D") as TextureButton
	_btn_move_3d = _window_internals.get_node_or_null("ToolbarGrid/Move3D") as TextureButton
	_btn_resize_3d = _window_internals.get_node_or_null("ToolbarGrid/Resize3D") as TextureButton
	_btn_arrange = _window_internals.get_node_or_null("ToolbarGrid/Arrange") as ArrangeDropDown
	if _btn_arrange != null:
		_btn_arrange.visible = false
		if not _btn_arrange.arrange_requested.is_connected(_button_arrange):
			_btn_arrange.arrange_requested.connect(_button_arrange)
	var iopu_config_button: TextureButton = _window_internals.get_node('ToolbarGrid/SetupIOPU')
	var reset_button: TextureButton = _window_internals.get_node('ToolbarGrid/Reset')
	var delete_button: TextureButton = _window_internals.get_node('ToolbarGrid/Delete')
	
	quick_connect_CA_N_button.pressed.connect(_button_quick_connect_neuron.bind(WindowQuickConnectNeuron.MODE.CORTICAL_AREA_TO_NEURONS))
	quick_connect_N_CA_button.pressed.connect(_button_quick_connect_neuron.bind(WindowQuickConnectNeuron.MODE.NEURONS_TO_CORTICAL_AREA))
	quick_connect_N_N_button.pressed.connect(_button_quick_connect_neuron.bind(WindowQuickConnectNeuron.MODE.NEURON_TO_NEURONS))
	
	_setup_base_window(WINDOW_NAME)
	if selection.size() == 0:
		push_error("BV UI: The quick menu was opened with 0 selected objects. This should never happen! Please note the steps to cause this error and open an issue! Closing the window...")
		close_window()
		return
	focus_exited.connect(_on_focus_lost)
	
	match(_mode):
		GenomeObject.ARRAY_MAKEUP.SINGLE_CORTICAL_AREA:
			reset_button.visible = true
			var is_circuit_builder_context := _selection_context in [
				SelectionSystem.SOURCE_CONTEXT.FROM_CIRCUIT_BUILDER_CLICK,
				SelectionSystem.SOURCE_CONTEXT.FROM_CIRCUIT_BUILDER_DRAG
			]
			var is_on_plate_of_other_region := _selection_context == SelectionSystem.SOURCE_CONTEXT.FROM_3D_SCENE_ON_PLATE
			if _btn_relocate_2d != null:
				_btn_relocate_2d.visible = is_circuit_builder_context
				_btn_relocate_2d.disabled = not is_circuit_builder_context
				_btn_relocate_2d.tooltip_text = "Relocate this cortical area (2D)" if is_circuit_builder_context else _btn_relocate_2d.tooltip_text
			open_3d_tab_button.visible = false  # Hide 3D tab button for cortical areas
			details_button.tooltip_text = "View Cortical Area Properties"
			quick_connect_button.tooltip_text = "Quick Connet: Map two areas together."
			move_to_region_button.tooltip_text = "Add to a circuit..."
			clone_button.tooltip_text = "Clone Cortical Area..."
			reset_button.tooltip_text = "Reset this Cortical Area..."
			delete_button.tooltip_text = "Delete this Cortical Area..."
			
			# 🚨 SAFETY CHECK: This should never happen due to earlier check, but be defensive
			if _selection.size() == 0:
				push_error("BV UI: CRITICAL - _selection became empty during setup after passing initial check!")
				return
			var area: AbstractCorticalArea = (_selection[0] as AbstractCorticalArea)
			_titlebar.title = area.friendly_name
			var is_ipu_opu := area is IPUCorticalArea or area is OPUCorticalArea
			iopu_config_button.visible = true
			iopu_config_button.disabled = not is_ipu_opu
			iopu_config_button.tooltip_text = "Open IPU/OPU configuration" if is_ipu_opu else "IPU/OPU configuration only."
			if _btn_move_3d != null:
				_btn_move_3d.visible = not is_circuit_builder_context
				if _btn_move_3d.visible:
					_btn_move_3d.disabled = is_on_plate_of_other_region
					_btn_move_3d.tooltip_text = "Relocate from within the area's circuit" if is_on_plate_of_other_region else "Relocate this cortical area (3D gizmo)"
			if _btn_resize_3d != null:
				_btn_resize_3d.visible = true
				_btn_resize_3d.disabled = is_circuit_builder_context or is_on_plate_of_other_region or not area.user_can_edit_dimensions_directly
				_btn_resize_3d.tooltip_text = "Resize from within the area's circuit" if is_on_plate_of_other_region else ("Resize this cortical area (3D gizmo)" if area.user_can_edit_dimensions_directly else "This cortical area cannot be resized")
			if is_circuit_builder_context:
				quick_connect_CA_N_button.disabled = true
				quick_connect_N_CA_button.disabled = true
				quick_connect_N_N_button.disabled = true
				quick_connect_CA_N_button.tooltip_text = "Voxel-level quick connect is only available in 3D view."
				quick_connect_N_CA_button.tooltip_text = "Voxel-level quick connect is only available in 3D view."
				quick_connect_N_N_button.tooltip_text = "Voxel-level quick connect is only available in 3D view."

			if !area.user_can_delete_this_area:
				delete_button.disabled = true
				var del_reason: String = area.user_delete_blocked_reason()
				delete_button.tooltip_text = del_reason if not del_reason.is_empty() else "This cortical area cannot be deleted."
			if !area.user_can_clone_this_cortical_area:
				clone_button.disabled = true
				clone_button.tooltip_text = "This Cortical Area Cannot Be Cloned"
			if !area.can_exist_in_subregion:
				move_to_region_button.disabled = true
				move_to_region_button.tooltip_text = "System Cortical Areas cannot be moved into a Circuit"
			if area is MemoryCorticalArea:
				quick_connect_CA_N_button.visible = true
				quick_connect_N_CA_button.visible = true
				quick_connect_N_N_button.visible = true
				quick_connect_CA_N_button.disabled = true
				quick_connect_N_CA_button.disabled = true
				quick_connect_N_N_button.disabled = true
				quick_connect_CA_N_button.tooltip_text = "Neuron block based operations are unavailable for memory cortical areas."
				quick_connect_N_CA_button.tooltip_text = "Neuron block based operations are unavailable for memory cortical areas."
				quick_connect_N_N_button.tooltip_text = "Neuron block based operations are unavailable for memory cortical areas."
				
			
		GenomeObject.ARRAY_MAKEUP.SINGLE_BRAIN_REGION:
			reset_button.visible = false
			iopu_config_button.visible = false
			var is_circuit_builder_region := _selection_context in [
				SelectionSystem.SOURCE_CONTEXT.FROM_CIRCUIT_BUILDER_CLICK,
				SelectionSystem.SOURCE_CONTEXT.FROM_CIRCUIT_BUILDER_DRAG
			]
			if _btn_relocate_2d != null:
				_btn_relocate_2d.visible = false
			if _btn_move_3d != null:
				_btn_move_3d.visible = not is_circuit_builder_region
				if _btn_move_3d.visible:
					_btn_move_3d.disabled = false
					_btn_move_3d.tooltip_text = "Relocate this circuit (3D gizmo)"
			if _btn_resize_3d != null:
				_btn_resize_3d.visible = false
			quick_connect_button.visible = false
			clone_button.visible = true
			quick_connect_CA_N_button.visible = false
			quick_connect_N_CA_button.visible = false
			quick_connect_N_N_button.visible = false
			details_button.tooltip_text = "View Circuit Details"
			open_3d_tab_button.tooltip_text = "Open Circuit in 3D Tab"
			move_to_region_button.tooltip_text = "Add to a circuit..."
			clone_button.tooltip_text = "Clone this circuit..."
			delete_button.tooltip_text = "Delete this Circuit..."
			
			# 🚨 SAFETY CHECK: This should never happen due to earlier check, but be defensive
			if _selection.size() == 0:
				push_error("BV UI: CRITICAL - _selection became empty during setup after passing initial check!")
				return
			var region: BrainRegion = (_selection[0] as BrainRegion)
			_titlebar.title = region.friendly_name

		GenomeObject.ARRAY_MAKEUP.SINGLE_CLASSIFIER:
			reset_button.visible = false
			iopu_config_button.visible = false
			open_3d_tab_button.visible = false
			quick_connect_button.visible = false
			clone_button.visible = false
			quick_connect_CA_N_button.visible = false
			quick_connect_N_CA_button.visible = false
			quick_connect_N_N_button.visible = false
			# Not a circuit: FEAGI has no classifier reparent API, so do not show a dead control.
			move_to_region_button.visible = false
			details_button.visible = true
			details_button.disabled = false
			details_button.tooltip_text = "Classifier properties"
			delete_button.visible = true
			delete_button.disabled = false
			delete_button.tooltip_text = "Delete this classifier..."
			var is_circuit_builder_classifier := _selection_context in [
				SelectionSystem.SOURCE_CONTEXT.FROM_CIRCUIT_BUILDER_CLICK,
				SelectionSystem.SOURCE_CONTEXT.FROM_CIRCUIT_BUILDER_DRAG
			]
			if _btn_relocate_2d != null:
				_btn_relocate_2d.visible = is_circuit_builder_classifier
				_btn_relocate_2d.disabled = not is_circuit_builder_classifier
				_btn_relocate_2d.tooltip_text = "Relocate this classifier (2D)"
			if _btn_move_3d != null:
				_btn_move_3d.visible = not is_circuit_builder_classifier
				if _btn_move_3d.visible:
					_btn_move_3d.disabled = false
					_btn_move_3d.tooltip_text = "Relocate this classifier (3D gizmo)"
			if _btn_resize_3d != null:
				_btn_resize_3d.visible = false
			if _selection.size() == 0:
				push_error("BV UI: CRITICAL - _selection became empty during classifier quick menu setup!")
				return
			var classifier: GenomeClassifier = (_selection[0] as GenomeClassifier)
			_titlebar.title = classifier.friendly_name

		GenomeObject.ARRAY_MAKEUP.MULTIPLE_CORTICAL_AREAS:
			reset_button.visible = true
			reset_button.disabled = false
			reset_button.tooltip_text = "Reset selected cortical areas..."
			iopu_config_button.visible = true
			var is_circuit_builder_context := _selection_context in [
				SelectionSystem.SOURCE_CONTEXT.FROM_CIRCUIT_BUILDER_CLICK,
				SelectionSystem.SOURCE_CONTEXT.FROM_CIRCUIT_BUILDER_DRAG
			]
			var areas: Array[AbstractCorticalArea] = AbstractCorticalArea.genome_array_to_cortical_area_array(selection)
			var all_ipu_opu := true
			for area in areas:
				if not (area is IPUCorticalArea or area is OPUCorticalArea):
					all_ipu_opu = false
					break
			iopu_config_button.disabled = not all_ipu_opu
			iopu_config_button.tooltip_text = "Open IPU/OPU configuration" if all_ipu_opu else "IPU/OPU configuration only."
			if _btn_relocate_2d != null:
				_btn_relocate_2d.visible = true
				_btn_relocate_2d.disabled = false
				_btn_relocate_2d.tooltip_text = "Relocate selected areas (2D)" if is_circuit_builder_context else "Relocate selected areas (3D gizmo)"
			if _btn_move_3d != null:
				_btn_move_3d.visible = false
			if _btn_resize_3d != null:
				_btn_resize_3d.visible = false
			open_3d_tab_button.visible = false  # Hide 3D tab button for multiple cortical areas
			quick_connect_button.visible = false
			clone_button.visible = false
			quick_connect_CA_N_button.visible = false
			quick_connect_N_CA_button.visible = false
			quick_connect_N_N_button.visible = false
			details_button.tooltip_text = "View Details of these Cortical Areas"
			move_to_region_button.tooltip_text = "Add to a circuit..."
			_titlebar.title = "Selected multiple areas"
			
			if !AbstractCorticalArea.can_all_areas_exist_in_subregion(areas):
				move_to_region_button.disabled = true
				move_to_region_button.tooltip_text = "One of the selected areas is of Input, Output, or Core type which is not allowed inside a neural circuit."
			if !AbstractCorticalArea.can_all_areas_be_deleted(areas):
				delete_button.disabled = true
				var multi_reason: String = ""
				for a in areas:
					if not a.user_can_delete_this_area:
						multi_reason = a.user_delete_blocked_reason()
						if not multi_reason.is_empty():
							break
				delete_button.tooltip_text = multi_reason if not multi_reason.is_empty() else "One or more of the selected areas cannot be deleted."
			_sync_arrange_button(areas)
			_refresh_multi_cortical_controls()
				
			
		GenomeObject.ARRAY_MAKEUP.MULTIPLE_BRAIN_REGIONS:
			reset_button.visible = false
			iopu_config_button.visible = false
			if _btn_relocate_2d != null:
				_btn_relocate_2d.visible = true
				_btn_relocate_2d.disabled = false
				_btn_relocate_2d.tooltip_text = "Relocate selected circuits (2D)"
			if _btn_move_3d != null:
				_btn_move_3d.visible = false
			if _btn_resize_3d != null:
				_btn_resize_3d.visible = false
			open_3d_tab_button.visible = false  # Hide 3D tab button for multiple brain regions
			quick_connect_button.visible = false
			clone_button.visible = false
			details_button.visible = false
			delete_button.visible = true
			quick_connect_CA_N_button.visible = false
			quick_connect_N_CA_button.visible = false
			quick_connect_N_N_button.visible = false
			move_to_region_button.tooltip_text = "Add to a circuit..."
			delete_button.tooltip_text = "Delete selected circuits..."
			_titlebar.title = "Selected multiple circuits"

		GenomeObject.ARRAY_MAKEUP.VARIOUS_GENOME_OBJECTS:
			reset_button.visible = false
			iopu_config_button.visible = false
			if _btn_relocate_2d != null:
				_btn_relocate_2d.visible = true
				_btn_relocate_2d.disabled = false
				_btn_relocate_2d.tooltip_text = "Relocate selected objects (2D)"
			if _btn_move_3d != null:
				_btn_move_3d.visible = false
			if _btn_resize_3d != null:
				_btn_resize_3d.visible = false
			open_3d_tab_button.visible = false  # Hide 3D tab button for mixed objects
			quick_connect_button.visible = false
			clone_button.visible = false
			details_button.visible = false
			quick_connect_CA_N_button.visible = false
			quick_connect_N_CA_button.visible = false
			quick_connect_N_N_button.visible = false
			move_to_region_button.tooltip_text = "Add to a circuit..."
			delete_button.tooltip_text = "Delete selected objects..."
			_titlebar.title = "Selected multiple objects"
			
			var filtered_areas: Array[AbstractCorticalArea] = AbstractCorticalArea.genome_array_to_cortical_area_array(selection)
			if !AbstractCorticalArea.can_all_areas_exist_in_subregion(filtered_areas):
				move_to_region_button.disabled = true
				move_to_region_button.tooltip_text = "One or more of the selected objects cannot be moved to a circuit"
			if !AbstractCorticalArea.can_all_areas_be_deleted(filtered_areas):
				delete_button.disabled = true
				var mix_reason: String = ""
				for a in filtered_areas:
					if not a.user_can_delete_this_area:
						mix_reason = a.user_delete_blocked_reason()
						if not mix_reason.is_empty():
							break
				delete_button.tooltip_text = mix_reason if not mix_reason.is_empty() else "One or more of the selected objects cannot be deleted."
			
	# Position after mode-specific visibility/layout changes so vertical distance is consistent.
	_fit_toolbar()
	_apply_icon_tooltips()
	call_deferred("_reposition_near_mouse_after_layout")




	#NOTE: Removed left bar spawn reference from here. Handle that in WindowManager directly instead please!




func _button_details() -> void:
	_debug_selection_state("_button_details start")
	# 🚨 SAFETY CHECK: Ensure selection array is not empty
	if _selection.size() == 0:
		push_error("BV UI: QuickMenu _button_details called with empty _selection array! This indicates a selection state bug.")
		BV.NOTIF.add_notification("No objects selected for details view!")
		close_window()
		return
	
	match(_mode):
		GenomeObject.ARRAY_MAKEUP.SINGLE_CORTICAL_AREA:
			BV.WM.spawn_adv_cortical_properties(AbstractCorticalArea.genome_array_to_cortical_area_array(_selection))
		GenomeObject.ARRAY_MAKEUP.SINGLE_BRAIN_REGION:
			BV.WM.spawn_edit_region((_selection[0] as BrainRegion))
		GenomeObject.ARRAY_MAKEUP.SINGLE_CLASSIFIER:
			BV.WM.spawn_edit_classifier(_selection[0] as GenomeClassifier)
		GenomeObject.ARRAY_MAKEUP.MULTIPLE_CORTICAL_AREAS:
			BV.WM.spawn_adv_cortical_properties(AbstractCorticalArea.genome_array_to_cortical_area_array(_selection))
	_debug_selection_state("_button_details before close")
	close_window()

func _button_quick_connect() -> void:
	if _selection.size() == 0:
		BV.NOTIF.add_notification("Please select something!")
	else:
		BV.WM.spawn_quick_connect((_selection[0] as AbstractCorticalArea))
	close_window()

func _button_quick_connect_neuron(mode: WindowQuickConnectNeuron.MODE) -> void:
	if _selection.size() == 0:
		BV.WM.spawn_quick_connect_neuron(mode)
	else:
		BV.WM.spawn_quick_connect_neuron(mode, _selection[0] as AbstractCorticalArea)
	close_window()

func _button_clone() -> void:
	if _selection.size() == 0:
		BV.NOTIF.add_notification("Please select something!")
	else:
		match(_mode):
			GenomeObject.ARRAY_MAKEUP.SINGLE_CORTICAL_AREA:
				BV.WM.spawn_clone_cortical((_selection[0] as AbstractCorticalArea))
			GenomeObject.ARRAY_MAKEUP.SINGLE_BRAIN_REGION:
				BV.WM.spawn_clone_region((_selection[0] as BrainRegion))
	close_window()

func _button_add_to_region() -> void:
	if _selection.size() == 0:
		BV.NOTIF.add_notification("Please select something!")
	else:
		var parent_region: BrainRegion = _selection[0].current_parent_region # Whatever we selected, the parent region is the parent region of any element that selection
		BV.WM.spawn_move_to_region(_selection, parent_region)
	close_window()

func _button_delete() -> void:
	if not await BV.WM.spawn_confirm_deletion(_selection):
		return
	close_window()

## Opens a placeholder IPU/OPU configuration popup.
func _button_ipu_opu_config() -> void:
	if _selection.size() == 0:
		BV.NOTIF.add_notification("No cortical area selected for IPU/OPU configuration.")
		close_window()
		return
	var areas: Array[AbstractCorticalArea] = AbstractCorticalArea.genome_array_to_cortical_area_array(_selection)
	var all_ipu_opu := true
	for area in areas:
		if not (area is IPUCorticalArea or area is OPUCorticalArea):
			all_ipu_opu = false
			break
	if not all_ipu_opu:
		BV.NOTIF.add_notification("IPU/OPU configuration only.")
		close_window()
		return
	var focus_area: AbstractCorticalArea = _selection[0] as AbstractCorticalArea
	var focus_key: StringName = focus_area.controller_ID if focus_area != null else &""
	var focus_section: StringName = WindowIPUOPUConfig.SECTION_OUTPUT if focus_area is OPUCorticalArea else WindowIPUOPUConfig.SECTION_INPUT
	BV.WM.spawn_ipu_opu_config(focus_key, focus_section)
	close_window()

## Resets selected cortical areas' runtime neural state (via FEAGI PUT /v1/cortical_area/reset).
func _button_reset() -> void:
	if FeagiCore == null or FeagiCore.requests == null:
		BV.NOTIF.add_notification("Reset unavailable: FEAGI is not ready")
		close_window()
		return
	var areas: Array[AbstractCorticalArea] = AbstractCorticalArea.genome_array_to_cortical_area_array(_selection)
	if areas.is_empty():
		BV.NOTIF.add_notification("No cortical areas selected to reset")
		close_window()
		return
	BV.NOTIF.add_notification("Resetting cortical areas...")
	var result = await FeagiCore.requests.mass_reset_cortical_areas(areas)
	if result.has_errored:
		BV.NOTIF.add_notification("Cortical reset failed")
	else:
		BV.NOTIF.add_notification("Cortical areas reset")
	close_window()

func _button_open_3d_tab() -> void:
	_debug_selection_state("_button_open_3d_tab start")
	# 🚨 SAFETY CHECK: Ensure selection array is not empty and contains a brain region
	if _selection.size() == 0:
		push_error("BV UI: QuickMenu _button_open_3d_tab called with empty _selection array!")
		BV.NOTIF.add_notification("No neural circuit selected for 3D tab!")
		close_window()
		return
		
	if _mode != GenomeObject.ARRAY_MAKEUP.SINGLE_BRAIN_REGION:
		push_error("BV UI: QuickMenu _button_open_3d_tab called but selection is not a single brain region!")
		BV.NOTIF.add_notification("3D tabs can only be created for single neural circuits!")
		close_window()
		return
	
	var region: BrainRegion = _selection[0] as BrainRegion
	if region == null:
		push_error("BV UI: QuickMenu _button_open_3d_tab: Selected object is not a brain region!")
		close_window()
		return
	
	print("🧠 QuickMenu: Opening 3D tab for brain region: %s" % region.friendly_name)
	print("  🔍 SELECTION ANALYSIS:")
	print("    - Region ID: %s" % region.region_ID)
	print("    - Is root region: %s" % region.is_root_region())
	print("    - Parent: %s" % (region.current_parent_region.friendly_name if region.current_parent_region else "None"))
	print("    - Contains %d cortical areas" % region.contained_cortical_areas.size())
	print("    - Contains %d child regions" % region.contained_regions.size())
	
	# List cortical areas in selected region
	print("  📋 CORTICAL AREAS IN SELECTED REGION:")
	for i in region.contained_cortical_areas.size():
		var area = region.contained_cortical_areas[i]
		print("    %d. %s (parent: %s)" % [i+1, area.cortical_ID, area.current_parent_region.friendly_name if area.current_parent_region else "None"])
	
	BV.WM.spawn_3d_brain_monitor_tab(region, true)
	_debug_selection_state("_button_open_3d_tab before close")
	close_window()

func _button_move_3d() -> void:
	if _selection.size() == 0:
		BV.NOTIF.add_notification("Please select something!")
		close_window()
		return
	if _mode == GenomeObject.ARRAY_MAKEUP.SINGLE_BRAIN_REGION:
		var region: BrainRegion = _selection[0] as BrainRegion
		if region == null or region.current_parent_region == null:
			BV.NOTIF.add_notification("Cannot relocate root circuit.")
			close_window()
			return
		var bm: UI_BrainMonitor_3DScene = BV.UI.get_brain_monitor_for_region(region.current_parent_region)
		if bm == null:
			BV.WM.spawn_popup(ConfigurablePopupDefinition.create_single_button_close_popup(
				"Move (3D) Unavailable",
				"No active 3D Brain Monitor found for this circuit's parent.\n\nOpen a 3D tab for the parent circuit, then try again."
			))
			close_window()
			return
		bm.start_brain_region_manipulation(region)
		close_window(false)
		return
	if _mode == GenomeObject.ARRAY_MAKEUP.MULTIPLE_CORTICAL_AREAS:
		var areas: Array[AbstractCorticalArea] = AbstractCorticalArea.genome_array_to_cortical_area_array(_selection)
		if areas.is_empty():
			close_window()
			return
		var anchor: AbstractCorticalArea = areas[0]
		if anchor == null or anchor.current_parent_region == null:
			BV.WM.spawn_popup(ConfigurablePopupDefinition.create_single_button_close_popup(
				"Move (3D) Unavailable",
				"Cannot start 3D relocation: no parent circuit available for selected cortical areas."
			))
			close_window()
			return
		var bm_multi: UI_BrainMonitor_3DScene = BV.UI.get_brain_monitor_for_region(anchor.current_parent_region)
		if bm_multi == null:
			BV.WM.spawn_popup(ConfigurablePopupDefinition.create_single_button_close_popup(
				"Move (3D) Unavailable",
				"No active 3D Brain Monitor found for selected areas' parent circuit.\n\nOpen a 3D tab for that circuit, then try again."
			))
			close_window()
			return
		bm_multi.start_cortical_area_multi_manipulation(areas, UI_BrainMonitor_3DScene.MANIPULATION_MODE.MOVE)
		close_window(false)
		return
	if _mode == GenomeObject.ARRAY_MAKEUP.SINGLE_CLASSIFIER:
		var classifier: GenomeClassifier = _selection[0] as GenomeClassifier
		if classifier == null:
			close_window()
			return
		var stamp: AbstractCorticalArea = classifier.get_stamp_area()
		if stamp == null or stamp.current_parent_region == null:
			BV.WM.spawn_popup(ConfigurablePopupDefinition.create_single_button_close_popup(
				"Move (3D) Unavailable",
				"Cannot start 3D relocation: classifier stamp is not in a parent circuit."
			))
			close_window()
			return
		var bm_classifier: UI_BrainMonitor_3DScene = BV.UI.get_brain_monitor_for_region(stamp.current_parent_region)
		if bm_classifier == null:
			BV.WM.spawn_popup(ConfigurablePopupDefinition.create_single_button_close_popup(
				"Move (3D) Unavailable",
				"No active 3D Brain Monitor found for this classifier.\n\nOpen a 3D tab for the parent circuit, then try again."
			))
			close_window()
			return
		bm_classifier.start_cortical_area_manipulation(stamp, UI_BrainMonitor_3DScene.MANIPULATION_MODE.MOVE)
		close_window(false)
		return
	if _mode != GenomeObject.ARRAY_MAKEUP.SINGLE_CORTICAL_AREA:
		close_window()
		return
	var area: AbstractCorticalArea = _selection[0] as AbstractCorticalArea
	if area == null or area.current_parent_region == null:
		BV.WM.spawn_popup(ConfigurablePopupDefinition.create_single_button_close_popup(
			"Move (3D) Unavailable",
			"Cannot start 3D relocation: no parent circuit available for this cortical area."
		))
		close_window()
		return
	var bm: UI_BrainMonitor_3DScene = BV.UI.get_brain_monitor_for_region(area.current_parent_region)
	if bm == null:
		BV.WM.spawn_popup(ConfigurablePopupDefinition.create_single_button_close_popup(
			"Move (3D) Unavailable",
			"No active 3D Brain Monitor found for this area's parent circuit.\n\nOpen a 3D tab for that circuit, then try again."
		))
		close_window()
		return
	if AbstractCorticalArea.is_reserved_system_core_area(area.cortical_ID):
		bm.start_core_cluster_cortical_manipulation(area)
	else:
		bm.start_cortical_area_manipulation(area, UI_BrainMonitor_3DScene.MANIPULATION_MODE.MOVE)
	close_window(false)

func _button_resize_3d() -> void:
	if _selection.size() == 0:
		BV.NOTIF.add_notification("Please select something!")
		close_window()
		return
	if _mode != GenomeObject.ARRAY_MAKEUP.SINGLE_CORTICAL_AREA:
		close_window()
		return
	var area: AbstractCorticalArea = _selection[0] as AbstractCorticalArea
	if area == null:
		close_window()
		return
	if not area.user_can_edit_dimensions_directly:
		BV.WM.spawn_popup(ConfigurablePopupDefinition.create_single_button_close_popup(
			"Resize (3D) Unavailable",
			"This cortical area cannot be resized."
		))
		close_window()
		return
	if area.current_parent_region == null:
		BV.WM.spawn_popup(ConfigurablePopupDefinition.create_single_button_close_popup(
			"Resize (3D) Unavailable",
			"Cannot start 3D resizing: no parent circuit available for this cortical area."
		))
		close_window()
		return
	var bm: UI_BrainMonitor_3DScene = BV.UI.get_brain_monitor_for_region(area.current_parent_region)
	if bm == null:
		BV.WM.spawn_popup(ConfigurablePopupDefinition.create_single_button_close_popup(
			"Resize (3D) Unavailable",
			"No active 3D Brain Monitor found for this area's parent circuit.\n\nOpen a 3D tab for that circuit, then try again."
		))
		close_window()
		return
	bm.start_cortical_area_manipulation(area, UI_BrainMonitor_3DScene.MANIPULATION_MODE.RESIZE)
	close_window(false)

func _button_relocate_2d() -> void:
	if _selection.size() == 0:
		BV.NOTIF.add_notification("Please select something!")
		close_window()
		return
	if _mode not in [
		GenomeObject.ARRAY_MAKEUP.SINGLE_CORTICAL_AREA,
		GenomeObject.ARRAY_MAKEUP.SINGLE_CLASSIFIER,
		GenomeObject.ARRAY_MAKEUP.MULTIPLE_CORTICAL_AREAS,
		GenomeObject.ARRAY_MAKEUP.MULTIPLE_BRAIN_REGIONS,
		GenomeObject.ARRAY_MAKEUP.VARIOUS_GENOME_OBJECTS
	]:
		close_window()
		return
	if _mode == GenomeObject.ARRAY_MAKEUP.MULTIPLE_CORTICAL_AREAS and _selection_context in [
		SelectionSystem.SOURCE_CONTEXT.FROM_3D_SCENE,
		SelectionSystem.SOURCE_CONTEXT.FROM_3D_SCENE_ON_PLATE
	]:
		var areas: Array[AbstractCorticalArea] = AbstractCorticalArea.genome_array_to_cortical_area_array(_selection)
		if areas.is_empty():
			close_window()
			return
		var parent_region: BrainRegion = areas[0].current_parent_region
		if parent_region == null:
			BV.NOTIF.add_notification("Cannot relocate: selected areas are missing parent circuit.")
			close_window()
			return
		for area in areas:
			if area == null or area.current_parent_region != parent_region:
				BV.NOTIF.add_notification("3D multi-relocate requires all selected areas to be in the same circuit.")
				close_window()
				return
		var bm: UI_BrainMonitor_3DScene = BV.UI.get_brain_monitor_for_region(parent_region)
		if bm == null:
			BV.NOTIF.add_notification("No active Brain Monitor tab found for selected areas.")
			close_window()
			return
		bm.start_cortical_area_multi_manipulation(areas, UI_BrainMonitor_3DScene.MANIPULATION_MODE.MOVE)
		close_window(false)
		return
	var cb := _get_active_cb_from_ui()
	if cb == null:
		BV.NOTIF.add_notification("No active Circuit Builder tab found.")
		close_window()
		return
	cb.start_multi_relocate(_selection)
	close_window(false)

func _get_active_cb_from_ui() -> CircuitBuilder:
	return _search_for_active_cb_in_view(BV.UI.root_UI_view)

func _search_for_active_cb_in_view(ui_view: UIView) -> CircuitBuilder:
	if ui_view == null:
		return null
	if ui_view.mode == UIView.MODE.TAB:
		var tab_container = ui_view._get_primary_child() as UITabContainer
		if tab_container != null and tab_container.get_tab_count() > 0:
			var active_control = tab_container.get_tab_control(tab_container.current_tab)
			if active_control is CircuitBuilder:
				return active_control as CircuitBuilder
	elif ui_view.mode == UIView.MODE.SPLIT:
		var primary_child = ui_view._get_primary_child()
		if primary_child is UIView:
			var result = _search_for_active_cb_in_view(primary_child as UIView)
			if result != null:
				return result
		elif primary_child is UITabContainer:
			var tab_container = primary_child as UITabContainer
			if tab_container.get_tab_count() > 0:
				var active_control = tab_container.get_tab_control(tab_container.current_tab)
				if active_control is CircuitBuilder:
					return active_control as CircuitBuilder
		var secondary_child = ui_view._get_secondary_child()
		if secondary_child is UIView:
			var result2 = _search_for_active_cb_in_view(secondary_child as UIView)
			if result2 != null:
				return result2
		elif secondary_child is UITabContainer:
			var tab_container2 = secondary_child as UITabContainer
			if tab_container2.get_tab_count() > 0:
				var active_control2 = tab_container2.get_tab_control(tab_container2.current_tab)
				if active_control2 is CircuitBuilder:
					return active_control2 as CircuitBuilder
	return null

## Shows Arrange only for a multi-area selection in one circuit, with no reserved core areas.
func _sync_arrange_button(areas: Array[AbstractCorticalArea]) -> void:
	if _btn_arrange == null:
		return
	var block_reason := _arrange_block_reason(areas)
	_btn_arrange.visible = true
	_btn_arrange.disabled = not block_reason.is_empty()
	_btn_arrange.tooltip_text = block_reason if not block_reason.is_empty() else "Arrange"
	_btn_arrange.set_action_availability(
		areas.size() >= SelectionArrange.ALIGN_MINIMUM_COUNT,
		areas.size() >= SelectionArrange.DISTRIBUTE_MINIMUM_COUNT and block_reason.is_empty()
	)


func _arrange_block_reason(areas: Array[AbstractCorticalArea]) -> String:
	if areas.size() < SelectionArrange.ALIGN_MINIMUM_COUNT:
		return "Select at least 2 areas to arrange them."
	var parent_region: BrainRegion = areas[0].current_parent_region
	if parent_region == null:
		return "Arrange requires every selected area to belong to a circuit."
	for area in areas:
		if area == null:
			return "Arrange requires every selected area to belong to a circuit."
		if AbstractCorticalArea.is_reserved_system_core_area(area.cortical_ID):
			return "Reserved core areas cannot be arranged."
		if area.current_parent_region != parent_region:
			return "Arrange requires all selected areas to be in the same circuit."
	return ""


func _record_position_edit(edit: PositionEdit) -> void:
	if BV == null or BV.UI == null:
		return
	BV.UI.record_position_edit(edit)


## Align or distribute the current multi-area selection on one axis, then save the genome once.
func _button_arrange(action: StringName, axis: int) -> void:
	if _btn_arrange != null:
		_btn_arrange.close_menu()
	if _arrange_in_progress:
		return
	var areas: Array[AbstractCorticalArea] = AbstractCorticalArea.genome_array_to_cortical_area_array(_selection)
	var block_reason := _arrange_block_reason(areas)
	if not block_reason.is_empty():
		BV.NOTIF.add_notification(block_reason)
		return
	if action == SelectionArrange.ACTION_DISTRIBUTE and areas.size() < SelectionArrange.DISTRIBUTE_MINIMUM_COUNT:
		BV.NOTIF.add_notification("Select at least 3 areas to distribute them.")
		return
	if not SelectionArrange.is_axis(axis):
		return
	var current: Array[Vector3i] = []
	for area in areas:
		current.append(area.coordinates_3D)
	var planned: Array[Vector3i] = SelectionArrange.plan_positions(action, current, axis)
	var axis_label := SelectionArrange.axis_label(axis)
	var pending_areas: Array[AbstractCorticalArea] = []
	var pending_positions: Array[Vector3i] = []
	var pending_befores: Array[Vector3i] = []
	for index in areas.size():
		if current[index] == planned[index]:
			continue
		pending_areas.append(areas[index])
		pending_positions.append(planned[index])
		pending_befores.append(current[index])
	if pending_areas.is_empty():
		var already := "aligned" if action == SelectionArrange.ACTION_ALIGN else "distributed"
		BV.NOTIF.add_notification("Selected areas are already %s on %s." % [already, axis_label])
		return
	if FeagiCore == null or FeagiCore.requests == null:
		BV.NOTIF.add_notification("Arrange unavailable: FEAGI is not ready.")
		return
	_arrange_in_progress = true
	var failed: Array[String] = []
	var moved_ids: Array[StringName] = []
	var moved_befores: Array[Vector3i] = []
	var moved_afters: Array[Vector3i] = []
	for index in pending_areas.size():
		var payload := {"coordinates_3d": FEAGIUtils.vector3i_to_array(pending_positions[index])}
		var result: FeagiRequestOutput = await FeagiCore.requests.update_cortical_area(pending_areas[index].cortical_ID, payload)
		if not is_instance_valid(self):
			return
		if result.has_errored:
			failed.append(String(pending_areas[index].cortical_ID))
			continue
		moved_ids.append(pending_areas[index].cortical_ID)
		moved_befores.append(pending_befores[index])
		moved_afters.append(pending_positions[index])
		if is_instance_valid(pending_areas[index]):
			pending_areas[index].FEAGI_change_coordinates_3D(pending_positions[index])
	_record_position_edit(PositionEdit.cortical_3d_moves("Arrange", moved_ids, moved_befores, moved_afters))
	if not failed.is_empty():
		_finish_arrange_request()
		BV.WM.spawn_popup(ConfigurablePopupDefinition.create_single_button_close_popup(
			"Arrange failed",
			"FEAGI rejected %d of %d position updates.\n\n%s" % [failed.size(), pending_areas.size(), ", ".join(failed)]
		))
		return
	var save_result: FeagiRequestOutput = await FeagiCore.requests.save_genome()
	if not is_instance_valid(self):
		return
	_finish_arrange_request()
	if save_result.has_errored:
		var save_details = save_result.decode_response_as_generic_error_code()
		BV.WM.spawn_popup(ConfigurablePopupDefinition.create_single_button_close_popup(
			"Save failed",
			"Saved positions but failed to save genome.\n\n%s\n%s" % [save_details[0], save_details[1]]
		))
		return
	var done := "Aligned" if action == SelectionArrange.ACTION_ALIGN else "Distributed"
	BV.NOTIF.add_notification("%s %d areas on %s." % [done, areas.size(), axis_label])


func _finish_arrange_request() -> void:
	_arrange_in_progress = false
	if not _close_requested_during_arrange:
		return
	var clear_selection := _close_requested_clear_selection
	_close_requested_during_arrange = false
	close_window(clear_selection)


func _condensed_keep_open_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if _btn_arrange != null and _btn_arrange.is_menu_open():
		var menu_rect := _btn_arrange.get_open_menu_rect()
		if menu_rect.has_area():
			rects.append(menu_rect)
	return rects


## Scene clicks dismiss the toolbar without clearing the selection the scene click is about to change.
func _close_for_condensed_dismiss() -> void:
	close_window(false)


func _on_focus_lost() -> void:
	# Do not clear active scene selection when this utility window loses focus.
	# Scene clicks (including additive multi-select) naturally move focus away.
	# The Arrange popup is a separate window; opening it must not dismiss this menu.
	if _arrange_in_progress:
		return
	if _btn_arrange != null and _btn_arrange.is_menu_open():
		return
	close_window(false)

# Debug function to check selection state
func _debug_selection_state(context: String) -> void:
	pass

# Override close_window to add safety debugging
# clear_selection: when true (Escape, X button, focus loss), clears selection. When false (Move 3D, etc.), keeps it.
func close_window(clear_selection: bool = true) -> void:
	if _arrange_in_progress:
		_close_requested_during_arrange = true
		_close_requested_clear_selection = clear_selection
		return
	if _btn_arrange != null:
		_btn_arrange.close_menu()
	_debug_selection_state("close_window")
	if clear_selection and BV != null and BV.UI != null and BV.UI.selection_system != null:
		BV.UI.selection_system.clear_all_highlighted()
	if _selection.size() == 0:
		pass
	super.close_window()

## Update the existing quick menu for multi-area selection without respawning.
## Returns true when refreshed; false if mode mismatch requires respawn.
func try_refresh_without_respawn(selection: Array[GenomeObject], context: SelectionSystem.SOURCE_CONTEXT) -> bool:
	var new_mode: GenomeObject.ARRAY_MAKEUP = GenomeObject.get_makeup_of_array(selection)
	if _mode != GenomeObject.ARRAY_MAKEUP.MULTIPLE_CORTICAL_AREAS or new_mode != GenomeObject.ARRAY_MAKEUP.MULTIPLE_CORTICAL_AREAS:
		return false
	_selection = selection
	_selection_context = context
	_refresh_multi_cortical_controls()
	_reposition_near_mouse()
	return true

func _reposition_near_mouse() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var window_size: Vector2i = size
	if window_size.x <= 2 or window_size.y <= 2:
		window_size = get_combined_minimum_size()
	var position_to_spawn: Vector2i = Vector2i(
		mouse_pos.x - (window_size.x / 2.0),
		mouse_pos.y - window_size.y - SPAWN_DISTANCE_PX
	)
	if position_to_spawn.y < 0:
		position_to_spawn.y = mouse_pos.y + SPAWN_DISTANCE_PX
		position_to_spawn.y = min(position_to_spawn.y, viewport_size.y - window_size.y)
	position = position_to_spawn

func _reposition_near_mouse_after_layout() -> void:
	await get_tree().process_frame
	_reposition_near_mouse()

func _refresh_multi_cortical_controls() -> void:
	var iopu_config_button: TextureButton = _window_internals.get_node('ToolbarGrid/SetupIOPU')
	var move_to_region_button: TextureButton = _window_internals.get_node('ToolbarGrid/AddToRegion')
	var delete_button: TextureButton = _window_internals.get_node('ToolbarGrid/Delete')
	var areas: Array[AbstractCorticalArea] = AbstractCorticalArea.genome_array_to_cortical_area_array(_selection)
	var details_button: TextureButton = _window_internals.get_node("ToolbarGrid/Details")
	var reset_button: TextureButton = _window_internals.get_node("ToolbarGrid/Reset")
	_titlebar.title = "Selected multiple areas"
	details_button.tooltip_text = "View Details of these Cortical Areas"
	reset_button.tooltip_text = "Reset selected cortical areas..."
	move_to_region_button.disabled = false
	move_to_region_button.tooltip_text = "Add to a circuit..."
	delete_button.disabled = false
	delete_button.tooltip_text = "Delete selected cortical areas..."
	var all_ipu_opu := true
	for area in areas:
		if not (area is IPUCorticalArea or area is OPUCorticalArea):
			all_ipu_opu = false
			break
	iopu_config_button.visible = true
	iopu_config_button.disabled = not all_ipu_opu
	iopu_config_button.tooltip_text = "Open IPU/OPU configuration" if all_ipu_opu else "IPU/OPU configuration only."
	var is_circuit_builder_context := _selection_context in [
		SelectionSystem.SOURCE_CONTEXT.FROM_CIRCUIT_BUILDER_CLICK,
		SelectionSystem.SOURCE_CONTEXT.FROM_CIRCUIT_BUILDER_DRAG
	]
	if _btn_relocate_2d != null:
		_btn_relocate_2d.visible = true
		_btn_relocate_2d.disabled = false
		_btn_relocate_2d.tooltip_text = "Relocate selected areas (2D)" if is_circuit_builder_context else "Relocate selected areas (3D gizmo)"
	_sync_arrange_button(areas)
	if !AbstractCorticalArea.can_all_areas_exist_in_subregion(areas):
		move_to_region_button.disabled = true
		move_to_region_button.tooltip_text = "One of the selected areas is of Input, Output, or Core type which is not allowed inside a neural circuit."
	if !AbstractCorticalArea.can_all_areas_be_deleted(areas):
		delete_button.disabled = true
		var rfr_reason: String = ""
		for a in areas:
			if not a.user_can_delete_this_area:
				rfr_reason = a.user_delete_blocked_reason()
				if not rfr_reason.is_empty():
					break
		delete_button.tooltip_text = rfr_reason if not rfr_reason.is_empty() else "One or more of the selected areas cannot be deleted."
	_apply_icon_tooltips()
	_fit_toolbar()


## Floating-window icons use the theme tooltip. Built-in tips draw under this layer.
func _apply_icon_tooltips() -> void:
	if _window_internals == null:
		return
	if get_node_or_null(_TOP_BAR_TOOLTIP_MANAGER_PATH) == null:
		return
	var grid := _window_internals.get_node_or_null("ToolbarGrid") as GridContainer
	if grid == null:
		return
	for child in grid.get_children():
		var button := child as Control
		if button == null or not button.visible:
			continue
		var text := button.tooltip_text.strip_edges()
		if text.is_empty():
			continue
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		var trigger := button.get_node_or_null("TooltipTrigger")
		if trigger == null:
			trigger = Node.new()
			trigger.set_script(_ICON_TOOLTIP_TRIGGER_SCRIPT)
			trigger.name = "TooltipTrigger"
			trigger.set("tooltip_manager_path", _TOP_BAR_TOOLTIP_MANAGER_PATH)
			button.add_child(trigger)
		trigger.set("show_full_text", true)
		if trigger.has_method("set_tooltip_text"):
			trigger.call("set_tooltip_text", text)
		else:
			trigger.set("tooltip_text", text)
		button.tooltip_text = ""


## Single cortical-area popups wrap actions onto two rows.
## The "Selected multiple areas" popup and every other quick menu stay on one row.
## Hidden actions do not reserve a cell.
func _fit_toolbar() -> void:
	_apply_toolbar_icon_size()
	var grid: GridContainer = _window_internals.get_node("ToolbarGrid") as GridContainer
	var visible_count: int = 0
	for child in grid.get_children():
		var control := child as Control
		if control != null and control.visible:
			visible_count += 1
	grid.columns = toolbar_column_count(visible_count, toolbar_wraps_two_rows(_mode))
	if toolbar_packs_icons_flush(_mode):
		grid.add_theme_constant_override("h_separation", 0)
	else:
		grid.remove_theme_constant_override("h_separation")
	if _titlebar != null:
		_titlebar.set_close_button_balanced(not toolbar_matches_icon_row(_mode))
	if toolbar_matches_icon_row(_mode):
		shrink_window()


## True only for the single cortical-area quick menu.
static func toolbar_wraps_two_rows(mode: GenomeObject.ARRAY_MAKEUP) -> bool:
	return mode == GenomeObject.ARRAY_MAKEUP.SINGLE_CORTICAL_AREA


## The multi-area popup packs its icons together. Other quick menus keep theme spacing.
static func toolbar_packs_icons_flush(mode: GenomeObject.ARRAY_MAKEUP) -> bool:
	return mode == GenomeObject.ARRAY_MAKEUP.MULTIPLE_CORTICAL_AREAS


## The multi-area popup sizes to the icon row. Its title does not keep the window wider.
static func toolbar_matches_icon_row(mode: GenomeObject.ARRAY_MAKEUP) -> bool:
	return mode == GenomeObject.ARRAY_MAKEUP.MULTIPLE_CORTICAL_AREAS


## Column count for the quick-menu icon grid.
## wrap_two_rows is true only for the single cortical-area popup.
static func toolbar_column_count(visible_count: int, wrap_two_rows: bool) -> int:
	var count: int = maxi(visible_count, 1)
	if wrap_two_rows:
		return maxi((count + 1) / 2, 1)
	return count


## Popup icons use the same size as the top-bar icon buttons on this view.
func _apply_toolbar_icon_size(_theme: Theme = null) -> void:
	if _window_internals == null:
		return
	var grid := _window_internals.get_node_or_null("ToolbarGrid") as GridContainer
	if grid == null:
		return
	var icon_size := _top_bar_icon_size()
	for child in grid.get_children():
		var button := child as TextureButton
		if button == null:
			continue
		button.custom_minimum_size = icon_size
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _top_bar_icon_size() -> Vector2:
	var element := ComboButtonStripStyler.TOP_BAR_CONTROL_THEME
	var strip_scale: float = BrainObjectsCombo.scale_steps_below(
		BV.UI.possible_UI_scales,
		BV.UI.loaded_theme_scale.x,
		BrainObjectsCombo.TAB_STRIP_SCALE_STEPS_SMALLER
	)
	var strip_theme: Theme = BV.UI.load_theme_resource(strip_scale, UIManager.THEME_COLORS.DARK)
	if strip_theme != null and strip_theme.has_constant("size_x", element) and strip_theme.has_constant("size_y", element):
		return Vector2(strip_theme.get_constant("size_x", element), strip_theme.get_constant("size_y", element))
	push_error("Quick menu could not load the top-bar icon size at scale %s" % strip_scale)
	return Vector2(BV.UI.get_minimum_size_from_loaded_theme(element))
