extends HBoxContainer
class_name BrainObjectsCombo

var context_region: BrainRegion = null

var _is_3d_context: bool = true
var _bm_scene: UI_BrainMonitor_3DScene = null
var _cb_scene: CircuitBuilder = null
var _global_topbar_mode: bool = false
var _force_disabled_override: bool = false

var _btn_brain_regions_list: BasePanelContainerButton
var _btn_brain_regions_add: TextureButton
var _btn_interconnect_list: BasePanelContainerButton
var _btn_interconnect_add: TextureButton
var _btn_memory_list: BasePanelContainerButton
var _btn_memory_add: TextureButton
var _btn_rearrange_layout: TextureButton
var _btn_inputs_list: BasePanelContainerButton
var _btn_inputs_add: TextureButton
var _btn_outputs_list: BasePanelContainerButton
var _btn_outputs_add: TextureButton
var _group_main: PanelContainer
var _group_interconnect: PanelContainer
var _group_memory: PanelContainer
var _group_rearrange: PanelContainer
var _spacer_after_main: Control
var _spacer_after_interconnect: Control
var _spacer_before_rearrange: Control
var _spacer_after_rearrange: Control
var _spacer_after_add_circuits: Control
var _spacer_after_add_inputs: Control
var _spacer_before_monitor_tools: Control
var _activity_visualization_dropdown: ActivityVisualizationDropDown
var _activity_toggle_button: TextureButton
var _camera_animations_button: ButtonTextureRectScaling

const HOVER_SCALE := Vector2(1.15, 1.15)
const NORMAL_SCALE := Vector2(1.0, 1.0)
const BACKPLATE_COLOR := Color("252525")
const PREFAB_FILTERABLE_LIST_POPUP: PackedScene = preload("res://BrainVisualizer/UI/GenericElements/DropDown/FilterableListPopup.tscn")
const COMBO_STYLER = preload("res://BrainVisualizer/UI/GenericElements/Buttons/ComboButtonStripStyler.gd")
const REARRANGE_SIZE_SCALE: float = 1.0
const SIZE_SCALE_3D: float = 0.8
const SIZE_SCALE_2D: float = 0.8

var _list_popup: FilterableListPopup

## Wire the combo buttons and dropdown popup.
func _ready() -> void:
	_btn_brain_regions_list = $MainGroup/MarginContainer/ButtonsRow/BrainRegionsList
	_btn_brain_regions_add = $MainGroup/MarginContainer/ButtonsRow/BrainRegionsList/HBoxContainer/TextureButton_BrainRegions
	_btn_interconnect_list = $InterconnectGroup/MarginContainer/ButtonsRow/InterconnectAreasList
	_btn_interconnect_add = $InterconnectGroup/MarginContainer/ButtonsRow/InterconnectAreasList/HBoxContainer/TextureButton_Interconnect
	_btn_memory_list = $MemoryGroup/MarginContainer/ButtonsRow/MemoryAreasList
	_btn_memory_add = $MemoryGroup/MarginContainer/ButtonsRow/MemoryAreasList/HBoxContainer/TextureButton_Memory
	_btn_rearrange_layout = $RearrangePanel/MarginContainer/TextureButton_Rearrange
	_btn_inputs_list = $MainGroup/MarginContainer/ButtonsRow/InputsList
	_btn_inputs_add = $MainGroup/MarginContainer/ButtonsRow/InputsList/HBoxContainer/TextureButton_Inputs
	_btn_outputs_list = $MainGroup/MarginContainer/ButtonsRow/OutputsList
	_btn_outputs_add = $MainGroup/MarginContainer/ButtonsRow/OutputsList/HBoxContainer/TextureButton_Outputs
	_group_main = $MainGroup
	_group_interconnect = $InterconnectGroup
	_group_memory = $MemoryGroup
	_group_rearrange = $RearrangePanel
	_spacer_after_main = $Spacer_AfterMainGroup
	_spacer_after_interconnect = $Spacer_AfterInterconnectGroup
	_spacer_before_rearrange = $Spacer_BeforeRearrange
	_spacer_after_rearrange = $Spacer_AfterRearrange
	_spacer_after_add_circuits = $MainGroup/MarginContainer/ButtonsRow/Spacer_AfterAddCircuits
	_spacer_after_add_inputs = $MainGroup/MarginContainer/ButtonsRow/Spacer_AfterAddInputs
	_spacer_before_monitor_tools = $Spacer_BeforeMonitorTools
	_activity_visualization_dropdown = $ActivityVisualizationDropDown
	_activity_toggle_button = $ActivityVisualizationDropDown/ToggleImageDropDown as TextureButton
	_camera_animations_button = $CameraAnimations as ButtonTextureRectScaling
	_btn_brain_regions_list.tooltip_text = "Select circuit"
	_btn_brain_regions_add.tooltip_text = "Add circuit"
	_btn_interconnect_list.tooltip_text = "Select interconnect area"
	_btn_interconnect_add.tooltip_text = "Add interconnect area"
	_btn_memory_list.tooltip_text = "Select memory area"
	_btn_memory_add.tooltip_text = "Add memory area"
	_btn_inputs_list.tooltip_text = "Select input area"
	_btn_inputs_add.tooltip_text = "Add input area"
	_btn_outputs_list.tooltip_text = "Select output area"
	_btn_outputs_add.tooltip_text = "Add output area"
	_btn_rearrange_layout.tooltip_text = "Rearrange Circuit Builder layout"

	# Ensure the combo captures events within its bounds; individual buttons will stop events
	mouse_filter = Control.MOUSE_FILTER_STOP

	_btn_brain_regions_list.pressed.connect(_open_brain_regions)
	_btn_brain_regions_add.pressed.connect(_add_brain_region)
	_btn_interconnect_list.pressed.connect(_open_interconnect_areas)
	_btn_interconnect_add.pressed.connect(_add_interconnect_area)
	_btn_memory_list.pressed.connect(_open_memory_areas)
	_btn_memory_add.pressed.connect(_add_memory_area)
	_btn_rearrange_layout.pressed.connect(_request_relayout)
	_btn_inputs_list.pressed.connect(_open_inputs)
	_btn_inputs_add.pressed.connect(_add_input_area)
	_btn_outputs_list.pressed.connect(_open_outputs)
	_btn_outputs_add.pressed.connect(_add_output_area)
	if _activity_visualization_dropdown != null:
		_activity_visualization_dropdown.activity_mode_changed.connect(_on_monitor_activity_mode_changed)
	if _camera_animations_button != null:
		_camera_animations_button.pressed.connect(_on_monitor_camera_animations_pressed)
	_apply_shared_combo_spacing_tokens()
	_flatten_group_wrapper_panels()
	_ensure_list_popup()
	_update_buttons_state()
	queue_redraw()
	# Ensure background redraws on resize/theme changes for consistent back plate
	resized.connect(func(): queue_redraw())
	
	# BrainMonitor tabs run inside a SubViewport; theme inheritance may not reach this subtree.
	# Opt-in to BV's theme-driven scaling so these "top bar" buttons resize with +/- UI scaling.
	BV.UI.theme_changed.connect(_on_theme_changed)
	_on_theme_changed(BV.UI.loaded_theme)


## Apply shared spacing tokens to keep all combo strips consistent across views.
func _apply_shared_combo_spacing_tokens() -> void:
	COMBO_STYLER.apply_list_hbox_spacing(self, [
		NodePath("MainGroup/MarginContainer/ButtonsRow/BrainRegionsList/HBoxContainer"),
		NodePath("MainGroup/MarginContainer/ButtonsRow/InputsList/HBoxContainer"),
		NodePath("MainGroup/MarginContainer/ButtonsRow/OutputsList/HBoxContainer"),
		NodePath("InterconnectGroup/MarginContainer/ButtonsRow/InterconnectAreasList/HBoxContainer"),
		NodePath("MemoryGroup/MarginContainer/ButtonsRow/MemoryAreasList/HBoxContainer")
	])
	COMBO_STYLER.apply_spacer_width(self, [
		NodePath("MainGroup/MarginContainer/ButtonsRow/Spacer_AfterAddCircuits"),
		NodePath("MainGroup/MarginContainer/ButtonsRow/Spacer_AfterAddInputs"),
		NodePath("Spacer_AfterMainGroup"),
		NodePath("Spacer_AfterInterconnectGroup"),
		NodePath("Spacer_BeforeRearrange"),
		NodePath("Spacer_AfterRearrange"),
		NodePath("Spacer_BeforeMonitorTools")
	])


## Remove per-group wrapper plates so all contexts read as one cohesive strip.
func _flatten_group_wrapper_panels() -> void:
	var empty_style := StyleBoxEmpty.new()
	var panels := []
	if _group_main != null:
		panels.append(_group_main)
	if _group_interconnect != null:
		panels.append(_group_interconnect)
	if _group_memory != null:
		panels.append(_group_memory)
	if _group_rearrange != null:
		panels.append(_group_rearrange)
	for panel in panels:
		panel.add_theme_stylebox_override("panel", empty_style)

func _on_theme_changed(new_theme: Theme) -> void:
	theme = new_theme
	_apply_theme_sizes_recursive(self)
	_apply_rearrange_button_size()


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

## Make the rearrange button slightly larger than standard.
func _apply_rearrange_button_size() -> void:
	if _btn_rearrange_layout == null:
		return
	var fallback: StringName = StringName(_btn_rearrange_layout.theme_type_variation) if String(_btn_rearrange_layout.theme_type_variation) != "" else &"TextureButton"
	var base_size := BV.UI.get_minimum_size_from_loaded_theme_variant_given_control(_btn_rearrange_layout, fallback)
	_btn_rearrange_layout.custom_minimum_size = base_size * REARRANGE_SIZE_SCALE * _get_context_size_scale()

func set_3d_context(bm_scene: UI_BrainMonitor_3DScene, region: BrainRegion) -> void:
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


## Use this component as the shared global top-bar strip.
func set_global_topbar_mode() -> void:
	_global_topbar_mode = true
	_bm_scene = null
	_cb_scene = null
	context_region = null
	_update_buttons_state()
	_on_theme_changed(theme)


## Allow host containers to force-enable/disable the strip uniformly.
func set_force_disabled(disabled: bool) -> void:
	_force_disabled_override = disabled
	_update_buttons_state()

## Enable or disable buttons based on whether a region is active.
func _update_buttons_state() -> void:
	if _global_topbar_mode:
		_set_all_buttons_disabled(_force_disabled_override)
		_set_visibility_for_context(false, true, false)
		_update_monitor_tools_visibility()
		return
	if context_region == null:
		_set_all_buttons_disabled(true)
		_set_visibility_for_context(false, false, false)
		_update_monitor_tools_visibility()
		return
	# Listing is always enabled (direct-only; will be empty if none)
	_set_all_buttons_disabled(_force_disabled_override)
	# Root region shows Inputs/Outputs; non-root shows Interconnect/Memory
	var is_root := _is_root_region()
	_set_visibility_for_context(not is_root, is_root, not _is_3d_context)
	_update_monitor_tools_visibility()


## Toggle disabled state for every control in the combo strip.
func _set_all_buttons_disabled(disabled: bool) -> void:
	_btn_brain_regions_list.disabled = disabled
	_btn_brain_regions_add.disabled = disabled
	_btn_interconnect_list.disabled = disabled
	_btn_interconnect_add.disabled = disabled
	_btn_memory_list.disabled = disabled
	_btn_memory_add.disabled = disabled
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
	if _spacer_before_monitor_tools != null:
		_spacer_before_monitor_tools.visible = show_tools
	if _activity_visualization_dropdown != null:
		_activity_visualization_dropdown.visible = show_tools
	if _camera_animations_button != null:
		_camera_animations_button.visible = show_tools


func _on_monitor_activity_mode_changed(action: StringName, enabled: bool) -> void:
	if _bm_scene == null:
		return
	if action == ActivityVisualizationDropDown.ACTION_GLOBAL_NEURAL_CONNECTIONS:
		_toggle_global_neural_connections_for_scene(_bm_scene, enabled)
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
			cortical_area_obj.set_hover_over_volume_state(true, true)
		else:
			cortical_area_obj.set_hover_over_volume_state(false, false)


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
	if _global_topbar_mode:
		BV.WM.spawn_select_region_template()
		return
	if context_region == null:
		return
	BV.WM.spawn_select_region_template(context_region)

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
	if _global_topbar_mode:
		BV.WM.spawn_create_cortical_with_type(AbstractCorticalArea.CORTICAL_AREA_TYPE.CUSTOM)
		return
	if context_region == null:
		return
	print("BrainObjectsCombo: Opening create interconnect window for region:", context_region.region_ID)
	BV.WM.spawn_create_cortical_with_type_for_region(context_region, AbstractCorticalArea.CORTICAL_AREA_TYPE.CUSTOM)

func _add_memory_area() -> void:
	if _global_topbar_mode:
		BV.WM.spawn_create_cortical_with_type(AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY)
		return
	if context_region == null:
		return
	print("BrainObjectsCombo: Opening create memory window for region:", context_region.region_ID)
	BV.WM.spawn_create_cortical_with_type_for_region(context_region, AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY)

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
		"Rearrange Circuit Builder",
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
	var root_region: BrainRegion = FeagiCore.feagi_local_cache.brain_regions.get_root_region()
	return root_region != null and root_region == context_region

func _set_visibility_for_context(show_interconnect_and_memory: bool, show_inputs_and_outputs: bool, show_rearrange_layout: bool) -> void:
	# Circuits always visible
	if _btn_brain_regions_list:
		_btn_brain_regions_list.visible = true
	if _btn_brain_regions_add:
		_btn_brain_regions_add.visible = true
	# Interconnect/Memory visibility
	if _btn_interconnect_list:
		_btn_interconnect_list.visible = show_interconnect_and_memory
	if _btn_interconnect_add:
		_btn_interconnect_add.visible = show_interconnect_and_memory
	if _btn_memory_list:
		_btn_memory_list.visible = show_interconnect_and_memory
	if _btn_memory_add:
		_btn_memory_add.visible = show_interconnect_and_memory
	if _btn_rearrange_layout:
		_btn_rearrange_layout.visible = show_rearrange_layout
	# Inputs/Outputs visibility
	if _btn_inputs_list:
		_btn_inputs_list.visible = show_inputs_and_outputs
	if _btn_inputs_add:
		_btn_inputs_add.visible = show_inputs_and_outputs
	if _btn_outputs_list:
		_btn_outputs_list.visible = show_inputs_and_outputs
	if _btn_outputs_add:
		_btn_outputs_add.visible = show_inputs_and_outputs
	# Main-row internal spacers must track root/non-root visibility too.
	if _spacer_after_add_circuits:
		_spacer_after_add_circuits.visible = show_inputs_and_outputs
	if _spacer_after_add_inputs:
		_spacer_after_add_inputs.visible = show_inputs_and_outputs
	# Group wrappers and spacers must follow visibility to avoid orphan horizontal gaps.
	if _group_interconnect:
		_group_interconnect.visible = show_interconnect_and_memory
	if _group_memory:
		_group_memory.visible = show_interconnect_and_memory
	if _group_rearrange:
		_group_rearrange.visible = show_rearrange_layout
	if _spacer_after_main:
		_spacer_after_main.visible = show_interconnect_and_memory
	if _spacer_after_interconnect:
		_spacer_after_interconnect.visible = show_interconnect_and_memory
	if _spacer_before_rearrange:
		_spacer_before_rearrange.visible = show_rearrange_layout
	if _spacer_after_rearrange:
		_spacer_after_rearrange.visible = show_rearrange_layout

func _apply_hover_visual(button: Control, hovered: bool) -> void:
	# Subtle scale-up on hover to match main 3D view visual feedback style
	button.scale = HOVER_SCALE if hovered else NORMAL_SCALE

## Create and attach the reusable list popup if needed.
func _ensure_list_popup() -> void:
	if _list_popup != null:
		return
	_list_popup = PREFAB_FILTERABLE_LIST_POPUP.instantiate()
	add_child(_list_popup)

## Open the dropdown with the provided items.
func _open_dropdown_for_items(anchor_button: Control, items: Array[Dictionary], placeholder_text: String, selection_handler: Callable) -> void:
	_ensure_list_popup()
	_list_popup.open_with_items(anchor_button, items, selection_handler, placeholder_text)

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
	# Draw a stable, neutral back plate behind combo groups.
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
