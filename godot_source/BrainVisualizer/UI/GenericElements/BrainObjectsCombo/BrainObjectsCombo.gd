extends HBoxContainer
class_name BrainObjectsCombo

## Ordered connectome hamburger rows. Append a new id here when adding a combo
## (e.g. classifier) and place the matching combo button under %MenuItems.
const CONNECTOME_MENU_ITEM_CIRCUIT: StringName = &"circuit"
const CONNECTOME_MENU_ITEM_INTERCONNECT: StringName = &"interconnect"
const CONNECTOME_MENU_ITEM_MEMORY: StringName = &"memory"
const CONNECTOME_MENU_ITEM_CLASSIFIER: StringName = &"classifier"

var context_region: BrainRegion = null

var _is_3d_context: bool = true
var _bm_scene: UI_BrainMonitor_3DScene = null
var _cb_scene: CircuitBuilder = null
var _global_topbar_mode: bool = false
var _force_disabled_override: bool = false

var _btn_connectome: BasePanelContainerButton
var _connectome_label: Label
var _connectome_hover_wired: bool = false
var _connectome_menu: PopupPanel
var _connectome_menu_items: VBoxContainer
var _btn_brain_regions_list: BasePanelContainerButton
var _btn_brain_regions_add: TextureButton
var _btn_interconnect_list: BasePanelContainerButton
var _btn_interconnect_add: TextureButton
var _btn_memory_list: BasePanelContainerButton
var _btn_memory_add: TextureButton
var _btn_classifier_list: BasePanelContainerButton
var _btn_classifier_add: TextureButton
var _btn_rearrange_layout: TextureButton
var _btn_inputs_list: BasePanelContainerButton
var _btn_inputs_add: TextureButton
var _btn_outputs_list: BasePanelContainerButton
var _btn_outputs_add: TextureButton
var _group_connectome: HBoxContainer
var _group_main: PanelContainer
var _group_rearrange: PanelContainer
var _spacer_after_connectome: Control
var _spacer_before_rearrange: Control
var _spacer_after_rearrange: Control
var _spacer_after_add_inputs: Control
var _spacer_before_monitor_tools: Control
var _activity_visualization_dropdown: ActivityVisualizationDropDown
var _activity_toggle_button: TextureButton
var _camera_animations_button: ButtonTextureRectScaling

const HOVER_SCALE := Vector2(1.15, 1.15)
const NORMAL_SCALE := Vector2(1.0, 1.0)
const BACKPLATE_COLOR := Color("252525")
## Fill of inspectors_S.jpg / camera_S.jpg so Connectome matches those icon buttons.
const ICON_BUTTON_PLATE_COLOR := Color8(67, 67, 67)
## Horizontal inset so "Connectome" is not flush against the plate.
const CONNECTOME_PLATE_PAD_X: int = 12
## In-place text pop. Scale avoids a layout resize that cancels hover.
const CONNECTOME_HOVER_SCALE: float = 1.1
const PREFAB_FILTERABLE_LIST_POPUP: PackedScene = preload("res://BrainVisualizer/UI/GenericElements/DropDown/FilterableListPopup.tscn")
const COMBO_STYLER = preload("res://BrainVisualizer/UI/GenericElements/Buttons/ComboButtonStripStyler.gd")
const CUSTOM_TOOLTIP_TRIGGER_SCRIPT = preload("res://BrainVisualizer/UI/GenericElements/CustomTooltip/CustomTooltipTrigger.gd")
const REARRANGE_SIZE_SCALE: float = 1.0
const SIZE_SCALE_3D: float = 0.8
const SIZE_SCALE_2D: float = 0.8

var _list_popup: FilterableListPopup
## True after [method apply_custom_topbar_tooltips] succeeded for this instance (TopBar or tab host).
var _hosted_styled_tooltips_applied: bool = false

## Ordered ids for the Connectome hamburger rows.
static func connectome_menu_item_ids() -> PackedStringArray:
	return PackedStringArray([
		String(CONNECTOME_MENU_ITEM_CIRCUIT),
		String(CONNECTOME_MENU_ITEM_INTERCONNECT),
		String(CONNECTOME_MENU_ITEM_MEMORY),
		String(CONNECTOME_MENU_ITEM_CLASSIFIER),
	])


## Hover scale is a fixed factor. Never multiply the current scale again.
static func connectome_hover_scale(hovered: bool) -> float:
	return CONNECTOME_HOVER_SCALE if hovered else 1.0


## Scene node names under %MenuItems, same order as [method connectome_menu_item_ids].
static func connectome_menu_row_node_names() -> PackedStringArray:
	return PackedStringArray([
		"BrainRegionsList",
		"InterconnectAreasList",
		"MemoryAreasList",
		"ClassifierList",
	])


## Wire the combo buttons and dropdown popup.
func _ready() -> void:
	_group_connectome = %ConnectomeGroup
	_btn_connectome = %ConnectomeButton
	_connectome_label = %ConnectomeButton/HBoxContainer/Label as Label
	_connectome_menu = %ConnectomeMenu
	_connectome_menu_items = %MenuItems
	_btn_brain_regions_list = %BrainRegionsList
	_btn_brain_regions_add = %BrainRegionsList/HBoxContainer/TextureButton_BrainRegions
	_btn_interconnect_list = %InterconnectAreasList
	_btn_interconnect_add = %InterconnectAreasList/HBoxContainer/TextureButton_Interconnect
	_btn_memory_list = %MemoryAreasList
	_btn_memory_add = %MemoryAreasList/HBoxContainer/TextureButton_Memory
	_btn_classifier_list = %ClassifierList
	_btn_classifier_add = %ClassifierList/HBoxContainer/TextureButton_Classifier
	_btn_rearrange_layout = $RearrangePanel/MarginContainer/TextureButton_Rearrange
	_btn_inputs_list = $MainGroup/MarginContainer/ButtonsRow/InputsList
	_btn_inputs_add = $MainGroup/MarginContainer/ButtonsRow/InputsList/HBoxContainer/TextureButton_Inputs
	_btn_outputs_list = $MainGroup/MarginContainer/ButtonsRow/OutputsList
	_btn_outputs_add = $MainGroup/MarginContainer/ButtonsRow/OutputsList/HBoxContainer/TextureButton_Outputs
	_group_main = $MainGroup
	_group_rearrange = $RearrangePanel
	_spacer_after_connectome = $Spacer_AfterConnectome
	_spacer_before_rearrange = $Spacer_BeforeRearrange
	_spacer_after_rearrange = $Spacer_AfterRearrange
	_spacer_after_add_inputs = $MainGroup/MarginContainer/ButtonsRow/Spacer_AfterAddInputs
	_spacer_before_monitor_tools = $Spacer_BeforeMonitorTools
	_activity_visualization_dropdown = $ActivityVisualizationDropDown
	_activity_toggle_button = $ActivityVisualizationDropDown/ToggleImageDropDown as TextureButton
	_camera_animations_button = $CameraAnimations as ButtonTextureRectScaling
	_apply_native_tooltips_for_combo_strip()

	# Ensure the combo captures events within its bounds; individual buttons will stop events
	mouse_filter = Control.MOUSE_FILTER_STOP

	_btn_connectome.focus_mode = Control.FOCUS_ALL
	_btn_connectome.pressed.connect(_toggle_connectome_menu)
	_btn_connectome.pressed.connect(_reset_connectome_label_hover)
	_btn_connectome.focus_exited.connect(_on_connectome_focus_exited)
	_btn_brain_regions_list.pressed.connect(_open_brain_regions)
	_btn_brain_regions_add.pressed.connect(_add_brain_region)
	_btn_interconnect_list.pressed.connect(_open_interconnect_areas)
	_btn_interconnect_add.pressed.connect(_add_interconnect_area)
	_btn_memory_list.pressed.connect(_open_memory_areas)
	_btn_memory_add.pressed.connect(_add_memory_area)
	_btn_classifier_list.pressed.connect(_open_classifier_areas)
	_btn_classifier_add.pressed.connect(_add_classifier)
	_btn_rearrange_layout.pressed.connect(_request_relayout)
	_btn_inputs_list.pressed.connect(_open_inputs)
	_btn_inputs_add.pressed.connect(_add_input_area)
	_btn_outputs_list.pressed.connect(_open_outputs)
	_btn_outputs_add.pressed.connect(_add_output_area)
	_set_connectome_menu_row_focus_none()
	align_connectome_menu_add_buttons(_connectome_menu_items)
	if _activity_visualization_dropdown != null:
		_activity_visualization_dropdown.activity_mode_changed.connect(_on_monitor_activity_mode_changed)
	if _camera_animations_button != null:
		_camera_animations_button.pressed.connect(_on_monitor_camera_animations_pressed)
	_apply_shared_combo_spacing_tokens()
	_flatten_group_wrapper_panels()
	_style_connectome_like_icon_buttons()
	_ensure_list_popup()
	_update_buttons_state()
	queue_redraw()
	# Ensure background redraws on resize/theme changes for consistent back plate
	resized.connect(func(): queue_redraw())
	
	# BrainMonitor tabs run inside a SubViewport; theme inheritance may not reach this subtree.
	# Opt-in to BV's theme-driven scaling so these "top bar" buttons resize with +/- UI scaling.
	BV.UI.theme_changed.connect(_on_theme_changed)
	_on_theme_changed(BV.UI.loaded_theme)


## Default Godot tooltips when this strip is not using the main top bar custom tooltip host.
func _apply_native_tooltips_for_combo_strip() -> void:
	_btn_connectome.tooltip_text = "Connectome objects"
	_btn_brain_regions_list.tooltip_text = "Select circuit"
	_btn_brain_regions_add.tooltip_text = "Add circuit"
	_btn_interconnect_list.tooltip_text = "Select interconnect area"
	_btn_interconnect_add.tooltip_text = "Add interconnect area"
	_btn_memory_list.tooltip_text = "Select memory area"
	_btn_memory_add.tooltip_text = "Add memory area"
	_btn_classifier_list.tooltip_text = "Select classifier"
	_btn_classifier_add.tooltip_text = "Add classifier"
	_btn_inputs_list.tooltip_text = "Select input area"
	_btn_inputs_add.tooltip_text = "Add input area"
	_btn_outputs_list.tooltip_text = "Select output area"
	_btn_outputs_add.tooltip_text = "Add output area"
	_btn_rearrange_layout.tooltip_text = "Circuit organizer"
	if _activity_visualization_dropdown != null:
		_activity_visualization_dropdown.tooltip_text = "Inspectors"
	if _camera_animations_button != null:
		_camera_animations_button.tooltip_text = "Camera Animations"


## Walks up from this combo to a node that hosts [CustomTopBarTooltipManager] ([TopBar] or [UITabContainer]).
func _find_first_tooltip_host() -> Node:
	var n: Node = self
	while n != null:
		if n.has_method("get_custom_tooltip_manager"):
			var mgr: Variant = n.call("get_custom_tooltip_manager")
			if mgr != null:
				return n
		n = n.get_parent()
	return null


## Circuit Builder / Brain Monitor: use the tab [UITabContainer] tooltip host (same styled panel as main top bar).
func _try_apply_styled_tooltips_for_current_host() -> void:
	if _hosted_styled_tooltips_applied or _global_topbar_mode:
		return
	apply_custom_topbar_tooltips()


## Disable native tooltips and use [CustomTopBarTooltip] via [TopBar] or [UITabContainer] host.
func apply_custom_topbar_tooltips() -> void:
	var host: Node = _find_first_tooltip_host()
	if host == null:
		return
	if _activity_visualization_dropdown != null:
		var act_toggle: ToggleImageDropDown = _activity_visualization_dropdown.get_node_or_null(
			"ToggleImageDropDown"
		) as ToggleImageDropDown
		CustomTopBarTooltipManager.wire_toggle_dropdown_menu_tooltips(act_toggle, true)
	CustomTopBarTooltipManager.strip_native_tooltips_recursive(self)
	var pairs: Array = [
		[_btn_connectome, "Connectome objects"],
		[_btn_brain_regions_list, "View all circuits"],
		[_btn_brain_regions_add, "Add a new circuit"],
		[_btn_interconnect_list, "View interconnect areas"],
		[_btn_interconnect_add, "Add interconnect area"],
		[_btn_memory_list, "View memory areas"],
		[_btn_memory_add, "Add memory area"],
		[_btn_classifier_list, "View classifiers"],
		[_btn_classifier_add, "Add classifier"],
		[_btn_inputs_list, "View all input areas"],
		[_btn_inputs_add, "Add input area"],
		[_btn_outputs_list, "View all output areas"],
		[_btn_outputs_add, "Add output area"],
		[_btn_rearrange_layout, "Circuit organizer"],
	]
	if _activity_visualization_dropdown != null:
		pairs.append([_activity_visualization_dropdown, "Inspectors"])
	if _camera_animations_button != null:
		pairs.append([_camera_animations_button, "Camera animations"])
	for pair in pairs:
		var ctl: Control = pair[0] as Control
		var txt: String = str(pair[1])
		if ctl == null or not is_instance_valid(ctl):
			continue
		ctl.tooltip_text = ""
		ctl.mouse_filter = Control.MOUSE_FILTER_PASS
		var existing: Node = ctl.get_node_or_null("TooltipTrigger")
		if existing != null:
			if existing.has_method("set_tooltip_text"):
				existing.call("set_tooltip_text", txt)
			else:
				existing.set("tooltip_text", txt)
			continue
		var trigger := Node.new()
		trigger.set_script(CUSTOM_TOOLTIP_TRIGGER_SCRIPT)
		trigger.name = "TooltipTrigger"
		ctl.add_child(trigger)
		trigger.set("tooltip_text", txt)
	if _btn_connectome != null:
		_btn_connectome.mouse_filter = Control.MOUSE_FILTER_STOP
	_hosted_styled_tooltips_applied = true


## Apply shared spacing tokens to keep all combo strips consistent across views.
func _apply_shared_combo_spacing_tokens() -> void:
	var list_hbox_paths := []
	list_hbox_paths.append(NodePath("ConnectomeGroup/ConnectomeButton/HBoxContainer"))
	list_hbox_paths.append(NodePath("ConnectomeGroup/ConnectomeMenu/MarginContainer/MenuItems/BrainRegionsList/HBoxContainer"))
	list_hbox_paths.append(NodePath("ConnectomeGroup/ConnectomeMenu/MarginContainer/MenuItems/InterconnectAreasList/HBoxContainer"))
	list_hbox_paths.append(NodePath("ConnectomeGroup/ConnectomeMenu/MarginContainer/MenuItems/MemoryAreasList/HBoxContainer"))
	list_hbox_paths.append(NodePath("MainGroup/MarginContainer/ButtonsRow/InputsList/HBoxContainer"))
	list_hbox_paths.append(NodePath("MainGroup/MarginContainer/ButtonsRow/OutputsList/HBoxContainer"))
	COMBO_STYLER.apply_list_hbox_spacing(self, list_hbox_paths)
	var spacer_paths := []
	spacer_paths.append(NodePath("Spacer_AfterConnectome"))
	spacer_paths.append(NodePath("MainGroup/MarginContainer/ButtonsRow/Spacer_AfterAddInputs"))
	spacer_paths.append(NodePath("Spacer_BeforeRearrange"))
	spacer_paths.append(NodePath("Spacer_AfterRearrange"))
	spacer_paths.append(NodePath("Spacer_BeforeMonitorTools"))
	COMBO_STYLER.apply_spacer_width(self, spacer_paths)


## Remove per-group wrapper plates so all contexts read as one cohesive strip.
func _flatten_group_wrapper_panels() -> void:
	var empty_style := StyleBoxEmpty.new()
	var panels := []
	if _group_main != null:
		panels.append(_group_main)
	if _group_rearrange != null:
		panels.append(_group_rearrange)
	for panel in panels:
		panel.add_theme_stylebox_override("panel", empty_style)

func _on_theme_changed(new_theme: Theme) -> void:
	theme = new_theme
	if _connectome_menu != null:
		_connectome_menu.theme = new_theme
	_apply_theme_sizes_recursive(self)
	if _connectome_menu != null:
		_apply_theme_sizes_recursive(_connectome_menu)
	_apply_rearrange_button_size()
	_style_connectome_like_icon_buttons()


## Current top-bar scale by usage context.
func _get_context_size_scale() -> float:
	return SIZE_SCALE_3D if _is_3d_context else SIZE_SCALE_2D

func _apply_theme_sizes_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is TextureButton:
			var tb := child as TextureButton
			var tb_fallback: StringName = StringName(tb.theme_type_variation) if String(tb.theme_type_variation) != "" else &"TextureButton"
			tb.custom_minimum_size = BV.UI.get_minimum_size_from_loaded_theme_variant_given_control(tb, tb_fallback) * _get_context_size_scale()
		elif child is TextureRect:
			var tr := child as TextureRect
			var tr_fallback: StringName = StringName(tr.theme_type_variation) if String(tr.theme_type_variation) != "" else &"TextureRect"
			tr.custom_minimum_size = BV.UI.get_minimum_size_from_loaded_theme_variant_given_control(tr, tr_fallback) * _get_context_size_scale()
		_apply_theme_sizes_recursive(child)

## Paint and size Connectome like the inspector / camera icon buttons beside it.
func _style_connectome_like_icon_buttons() -> void:
	if _btn_connectome == null:
		return
	_btn_connectome.set_meta("plate_color", ICON_BUTTON_PLATE_COLOR)
	_btn_connectome.set_meta("plate_padding_x", CONNECTOME_PLATE_PAD_X)
	_btn_connectome.set_meta("plate_padding_y", 0)
	_btn_connectome.clip_contents = false
	if _connectome_label != null:
		_connectome_label.remove_theme_font_size_override("font_size")
		_connectome_label.scale = Vector2.ONE
	_btn_connectome._apply_plate_color()
	var icon_height: float = _neighbor_icon_button_height()
	if icon_height > 0.0:
		_btn_connectome.custom_minimum_size.y = icon_height
		_btn_connectome.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_wire_connectome_label_hover()


func _wire_connectome_label_hover() -> void:
	if _connectome_hover_wired or _btn_connectome == null:
		return
	if _connectome_label != null:
		_connectome_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_connectome_label.resized.connect(_center_connectome_label_pivot)
		_center_connectome_label_pivot()
	_btn_connectome.mouse_entered.connect(_on_connectome_label_hover.bind(true))
	_btn_connectome.mouse_exited.connect(_on_connectome_mouse_exited)
	_connectome_hover_wired = true


func _center_connectome_label_pivot() -> void:
	if _connectome_label == null:
		return
	_connectome_label.pivot_offset = _connectome_label.size * 0.5


func _on_connectome_label_hover(hovered: bool) -> void:
	if not hovered:
		_reset_connectome_label_hover()
		return
	_apply_connectome_label_scale(connectome_hover_scale(true))


func _on_connectome_mouse_exited() -> void:
	if _btn_connectome != null and _btn_connectome.get_global_rect().has_point(_btn_connectome.get_global_mouse_position()):
		return
	_reset_connectome_label_hover()


func _reset_connectome_label_hover() -> void:
	_apply_connectome_label_scale(connectome_hover_scale(false))


func _apply_connectome_label_scale(scale_factor: float) -> void:
	if _connectome_label == null:
		return
	_center_connectome_label_pivot()
	_connectome_label.scale = Vector2(scale_factor, scale_factor)


func _neighbor_icon_button_height() -> float:
	if _activity_toggle_button != null and _activity_toggle_button.custom_minimum_size.y > 0.0:
		return _activity_toggle_button.custom_minimum_size.y
	if _camera_animations_button != null and _camera_animations_button.custom_minimum_size.y > 0.0:
		return _camera_animations_button.custom_minimum_size.y
	return 0.0


## Make the rearrange button slightly larger than standard.
func _apply_rearrange_button_size() -> void:
	if _btn_rearrange_layout == null:
		return
	var fallback: StringName = StringName(_btn_rearrange_layout.theme_type_variation) if String(_btn_rearrange_layout.theme_type_variation) != "" else &"TextureButton"
	var base_size := BV.UI.get_minimum_size_from_loaded_theme_variant_given_control(_btn_rearrange_layout, fallback)
	_btn_rearrange_layout.custom_minimum_size = base_size * REARRANGE_SIZE_SCALE * _get_context_size_scale()

func set_3d_context(bm_scene: UI_BrainMonitor_3DScene, region: BrainRegion) -> void:
	if _is_3d_context and _bm_scene == bm_scene and context_region == region and not _global_topbar_mode:
		return
	if not _hosted_styled_tooltips_applied:
		_try_apply_styled_tooltips_for_current_host()
	_is_3d_context = true
	_global_topbar_mode = false
	_bm_scene = bm_scene
	context_region = region
	_update_buttons_state()
	_on_theme_changed(theme)

## Switch to 2D context and refresh listings.
func set_2d_context(cb_scene: CircuitBuilder, region: BrainRegion) -> void:
	_is_3d_context = false
	_global_topbar_mode = false
	_cb_scene = cb_scene
	context_region = region
	_update_buttons_state()
	_on_theme_changed(theme)
	if not _hosted_styled_tooltips_applied:
		_try_apply_styled_tooltips_for_current_host()


## Use this component as the shared global top-bar strip.
## Top bar is circuits + I/O only. Connectome hamburger stays on Circuit Builder / Brain Monitor tabs.
func set_global_topbar_mode() -> void:
	_global_topbar_mode = true
	_bm_scene = null
	_cb_scene = null
	context_region = null
	_place_circuits_on_topbar_strip()
	_update_buttons_state()
	_on_theme_changed(theme)


## Circuits sit on the main top bar strip; they stay inside the Connectome menu on tab combos.
func _place_circuits_on_topbar_strip() -> void:
	if _btn_brain_regions_list == null:
		return
	if _btn_brain_regions_list.get_parent() == self:
		return
	var menu_parent: Node = _btn_brain_regions_list.get_parent()
	if menu_parent != null:
		menu_parent.remove_child(_btn_brain_regions_list)
	add_child(_btn_brain_regions_list)
	move_child(_btn_brain_regions_list, 0)
	_btn_brain_regions_list.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_btn_brain_regions_list.visible = true
	if _group_connectome != null:
		_group_connectome.visible = false
	if _btn_connectome != null:
		_btn_connectome.visible = false
	_close_connectome_menu()


## Allow host containers to force-enable/disable the strip uniformly.
func set_force_disabled(disabled: bool) -> void:
	_force_disabled_override = disabled
	_update_buttons_state()

## Enable or disable buttons based on whether a region is active.
func _update_buttons_state() -> void:
	if _global_topbar_mode:
		_set_all_buttons_disabled(_force_disabled_override)
		_set_visibility_for_context(true, false)
		_update_monitor_tools_visibility()
		return
	if context_region == null:
		_set_all_buttons_disabled(true)
		_set_visibility_for_context(false, false)
		_update_monitor_tools_visibility()
		return
	# Listing is always enabled (direct-only; will be empty if none)
	_set_all_buttons_disabled(_force_disabled_override)
	# Root region keeps Inputs/Outputs on the strip; connectome objects stay in the hamburger.
	var is_root := _is_root_region()
	_set_visibility_for_context(is_root, not _is_3d_context)
	_update_monitor_tools_visibility()


## Toggle disabled state for every control in the combo strip.
func _set_all_buttons_disabled(disabled: bool) -> void:
	_btn_connectome.disabled = disabled
	_btn_brain_regions_list.disabled = disabled
	_btn_brain_regions_add.disabled = disabled
	_btn_interconnect_list.disabled = disabled
	_btn_interconnect_add.disabled = disabled
	_btn_memory_list.disabled = disabled
	_btn_memory_add.disabled = disabled
	_btn_classifier_list.disabled = disabled
	_btn_classifier_add.disabled = disabled
	_btn_rearrange_layout.disabled = disabled
	_btn_inputs_list.disabled = disabled
	_btn_inputs_add.disabled = disabled
	_btn_outputs_list.disabled = disabled
	_btn_outputs_add.disabled = disabled
	if _activity_toggle_button != null:
		_activity_toggle_button.disabled = disabled
	if _camera_animations_button != null:
		_camera_animations_button.disabled = disabled


## Brain Monitor tab strip only: same controls as the main top bar, scoped to this tab's 3D scene.
func _update_monitor_tools_visibility() -> void:
	var show_tools := _is_3d_context and _bm_scene != null and not _global_topbar_mode
	# Do not insert extra spacers here. Connectome / inspector / camera share the strip gap.
	if _spacer_before_monitor_tools != null:
		_spacer_before_monitor_tools.visible = false
	if _activity_visualization_dropdown != null:
		_activity_visualization_dropdown.visible = show_tools
	if _camera_animations_button != null:
		_camera_animations_button.visible = show_tools


func _on_monitor_activity_mode_changed(action: StringName, enabled: bool) -> void:
	if _bm_scene == null:
		return
	if action == ActivityVisualizationDropDown.ACTION_GLOBAL_NEURAL_CONNECTIONS:
		_toggle_global_neural_connections_for_scene(_bm_scene, enabled)
		BV.UI.set_connection_inspector_stop_overlay_visible(enabled)
	elif action == ActivityVisualizationDropDown.ACTION_VOXEL_INSPECTOR:
		BV.UI.brain_monitor_activity_mode = UIManager.BRAIN_MONITOR_ACTIVITY_MODE.VOXEL_INSPECTOR
		BV.WM.spawn_voxel_inspector()
	elif action == ActivityVisualizationDropDown.ACTION_MEMORY_INSPECTOR:
		BV.UI.brain_monitor_activity_mode = UIManager.BRAIN_MONITOR_ACTIVITY_MODE.MEMORY_INSPECTOR
		BV.WM.spawn_memory_inspector()


func _toggle_global_neural_connections_for_scene(brain_monitor: UI_BrainMonitor_3DScene, enabled: bool) -> void:
	var cortical_area_objects: Array = _find_all_cortical_area_objects_in_scene(brain_monitor)
	for cortical_area_obj in cortical_area_objects:
		if enabled:
			cortical_area_obj.set_hover_over_volume_state(true)
		else:
			cortical_area_obj.set_hover_over_volume_state(false)


## Keeps the Connection inspector toggle visuals aligned when the mode is cleared from elsewhere (e.g. floating stop button).
func sync_connection_inspector_enabled(enabled: bool) -> void:
	if _activity_visualization_dropdown != null:
		_activity_visualization_dropdown.set_connection_inspector_enabled(enabled)


func _find_all_cortical_area_objects_in_scene(root: Node) -> Array:
	var cortical_areas: Array = []
	_recursive_find_cortical_areas_bm(root, cortical_areas)
	return cortical_areas


func _recursive_find_cortical_areas_bm(node: Node, cortical_areas: Array) -> void:
	if node.get_script() and node.get_script().get_global_name() == "UI_BrainMonitor_CorticalArea":
		cortical_areas.append(node)
	for child in node.get_children():
		_recursive_find_cortical_areas_bm(child, cortical_areas)


func _on_monitor_camera_animations_pressed() -> void:
	if _bm_scene != null:
		BV.WM.spawn_camera_animations(_bm_scene)


## Open circuits dropdown for the current region.
func _open_brain_regions() -> void:
	if context_region == null and not _global_topbar_mode:
		return
	var items := _build_region_items()
	_open_dropdown_for_items(_btn_brain_regions_list, items, "Filter circuits...", func(region: BrainRegion):
		_focus_region(region)
	)

func _add_brain_region() -> void:
	var anchor := _btn_brain_regions_add if _global_topbar_mode else _connectome_action_anchor()
	if _global_topbar_mode:
		# Top bar trigger defines context: create under main/root scene.
		BV.WM.spawn_select_region_template(null, true, anchor)
		return
	if context_region == null:
		return
	BV.WM.spawn_select_region_template(context_region, false, anchor)

## Open interconnect areas dropdown for the current region.
func _open_interconnect_areas() -> void:
	if context_region == null and not _global_topbar_mode:
		return
	var items := _build_cortical_items_for_types([
		AbstractCorticalArea.CORTICAL_AREA_TYPE.CUSTOM,
		AbstractCorticalArea.CORTICAL_AREA_TYPE.INTERCONNECT,
	])
	_open_dropdown_for_items(_btn_interconnect_list, items, "Filter interconnect areas...", func(area: AbstractCorticalArea):
		_focus_cortical(area)
	)

## Open memory areas dropdown for the current region.
func _open_memory_areas() -> void:
	if context_region == null and not _global_topbar_mode:
		return
	var items := _build_cortical_items_for_types([AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY])
	_open_dropdown_for_items(_btn_memory_list, items, "Filter memory areas...", func(area: AbstractCorticalArea):
		_focus_cortical(area)
	)

func _open_classifier_areas() -> void:
	if context_region == null and not _global_topbar_mode:
		return
	var items := _build_classifier_items()
	_open_dropdown_for_items(_btn_classifier_list, items, "Filter classifiers...", func(classifier: GenomeClassifier):
		_focus_classifier(classifier)
	)

func _add_classifier() -> void:
	var region: BrainRegion = context_region
	if region == null and _cb_scene != null:
		region = _cb_scene.representing_region
	if region == null and _bm_scene != null:
		region = _bm_scene.representing_region
	if region == null:
		var popup_definition: ConfigurablePopupDefinition = ConfigurablePopupDefinition.create_single_button_close_popup(
			"ERROR",
			"Open a Circuit Builder or Brain Monitor tab, then add the classifier in that region.",
			"OK"
		)
		BV.WM.spawn_popup(popup_definition)
		return
	_close_connectome_menu()
	BV.WM.spawn_create_classifier_for_region(region, null)

func _build_classifier_items() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	if context_region == null:
		return items
	var region_id: String = String(context_region.region_ID)
	for classifier in FeagiCore.feagi_local_cache.classifiers.values():
		if not classifier is GenomeClassifier:
			continue
		var typed: GenomeClassifier = classifier as GenomeClassifier
		if typed.current_parent_region == null or String(typed.current_parent_region.region_ID) != region_id:
			continue
		items.append({"label": String(typed.friendly_name), "payload": typed})
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("label", "")).to_lower() < String(b.get("label", "")).to_lower()
	)
	return items

## Open input areas dropdown for the current region.
func _open_inputs() -> void:
	if context_region == null and not _global_topbar_mode:
		return
	var items := _build_cortical_items_for_types([AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU])
	_open_dropdown_for_items(_btn_inputs_list, items, "Filter inputs...", func(area: AbstractCorticalArea):
		_focus_cortical(area)
	)

## Open output areas dropdown for the current region.
func _open_outputs() -> void:
	if context_region == null and not _global_topbar_mode:
		return
	var items := _build_cortical_items_for_types([AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU])
	_open_dropdown_for_items(_btn_outputs_list, items, "Filter outputs...", func(area: AbstractCorticalArea):
		_focus_cortical(area)
	)

func _add_interconnect_area() -> void:
	var anchor := _connectome_action_anchor()
	if _global_topbar_mode:
		BV.WM.spawn_create_cortical_with_type(AbstractCorticalArea.CORTICAL_AREA_TYPE.CUSTOM, anchor)
		return
	if context_region == null:
		return
	print("BrainObjectsCombo: Opening create interconnect window for region:", context_region.region_ID)
	BV.WM.spawn_create_cortical_with_type_for_region(context_region, AbstractCorticalArea.CORTICAL_AREA_TYPE.CUSTOM, anchor)

func _add_memory_area() -> void:
	var anchor := _connectome_action_anchor()
	if _global_topbar_mode:
		BV.WM.spawn_create_cortical_with_type(AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY, anchor)
		return
	if context_region == null:
		return
	print("BrainObjectsCombo: Opening create memory window for region:", context_region.region_ID)
	BV.WM.spawn_create_cortical_with_type_for_region(context_region, AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY, anchor)

func _add_input_area() -> void:
	if _global_topbar_mode:
		BV.WM.spawn_create_cortical_with_type(AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU, _btn_inputs_add)
		return
	if context_region == null:
		return
	print("BrainObjectsCombo: Opening create input window for region:", context_region.region_ID)
	BV.WM.spawn_create_cortical_with_type_for_region(context_region, AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU, _btn_inputs_add)

func _add_output_area() -> void:
	if _global_topbar_mode:
		BV.WM.spawn_create_cortical_with_type(AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU, _btn_outputs_add)
		return
	if context_region == null:
		return
	print("BrainObjectsCombo: Opening create output window for region:", context_region.region_ID)
	BV.WM.spawn_create_cortical_with_type_for_region(context_region, AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU, _btn_outputs_add)


## Top bar / host wiring: anchor for spawning create I/O dialogs to the right of the + button.
func get_inputs_add_button() -> TextureButton:
	return _btn_inputs_add


func get_outputs_add_button() -> TextureButton:
	return _btn_outputs_add


func _request_relayout() -> void:
	if _is_3d_context:
		return
	var cb := _cb_scene if _cb_scene != null else _get_active_cb_from_ui()
	if cb == null:
		return
	var popup_message: StringName = "This will rearrange all nodes in the Circuit Builder view and update their saved 2D positions.\n\nProceed?"
	var cancel_button := ConfigurablePopupDefinition.create_close_button("Cancel")
	var rearrange_button := ConfigurablePopupDefinition.create_action_button(func(): cb.relayout_nodes(), "Rearrange")
	var popup_definition: ConfigurablePopupDefinition = ConfigurablePopupDefinition.new(
		"Circuit organizer",
		popup_message,
		[cancel_button, rearrange_button]
	)
	var popup_window: WindowConfigurablePopup = BV.WM.spawn_popup(popup_definition)
	if popup_window != null and _btn_rearrange_layout != null:
		var button_rect: Rect2 = _btn_rearrange_layout.get_global_rect()
		var popup_target_pos: Vector2 = button_rect.position + Vector2(0.0, button_rect.size.y + 8.0)
		# Apply after setup/import so persisted window memory doesn't override this click anchor.
		popup_window.call_deferred("set", "global_position", popup_target_pos)

func _is_root_region() -> bool:
	if context_region == null:
		return false
	if not FeagiCore or not FeagiCore.feagi_local_cache or not FeagiCore.feagi_local_cache.brain_regions:
		return false
	# During reload windows, region cache may not have an established root yet.
	# Avoid surfacing noisy errors by short-circuiting until root is available.
	if not FeagiCore.feagi_local_cache.brain_regions.is_root_available():
		return false
	var root_region: BrainRegion = FeagiCore.feagi_local_cache.brain_regions.get_root_region()
	return root_region != null and root_region == context_region

func _set_visibility_for_context(show_inputs_and_outputs: bool, show_rearrange_layout: bool) -> void:
	# Connectome hamburger is Circuit Builder / Brain Monitor only.
	var show_connectome := not _global_topbar_mode
	if _group_connectome:
		_group_connectome.visible = show_connectome
	if _btn_connectome:
		_btn_connectome.visible = show_connectome
	if _btn_brain_regions_list:
		_btn_brain_regions_list.visible = true
	if _btn_brain_regions_add:
		_btn_brain_regions_add.visible = true
	if _btn_interconnect_list:
		_btn_interconnect_list.visible = true
	if _btn_interconnect_add:
		_btn_interconnect_add.visible = true
	if _btn_memory_list:
		_btn_memory_list.visible = true
	if _btn_memory_add:
		_btn_memory_add.visible = true
	if _btn_classifier_list:
		_btn_classifier_list.visible = true
	if _btn_classifier_add:
		_btn_classifier_add.visible = true
	if _btn_rearrange_layout:
		_btn_rearrange_layout.visible = show_rearrange_layout
	# Inputs/Outputs remain on the strip (root / global top bar).
	if _btn_inputs_list:
		_btn_inputs_list.visible = show_inputs_and_outputs
	if _btn_inputs_add:
		_btn_inputs_add.visible = show_inputs_and_outputs
	if _btn_outputs_list:
		_btn_outputs_list.visible = show_inputs_and_outputs
	if _btn_outputs_add:
		_btn_outputs_add.visible = show_inputs_and_outputs
	if _spacer_after_add_inputs:
		_spacer_after_add_inputs.visible = show_inputs_and_outputs
	if _group_main:
		_group_main.visible = show_inputs_and_outputs
	if _group_rearrange:
		_group_rearrange.visible = show_rearrange_layout
	if _spacer_after_connectome:
		_spacer_after_connectome.visible = show_inputs_and_outputs
	if _spacer_before_rearrange:
		_spacer_before_rearrange.visible = false
	if _spacer_after_rearrange:
		_spacer_after_rearrange.visible = false

func _apply_hover_visual(button: Control, hovered: bool) -> void:
	# Subtle scale-up on hover to match main 3D view visual feedback style
	button.scale = HOVER_SCALE if hovered else NORMAL_SCALE

## Create and attach the reusable list popup if needed.
func _ensure_list_popup() -> void:
	if _list_popup != null:
		return
	_list_popup = PREFAB_FILTERABLE_LIST_POPUP.instantiate()
	add_child(_list_popup)


## Stretch each hamburger row to the menu width and push + buttons to the right edge.
## Walks %MenuItems so a later classifier row gets the same alignment automatically.
static func align_connectome_menu_add_buttons(menu_items: VBoxContainer) -> void:
	if menu_items == null:
		return
	menu_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for child in menu_items.get_children():
		if not child is Control:
			continue
		var row: Control = child as Control
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var hbox: HBoxContainer = row.get_node_or_null("HBoxContainer") as HBoxContainer
		if hbox == null:
			continue
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for hbox_child in hbox.get_children():
			if hbox_child is Label:
				(hbox_child as Label).size_flags_horizontal = Control.SIZE_EXPAND_FILL
			elif hbox_child is TextureButton:
				(hbox_child as TextureButton).size_flags_horizontal = Control.SIZE_SHRINK_END


## Menu-row buttons must not steal focus or the hamburger closes before the click lands.
func _set_connectome_menu_row_focus_none() -> void:
	var rows: Array[Control] = [
		_btn_brain_regions_list,
		_btn_brain_regions_add,
		_btn_interconnect_list,
		_btn_interconnect_add,
		_btn_memory_list,
		_btn_memory_add,
		_btn_classifier_list,
		_btn_classifier_add,
	]
	for row in rows:
		if row != null:
			row.focus_mode = Control.FOCUS_NONE


## True while the Connectome hamburger popup is visible.
func is_connectome_menu_open() -> bool:
	return _connectome_menu != null and _connectome_menu.visible


## Toggle the Connectome hamburger that hosts circuit / interconnect / memory combos.
func _toggle_connectome_menu() -> void:
	if is_connectome_menu_open():
		_close_connectome_menu()
		return
	_open_connectome_menu()


func _open_connectome_menu() -> void:
	if _connectome_menu == null or _btn_connectome == null:
		return
	if BV.UI:
		_connectome_menu.theme = BV.UI.loaded_theme
	_reparent_connectome_menu_to_root_viewport()
	align_connectome_menu_add_buttons(_connectome_menu_items)
	_connectome_menu.size = Vector2.ZERO
	var anchor_screen := _get_connectome_anchor_screen_position()
	_connectome_menu.position = Vector2i(anchor_screen + Vector2(0, _btn_connectome.size.y))
	_connectome_menu.popup()


func _close_connectome_menu() -> void:
	if _connectome_menu == null:
		return
	_connectome_menu.hide()


## Close the hamburger when the trigger loses focus, unless the click stayed in the menu.
func _on_connectome_focus_exited() -> void:
	call_deferred("_close_connectome_menu_if_focus_lost")


func _close_connectome_menu_if_focus_lost() -> void:
	if not is_connectome_menu_open():
		return
	if _is_pointer_over_connectome_menu():
		return
	_close_connectome_menu()


func _is_pointer_over_connectome_menu() -> bool:
	if _connectome_menu == null:
		return false
	var tree := get_tree()
	if tree != null and tree.root != null:
		var root_hovered: Control = tree.root.gui_get_hovered_control()
		if root_hovered != null and (_connectome_menu == root_hovered or _connectome_menu.is_ancestor_of(root_hovered)):
			return true
	var local_viewport := get_viewport()
	if local_viewport != null:
		var local_hovered: Control = local_viewport.gui_get_hovered_control()
		if local_hovered != null and (_connectome_menu == local_hovered or _connectome_menu.is_ancestor_of(local_hovered)):
			return true
	# PopupPanel is a Window, not a Control.
	return _connectome_menu.get_visible_rect().has_point(_connectome_menu.get_mouse_position())


func _reparent_connectome_menu_to_root_viewport() -> void:
	if _connectome_menu == null:
		return
	var tree := get_tree()
	if tree == null:
		return
	var root_viewport := tree.root
	if root_viewport == null:
		return
	if _connectome_menu.get_parent() == root_viewport:
		return
	var parent := _connectome_menu.get_parent()
	if parent != null:
		parent.remove_child(_connectome_menu)
	root_viewport.add_child(_connectome_menu)
	if BV.UI:
		_connectome_menu.theme = BV.UI.loaded_theme


func _get_connectome_anchor_screen_position() -> Vector2:
	var anchor_pos := _btn_connectome.get_global_position()
	var anchor_viewport := _btn_connectome.get_viewport()
	if anchor_viewport == null:
		return anchor_pos
	if anchor_viewport is SubViewport:
		var container := anchor_viewport.get_parent()
		if container is SubViewportContainer:
			anchor_pos += (container as SubViewportContainer).get_global_position()
	return anchor_pos


## After the hamburger closes, spawn list/create UI from the still-visible Connectome button.
func _connectome_action_anchor() -> Control:
	_close_connectome_menu()
	return _btn_connectome


## Open the dropdown with the provided items.
func _open_dropdown_for_items(anchor_button: Control, items: Array[Dictionary], placeholder_text: String, selection_handler: Callable) -> void:
	var anchor := anchor_button
	if is_connectome_menu_open() or _is_connectome_menu_row(anchor_button):
		anchor = _connectome_action_anchor()
	_ensure_list_popup()
	_list_popup.open_with_items(anchor, items, selection_handler, placeholder_text)


func _is_connectome_menu_row(control: Control) -> bool:
	if control == null or _connectome_menu_items == null:
		return false
	return _connectome_menu_items == control or _connectome_menu_items.is_ancestor_of(control)

## Build dropdown items for child regions.
func _build_region_items() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	if context_region != null:
		for region in context_region.contained_regions:
			items.append({"label": region.friendly_name, "payload": region})
	else:
		# Global top bar (context_region cleared): list every sub-circuit under the genome root.
		# Do not scope to the active BM/CB tab — that hid root-level circuits when the Brain Monitor was
		# open on a sub-region, or when split view resolved a different pane first.
		var scope_region: BrainRegion = null
		if FeagiCore != null and FeagiCore.feagi_local_cache != null and FeagiCore.feagi_local_cache.brain_regions != null:
			scope_region = FeagiCore.feagi_local_cache.brain_regions.get_root_region()
		if scope_region != null:
			for region in scope_region.get_all_subregions_recursive():
				items.append({"label": region.friendly_name, "payload": region})
	# When context_region is set (BM 3D / Circuit Builder), list only direct child regions.
	# Do not fall back to the full brain when there are no sub-circuits (that hid the intended scope).
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("label", "")).to_lower() < String(b.get("label", "")).to_lower()
	)
	return items

## Build dropdown items for cortical areas matching any of [param area_types] within scope.
## When [member context_region] is set (Brain Monitor / Circuit Builder tab), only areas under that region tree are listed.
## When it is null (global top bar), lists genome-wide by type.
func _build_cortical_items_for_types(area_types: Array[AbstractCorticalArea.CORTICAL_AREA_TYPE]) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var areas: Array[AbstractCorticalArea] = []
	if context_region != null:
		areas = _collect_cortical_areas_matching_types_in_region_tree(context_region, area_types)
	else:
		for t: AbstractCorticalArea.CORTICAL_AREA_TYPE in area_types:
			for area in FeagiCore.feagi_local_cache.cortical_areas.search_for_available_cortical_areas_by_type(t):
				if area not in areas:
					areas.append(area)
	areas.sort_custom(func(a: AbstractCorticalArea, b: AbstractCorticalArea) -> bool:
		return String(a.friendly_name).to_lower() < String(b.friendly_name).to_lower()
	)
	for area in areas:
		items.append({"label": area.friendly_name, "payload": area})
	return items


## Collects cortical areas of the given types from [param region] and all nested subregions (not genome-wide).
func _collect_cortical_areas_matching_types_in_region_tree(
	region: BrainRegion,
	matching_types: Array[AbstractCorticalArea.CORTICAL_AREA_TYPE]
) -> Array[AbstractCorticalArea]:
	var out: Array[AbstractCorticalArea] = []
	if region == null:
		return out
	for area in region.contained_cortical_areas:
		if area.cortical_type in matching_types:
			out.append(area)
	for subregion in region.contained_regions:
		out.append_array(_collect_cortical_areas_matching_types_in_region_tree(subregion, matching_types))
	return out

func _draw() -> void:
	# Main top bar keeps a shared plate. Tab combos must not, or Connectome
	# melts into the same color as the inspector / camera buttons.
	if not _global_topbar_mode:
		return
	var back_rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(back_rect, BACKPLATE_COLOR, true)

func _focus_region(region: BrainRegion) -> void:
	if _is_3d_context and _bm_scene and _bm_scene.get_pancake_camera():
		if _bm_scene.has_method("focus_on_brain_region"):
			_bm_scene.focus_on_brain_region(region)
			if _bm_scene.has_method("flash_indicator_for_brain_region"):
				_bm_scene.flash_indicator_for_brain_region(region)
		else:
			_bm_scene.get_pancake_camera().teleport_to_look_at_without_changing_angle(Vector3(region.coordinates_3D))
		return
	if _is_3d_context:
		var active_bm := BV.UI.get_active_brain_monitor()
		if active_bm and active_bm.get_pancake_camera():
			if active_bm.has_method("focus_on_brain_region"):
				active_bm.focus_on_brain_region(region)
				if active_bm.has_method("flash_indicator_for_brain_region"):
					active_bm.flash_indicator_for_brain_region(region)
			else:
				active_bm.get_pancake_camera().teleport_to_look_at_without_changing_angle(Vector3(region.coordinates_3D))
			return
	if (not _is_3d_context) and _cb_scene:
		_cb_scene.focus_on_region(region)
		return
	if not _is_3d_context:
		var active_cb := _get_active_cb_from_ui()
		if active_cb:
			active_cb.focus_on_region(region)

func _focus_classifier(classifier: GenomeClassifier) -> void:
	if classifier == null:
		return
	if (not _is_3d_context) and _cb_scene:
		_cb_scene.focus_on_classifier(classifier)
		return
	if not _is_3d_context:
		var active_cb := _get_active_cb_from_ui()
		if active_cb:
			active_cb.focus_on_classifier(classifier)
			return
	var stamp: AbstractCorticalArea = classifier.get_stamp_area()
	if stamp != null:
		_focus_cortical(stamp)


func _focus_cortical(area: AbstractCorticalArea) -> void:
	if _is_3d_context and _bm_scene and _bm_scene.get_pancake_camera():
		if _bm_scene.has_method("focus_on_cortical_area"):
			_bm_scene.focus_on_cortical_area(area)
			if _bm_scene.has_method("flash_indicator_for_cortical_area"):
				_bm_scene.flash_indicator_for_cortical_area(area)
		else:
			var center_pos = Vector3(area.coordinates_3D) + (area.dimensions_3D / 2.0)
			_bm_scene.get_pancake_camera().teleport_to_look_at_without_changing_angle(center_pos)
		return
	if _is_3d_context:
		var active_bm := BV.UI.get_active_brain_monitor()
		if active_bm and active_bm.get_pancake_camera():
			if active_bm.has_method("focus_on_cortical_area"):
				active_bm.focus_on_cortical_area(area)
				if active_bm.has_method("flash_indicator_for_cortical_area"):
					active_bm.flash_indicator_for_cortical_area(area)
			else:
				var center_pos2 = Vector3(area.coordinates_3D) + (area.dimensions_3D / 2.0)
				active_bm.get_pancake_camera().teleport_to_look_at_without_changing_angle(center_pos2)
			return
	if (not _is_3d_context) and _cb_scene:
		_cb_scene.focus_on_cortical_area(area)
		return
	if not _is_3d_context:
		var active_cb := _get_active_cb_from_ui()
		if active_cb:
			active_cb.focus_on_cortical_area(area)


## Find the active Circuit Builder tab if needed.
func _get_active_cb_from_ui() -> CircuitBuilder:
	return _search_for_active_cb_in_view(BV.UI.root_UI_view)


## Recursively search for the active Circuit Builder tab in a UIView.
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
