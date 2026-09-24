extends HBoxContainer
class_name BrainObjectsCombo

## Ordered Elements menu rows. Append a new id here when adding a combo
## and place the matching combo button under %MenuItems.
const CONNECTOME_MENU_ITEM_CIRCUIT: StringName = &"circuit"
const CONNECTOME_MENU_ITEM_INTERCONNECT: StringName = &"interconnect"
const CONNECTOME_MENU_ITEM_MEMORY: StringName = &"memory"

var context_region: BrainRegion = null

var _is_3d_context: bool = true
var _bm_scene: UI_BrainMonitor_3DScene = null
var _cb_scene: CircuitBuilder = null
var _global_topbar_mode: bool = false
var _force_disabled_override: bool = false

var _btn_connectome: BasePanelContainerButton
var _connectome_label: Label
var _connectome_hover_wired: bool = false
var _elements_menu_close_timer: Timer = null
var _connectome_menu: PopupPanel
var _connectome_menu_items: VBoxContainer
var _btn_brain_regions_list: TextureButton
var _circuits_title: Control
var _btn_brain_regions_add: TextureButton
var _btn_interconnect_list: TextureButton
var _interconnect_title: Control
var _btn_interconnect_add: TextureButton
var _btn_memory_list: TextureButton
var _memory_title: Control
var _btn_memory_add: TextureButton
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
## Fill of inspectors_S.jpg / camera_S.jpg so Elements matches those icon buttons.
const ICON_BUTTON_PLATE_COLOR := Color8(67, 67, 67)
## Horizontal inset so "Elements" is not flush against the plate.
const CONNECTOME_PLATE_PAD_X: int = 12
## In-place text pop. Scale avoids a layout resize that cancels hover.
const CONNECTOME_HOVER_SCALE: float = 1.1
## Overlap so the pointer can move from Elements into the menu without a gap.
const ELEMENTS_MENU_ANCHOR_OVERLAP_PX: int = 4
## Grace period while the pointer crosses from the button into the menu.
const ELEMENTS_MENU_HOVER_CLOSE_DELAY_SEC: float = 0.15
## Same overlay stacking as CircuitBuilder.tscn so tab chrome stays above the view.
const TAB_OVERLAY_Z_INDEX: int = 10
## Expander between list and + on a hamburger row. Ignores mouse so the plate is not a button.
const COMBO_ROW_GAP_NAME: StringName = &"RowGap"
const PREFAB_FILTERABLE_LIST_POPUP: PackedScene = preload("res://BrainVisualizer/UI/GenericElements/DropDown/FilterableListPopup.tscn")
const COMBO_STYLER = preload("res://BrainVisualizer/UI/GenericElements/Buttons/ComboButtonStripStyler.gd")
const CUSTOM_TOOLTIP_TRIGGER_SCRIPT = preload("res://BrainVisualizer/UI/GenericElements/CustomTooltip/CustomTooltipTrigger.gd")
const REARRANGE_SIZE_SCALE: float = 1.0
## Circuit Builder and Brain Monitor strips use the UI theme two steps below the root bar.
const TAB_STRIP_SCALE_STEPS_SMALLER: int = 2

var _list_popup: FilterableListPopup
var _circuits_row: PanelContainer
var _interconnect_row: PanelContainer
var _memory_row: PanelContainer
var _inputs_row: PanelContainer
var _outputs_row: PanelContainer
var _root_hover_list_anchor: Control = null
var _root_open_list_id: StringName = &""
var _root_list_hover_close_timer: Timer = null
const ROOT_LIST_CIRCUITS: StringName = &"circuits"
const ROOT_LIST_INTERCONNECT: StringName = &"interconnect"
const ROOT_LIST_MEMORY: StringName = &"memory"
const ROOT_LIST_INPUTS: StringName = &"inputs"
const ROOT_LIST_OUTPUTS: StringName = &"outputs"
const ROOT_LIST_CONNECTIVITY_RULES: StringName = &"connectivity_rules"
const TAB_ROW_SPACER_AFTER_CIRCUITS: StringName = &"Spacer_AfterCircuitsRow"
const TAB_ROW_SPACER_AFTER_INTERCONNECT: StringName = &"Spacer_AfterInterconnectRow"
## True after [method apply_custom_topbar_tooltips] succeeded for this instance (TopBar or tab host).
var _hosted_styled_tooltips_applied: bool = false

## Ordered ids for the Elements menu rows.
static func connectome_menu_item_ids() -> PackedStringArray:
	return PackedStringArray([
		String(CONNECTOME_MENU_ITEM_CIRCUIT),
		String(CONNECTOME_MENU_ITEM_INTERCONNECT),
		String(CONNECTOME_MENU_ITEM_MEMORY),
	])


## Hover scale is a fixed factor. Never multiply the current scale again.
static func connectome_hover_scale(hovered: bool) -> float:
	return CONNECTOME_HOVER_SCALE if hovered else 1.0


## The Elements dropdown is not used. Category chips sit on the strip.
static func should_open_elements_menu_on_hover(_global_topbar_mode: bool, _button_disabled: bool) -> bool:
	return false


## List icons are not used. Hovering the title opens the list.
static func should_show_category_list_button() -> bool:
	return false


## Circuit Builder and Brain Monitor show Circuits, Interconnect Areas, and Memory Areas on the strip.
static func should_show_tab_category_rows_on_strip(global_topbar_mode: bool) -> bool:
	return not global_topbar_mode


## Move [param node] under [param host].
## Adding a node directly onto its current owner makes that owner inconsistent, and later % lookups fail.
static func reparent_under_host(host: Node, node: Node) -> void:
	if node == null or host == null or node.get_parent() == host:
		return
	var keep_unique := node.unique_name_in_owner
	var parent := node.get_parent()
	if parent != null:
		parent.remove_child(node)
	node.owner = null
	host.add_child(node)
	if keep_unique:
		node.owner = host
		node.unique_name_in_owner = true


## Title hover opens the category list on the root bar and on tab bars.
static func should_open_category_list_on_title_hover(strip_disabled: bool) -> bool:
	return not strip_disabled


const CORTICAL_FOCUS_MONITOR: StringName = &"monitor"
const CORTICAL_FOCUS_BUILDER: StringName = &"builder"
const CORTICAL_FOCUS_NONE: StringName = &"none"


## Which view receives a list click. Bound tab scenes win. The root bar uses the view that shows the area.
static func cortical_list_focus_target(
	has_bound_monitor: bool,
	has_bound_builder: bool,
	active_monitor_has_area: bool,
	has_active_builder: bool,
	visible_monitor_has_area: bool
) -> StringName:
	if has_bound_monitor:
		return CORTICAL_FOCUS_MONITOR
	if has_bound_builder:
		return CORTICAL_FOCUS_BUILDER
	if active_monitor_has_area:
		return CORTICAL_FOCUS_MONITOR
	if has_active_builder:
		return CORTICAL_FOCUS_BUILDER
	if visible_monitor_has_area:
		return CORTICAL_FOCUS_MONITOR
	return CORTICAL_FOCUS_NONE


## Theme step two sizes below [param current_scale]. Stays on the smallest theme when already there.
static func scale_steps_below(scales: Array, current_scale: float, steps: int) -> float:
	var index := -1
	for i in range(scales.size()):
		if abs(float(scales[i]) - current_scale) < 0.0001:
			index = i
			break
	if index < 0:
		push_error("UI scale %s is not in the theme scale list" % current_scale)
		return current_scale
	return float(scales[maxi(0, index - steps)])


## Scene node names under %MenuItems, same order as [method connectome_menu_item_ids].
static func connectome_menu_row_node_names() -> PackedStringArray:
	return PackedStringArray([
		"BrainRegionsRow",
		"InterconnectAreasRow",
		"MemoryAreasRow",
	])


## Wire the combo buttons and dropdown popup.
func _ready() -> void:
	_group_connectome = %ConnectomeGroup
	_btn_connectome = %ConnectomeButton
	_connectome_label = %ConnectomeButton/HBoxContainer/Label as Label
	_connectome_menu = %ConnectomeMenu
	_connectome_menu_items = %MenuItems
	_btn_brain_regions_list = %TextureButton_BrainRegionsList
	_circuits_row = %BrainRegionsRow
	_interconnect_row = %InterconnectAreasRow
	_memory_row = %MemoryAreasRow
	_inputs_row = %InputsRow
	_outputs_row = %OutputsRow
	_circuits_title = _circuits_row.get_node("HBoxContainer/BrainRegionsList") as Control
	_btn_brain_regions_add = %TextureButton_BrainRegions
	_btn_interconnect_list = %TextureButton_InterconnectList
	_interconnect_title = _interconnect_row.get_node("HBoxContainer/InterconnectAreasList") as Control
	_btn_interconnect_add = %TextureButton_Interconnect
	_btn_memory_list = %TextureButton_MemoryList
	_memory_title = _memory_row.get_node("HBoxContainer/MemoryAreasList") as Control
	_btn_memory_add = %TextureButton_Memory
	_btn_rearrange_layout = $RearrangePanel/MarginContainer/TextureButton_Rearrange
	_btn_inputs_list = %InputsList
	_btn_inputs_add = %TextureButton_Inputs
	_btn_outputs_list = %OutputsList
	_btn_outputs_add = %TextureButton_Outputs
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
	_btn_connectome.pressed.connect(_open_elements_menu_from_pointer)
	_btn_connectome.focus_exited.connect(_on_connectome_focus_exited)
	if not _connectome_menu.mouse_entered.is_connected(_cancel_elements_menu_close):
		_connectome_menu.mouse_entered.connect(_cancel_elements_menu_close)
	if not _connectome_menu.mouse_exited.is_connected(_schedule_elements_menu_close):
		_connectome_menu.mouse_exited.connect(_schedule_elements_menu_close)
	_btn_brain_regions_list.pressed.connect(_open_brain_regions)
	_btn_brain_regions_add.pressed.connect(_add_brain_region)
	_wire_root_category_title_hover()
	_btn_interconnect_list.pressed.connect(_open_interconnect_areas)
	_btn_interconnect_add.pressed.connect(_add_interconnect_area)
	_btn_memory_list.pressed.connect(_open_memory_areas)
	_btn_memory_add.pressed.connect(_add_memory_area)
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
	_btn_connectome.tooltip_text = "Circuits, areas, and memory"
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
		[_btn_connectome, "Circuits, areas, and memory"],
		[_btn_brain_regions_list, "View all circuits"],
		[_btn_brain_regions_add, "Add a new circuit"],
		[_btn_interconnect_list, "View interconnect areas"],
		[_btn_interconnect_add, "Add interconnect area"],
		[_btn_memory_list, "View memory areas"],
		[_btn_memory_add, "Add memory area"],
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
	var proportion := _strip_proportion()
	var content_separation := int(round(float(COMBO_STYLER.INNER_CONTENT_SEPARATION) * proportion))
	_space_row_content(_circuits_row, "BrainRegionsList", content_separation)
	_space_row_content(_interconnect_row, "InterconnectAreasList", content_separation)
	_space_row_content(_memory_row, "MemoryAreasList", content_separation)
	_space_row_content(_inputs_row, "InputsList", content_separation)
	_space_row_content(_outputs_row, "OutputsList", content_separation)
	var plate_gap := int(round(float(COMBO_STYLER.COMBO_PLATE_GAP) * proportion))
	var pad_x := int(round(float(COMBO_STYLER.ROW_PAD_X) * proportion))
	var pad_y := int(round(float(COMBO_STYLER.ROW_PAD_Y) * proportion))
	COMBO_STYLER.apply_list_hbox_spacing(self, list_hbox_paths, content_separation)
	add_theme_constant_override("separation", 0)
	var buttons_row := $MainGroup/MarginContainer/ButtonsRow as HBoxContainer
	if buttons_row != null:
		buttons_row.add_theme_constant_override("separation", 0)
	var plate_gap_paths := [
		NodePath("Spacer_AfterConnectome"),
		NodePath("MainGroup/MarginContainer/ButtonsRow/Spacer_AfterAddInputs"),
		NodePath("Spacer_BeforeRearrange"),
		NodePath("Spacer_BeforeMonitorTools"),
		NodePath(String(TAB_ROW_SPACER_AFTER_CIRCUITS)),
		NodePath(String(TAB_ROW_SPACER_AFTER_INTERCONNECT)),
	]
	COMBO_STYLER.apply_spacer_width(self, plate_gap_paths, plate_gap)
	if _spacer_after_rearrange != null:
		_spacer_after_rearrange.custom_minimum_size = Vector2.ZERO
	var combo_rows: Array[PanelContainer] = [
		_circuits_row,
		_interconnect_row,
		_memory_row,
		_inputs_row,
		_outputs_row,
	]
	for combo_row in combo_rows:
		COMBO_STYLER.apply_combo_row_plate_padding(combo_row, pad_x, pad_y)


## Space a category row from the row node, so it still works after the row leaves the Elements menu.
func _space_row_content(row: Node, list_name: String, separation: int) -> void:
	if row == null:
		return
	var boxes: Array[Node] = [
		row.get_node_or_null("HBoxContainer"),
		row.get_node_or_null("HBoxContainer/%s/HBoxContainer" % list_name),
	]
	for box in boxes:
		if box is HBoxContainer:
			(box as HBoxContainer).add_theme_constant_override("separation", separation)


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

func _on_theme_changed(_new_theme: Theme) -> void:
	var strip_theme := _theme_for_this_strip()
	theme = strip_theme
	if _connectome_menu != null:
		_connectome_menu.theme = strip_theme
	var button_size := _control_size_from_theme(strip_theme)
	_apply_uniform_control_size(self, button_size)
	if _connectome_menu != null:
		_apply_uniform_control_size(_connectome_menu, button_size)
	_apply_rearrange_button_size(button_size)
	_apply_shared_combo_spacing_tokens()
	_style_connectome_like_icon_buttons()


## Root bar uses the active theme. Tab bars use the theme two steps smaller.
func _theme_for_this_strip() -> Theme:
	var loaded: Theme = BV.UI.loaded_theme
	if _global_topbar_mode:
		return loaded
	var target_scale := scale_steps_below(BV.UI.possible_UI_scales, BV.UI.loaded_theme_scale.x, TAB_STRIP_SCALE_STEPS_SMALLER)
	if is_equal_approx(target_scale, BV.UI.loaded_theme_scale.x):
		return loaded
	var smaller: Theme = BV.UI.load_theme_resource(target_scale, UIManager.THEME_COLORS.DARK)
	if smaller == null:
		push_error("Tab strip could not load UI theme scale %s" % target_scale)
		return loaded
	return smaller


func _control_size_from_theme(source: Theme) -> Vector2:
	var element := COMBO_STYLER.TOP_BAR_CONTROL_THEME
	if source != null and source.has_constant("size_x", element) and source.has_constant("size_y", element):
		return Vector2(source.get_constant("size_x", element), source.get_constant("size_y", element))
	push_error("Theme is missing TextureButton_TopBar size")
	return Vector2(BV.UI.get_minimum_size_from_loaded_theme(element))


## 1.0 on the root bar. Tab bars shrink with the two-step-smaller theme.
func _strip_proportion() -> float:
	if _global_topbar_mode:
		return 1.0
	var loaded_width := float(BV.UI.get_minimum_size_from_loaded_theme(COMBO_STYLER.TOP_BAR_CONTROL_THEME).x)
	if loaded_width <= 0.0:
		push_error("Loaded top-bar control width is missing")
		return 1.0
	return _control_size_from_theme(_theme_for_this_strip()).x / loaded_width


## Buttons use TextureButton_TopBar from the loaded theme. Category icons are a fraction of that size.
func _apply_uniform_control_size(node: Node, theme_button_size: Vector2) -> void:
	for child in node.get_children():
		if child is TextureRect and bool(child.get_meta("category_icon", false)):
			var icon := child as Control
			var full_bleed := bool(child.get_meta("full_bleed_icon", false))
			icon.custom_minimum_size = COMBO_STYLER.category_icon_size(theme_button_size, full_bleed)
			icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		elif child is TextureButton:
			var button := child as TextureButton
			button.theme_type_variation = COMBO_STYLER.TOP_BAR_CONTROL_THEME
			button.custom_minimum_size = theme_button_size
			button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		elif child is TextureRect:
			(child as Control).custom_minimum_size = theme_button_size
		_apply_uniform_control_size(child, theme_button_size)

## Paint and size Elements like the inspector / camera icon buttons beside it.
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
	var connectome_hbox: Control = _btn_connectome.get_node_or_null("HBoxContainer") as Control
	if connectome_hbox != null:
		connectome_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	_open_elements_menu_from_pointer()


func _on_connectome_mouse_exited() -> void:
	_schedule_elements_menu_close()
	if _is_pointer_over_connectome_button():
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


## Make the rearrange button match the strip's TextureButton_TopBar size.
func _apply_rearrange_button_size(base_size: Vector2) -> void:
	if _btn_rearrange_layout == null:
		return
	_btn_rearrange_layout.theme_type_variation = COMBO_STYLER.TOP_BAR_CONTROL_THEME
	_btn_rearrange_layout.custom_minimum_size = base_size * REARRANGE_SIZE_SCALE

func set_3d_context(bm_scene: UI_BrainMonitor_3DScene, region: BrainRegion) -> void:
	if _is_3d_context and _bm_scene == bm_scene and context_region == region and not _global_topbar_mode:
		return
	if not _hosted_styled_tooltips_applied:
		_try_apply_styled_tooltips_for_current_host()
	_is_3d_context = true
	_global_topbar_mode = false
	_bm_scene = bm_scene
	context_region = region
	_place_category_rows_on_tab_strip()
	_update_buttons_state()
	_on_theme_changed(theme)

## Switch to 2D context and refresh listings.
func set_2d_context(cb_scene: CircuitBuilder, region: BrainRegion) -> void:
	_is_3d_context = false
	_global_topbar_mode = false
	_cb_scene = cb_scene
	context_region = region
	_place_category_rows_on_tab_strip()
	_update_buttons_state()
	_on_theme_changed(theme)
	if not _hosted_styled_tooltips_applied:
		_try_apply_styled_tooltips_for_current_host()


## Use this component as the shared global top-bar strip.
## Root bar is circuits + I/O. Tab bars list circuits, interconnect areas, and memory areas inline.
func set_global_topbar_mode() -> void:
	_global_topbar_mode = true
	_bm_scene = null
	_cb_scene = null
	context_region = null
	_place_circuits_on_topbar_strip()
	_update_buttons_state()
	_on_theme_changed(theme)


## Tab bars use the root-bar pattern: category chips on the strip, no Elements menu.
func _place_category_rows_on_tab_strip() -> void:
	if not should_show_tab_category_rows_on_strip(_global_topbar_mode):
		return
	var sequence: Array[Control] = [
		_circuits_row,
		_ensure_category_row_spacer(TAB_ROW_SPACER_AFTER_CIRCUITS),
		_interconnect_row,
		_ensure_category_row_spacer(TAB_ROW_SPACER_AFTER_INTERCONNECT),
		_memory_row,
	]
	for i in range(sequence.size()):
		var node := sequence[i]
		_reparent_onto_strip(node, i)
		if node is PanelContainer:
			node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			node.visible = true
	_hide_elements_controls()


func _reparent_onto_strip(node: Control, index: int) -> void:
	if node == null:
		return
	reparent_under_host(self, node)
	move_child(node, mini(index, get_child_count() - 1))


func _ensure_category_row_spacer(spacer_name: StringName) -> Control:
	var spacer := get_node_or_null(NodePath(String(spacer_name))) as Control
	if spacer == null:
		spacer = Control.new()
		spacer.name = spacer_name
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(spacer)
	spacer.size_flags_horizontal = 0
	var gap := int(round(float(COMBO_STYLER.COMBO_PLATE_GAP) * _strip_proportion()))
	spacer.custom_minimum_size = Vector2(gap, 0)
	return spacer


func _hide_elements_controls() -> void:
	if _group_connectome != null:
		_group_connectome.visible = false
	if _btn_connectome != null:
		_btn_connectome.visible = false
	_close_connectome_menu()


## Circuits sit on the main top bar strip. Interconnect and memory stay off that bar.
func _place_circuits_on_topbar_strip() -> void:
	var circuits_row: Control = _circuits_row
	if circuits_row == null or circuits_row.get_parent() == self:
		return
	reparent_under_host(self, circuits_row)
	move_child(circuits_row, 0)
	circuits_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	circuits_row.visible = true
	_hide_elements_controls()


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
	# Root region keeps Inputs/Outputs on the strip; elements stay in the menu.
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


## Category titles open their lists on hover on the root bar and on tab bars.
func _wire_root_category_title_hover() -> void:
	_wire_category_title(_circuits_title, ROOT_LIST_CIRCUITS, _open_brain_regions)
	_wire_category_title(_interconnect_title, ROOT_LIST_INTERCONNECT, _open_interconnect_areas)
	_wire_category_title(_memory_title, ROOT_LIST_MEMORY, _open_memory_areas)
	_btn_inputs_list.mouse_entered.connect(_on_root_category_title_entered.bind(_btn_inputs_list, ROOT_LIST_INPUTS, _open_inputs))
	_btn_inputs_list.mouse_exited.connect(_on_root_category_title_exited.bind(_btn_inputs_list))
	_btn_outputs_list.mouse_entered.connect(_on_root_category_title_entered.bind(_btn_outputs_list, ROOT_LIST_OUTPUTS, _open_outputs))
	_btn_outputs_list.mouse_exited.connect(_on_root_category_title_exited.bind(_btn_outputs_list))


## Root-bar controls outside this strip, such as Connectivity Rules, use the same hover list.
func attach_category_list_hover(title: Control, list_id: StringName, opener: Callable) -> void:
	_wire_category_title(title, list_id, opener)


## Open the shared filter list under [param anchor].
func open_category_list(anchor: Control, items: Array[Dictionary], placeholder_text: String, selection_handler: Callable) -> void:
	_open_dropdown_for_items(anchor, items, placeholder_text, selection_handler)


func _wire_category_title(title: Control, list_id: StringName, opener: Callable) -> void:
	if title == null:
		return
	title.mouse_entered.connect(_on_root_category_title_entered.bind(title, list_id, opener))
	title.mouse_exited.connect(_on_root_category_title_exited.bind(title))
	title.gui_input.connect(_on_category_title_gui_input.bind(title, list_id, opener))


## Titles accept the pointer because the list icon is not shown.
func _apply_category_title_pointer() -> void:
	for title in [_circuits_title, _interconnect_title, _memory_title]:
		if title == null:
			continue
		title.mouse_filter = Control.MOUSE_FILTER_STOP
		title.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _category_strip_is_disabled() -> bool:
	if _force_disabled_override:
		return true
	return _btn_brain_regions_add != null and _btn_brain_regions_add.disabled


func _on_root_category_title_entered(title: Control, list_id: StringName, opener: Callable) -> void:
	if not should_open_category_list_on_title_hover(_category_strip_is_disabled()):
		return
	_root_hover_list_anchor = title
	_cancel_root_list_hover_close()
	_ensure_list_popup_hover_hooks()
	if _list_popup != null and _list_popup.visible and _root_open_list_id == list_id:
		return
	_root_open_list_id = list_id
	opener.call()


func _on_root_category_title_exited(title: Control) -> void:
	if _root_hover_list_anchor != title:
		return
	_schedule_root_list_hover_close()


## Click still opens a category list after the list icon is hidden.
func _on_category_title_gui_input(event: InputEvent, title: Control, list_id: StringName, opener: Callable) -> void:
	if not should_open_category_list_on_title_hover(_category_strip_is_disabled()):
		return
	if title == null or not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	_root_hover_list_anchor = title
	_root_open_list_id = list_id
	opener.call()
	title.accept_event()


func _ensure_list_popup_hover_hooks() -> void:
	_ensure_list_popup()
	if _list_popup.mouse_entered.is_connected(_cancel_root_list_hover_close):
		return
	_list_popup.mouse_entered.connect(_cancel_root_list_hover_close)
	_list_popup.mouse_exited.connect(_schedule_root_list_hover_close)


func _ensure_root_list_hover_close_timer() -> Timer:
	if _root_list_hover_close_timer != null:
		return _root_list_hover_close_timer
	var timer := Timer.new()
	timer.one_shot = true
	timer.timeout.connect(_close_root_list_if_pointer_left)
	add_child(timer)
	_root_list_hover_close_timer = timer
	return timer


func _schedule_root_list_hover_close() -> void:
	if _list_popup == null or not _list_popup.visible:
		return
	_ensure_root_list_hover_close_timer().start(ELEMENTS_MENU_HOVER_CLOSE_DELAY_SEC)


func _cancel_root_list_hover_close() -> void:
	if _root_list_hover_close_timer != null:
		_root_list_hover_close_timer.stop()


func _close_root_list_if_pointer_left() -> void:
	if _list_popup == null or not _list_popup.visible:
		return
	if _is_pointer_over_control(_root_hover_list_anchor) or _is_pointer_over_list_popup():
		return
	_list_popup.hide()
	_root_open_list_id = &""
	_root_hover_list_anchor = null


func _is_pointer_over_control(control: Control) -> bool:
	if control == null or not is_instance_valid(control):
		return false
	var vp := control.get_viewport()
	if vp == null:
		return false
	var hovered: Control = vp.gui_get_hovered_control()
	if hovered == null:
		return false
	return control == hovered or control.is_ancestor_of(hovered)


func _is_pointer_over_list_popup() -> bool:
	if _list_popup == null or not _list_popup.visible:
		return false
	var tree := get_tree()
	if tree != null and tree.root != null:
		var root_hovered: Control = tree.root.gui_get_hovered_control()
		if root_hovered != null and (_list_popup == root_hovered or _list_popup.is_ancestor_of(root_hovered)):
			return true
	return _list_popup.get_visible_rect().has_point(_list_popup.get_mouse_position())


## Open circuits dropdown for the current region.
func _open_brain_regions() -> void:
	if context_region == null and not _global_topbar_mode:
		return
	var items := _build_region_items()
	_open_dropdown_for_items(_circuits_title, items, "Filter circuits...", func(region: BrainRegion):
		_focus_region(region)
	)

func _add_brain_region() -> void:
	var anchor := _btn_brain_regions_add
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
	_open_dropdown_for_items(_interconnect_title, items, "Filter interconnect areas...", func(area: AbstractCorticalArea):
		_focus_cortical(area)
	)

## Open memory areas dropdown for the current region.
func _open_memory_areas() -> void:
	if context_region == null and not _global_topbar_mode:
		return
	var items := _build_cortical_items_for_types([AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY])
	_open_dropdown_for_items(_memory_title, items, "Filter memory areas...", func(area: AbstractCorticalArea):
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
	var anchor := _btn_interconnect_add
	if _global_topbar_mode:
		BV.WM.spawn_create_cortical_with_type(AbstractCorticalArea.CORTICAL_AREA_TYPE.CUSTOM, anchor)
		return
	if context_region == null:
		return
	print("BrainObjectsCombo: Opening create interconnect window for region:", context_region.region_ID)
	BV.WM.spawn_create_cortical_with_type_for_region(context_region, AbstractCorticalArea.CORTICAL_AREA_TYPE.CUSTOM, anchor)

func _add_memory_area() -> void:
	var anchor := _btn_memory_add
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
	_hide_elements_controls()
	var show_tab_categories := should_show_tab_category_rows_on_strip(_global_topbar_mode)
	if _interconnect_row != null:
		_interconnect_row.visible = show_tab_categories
	if _memory_row != null:
		_memory_row.visible = show_tab_categories
	if _btn_brain_regions_list:
		_btn_brain_regions_list.visible = should_show_category_list_button()
	if _btn_interconnect_list:
		_btn_interconnect_list.visible = should_show_category_list_button()
	if _btn_memory_list:
		_btn_memory_list.visible = should_show_category_list_button()
	_apply_category_title_pointer()
	if _btn_brain_regions_add:
		_btn_brain_regions_add.visible = true
	if _btn_interconnect_add:
		_btn_interconnect_add.visible = true
	if _btn_memory_add:
		_btn_memory_add.visible = true
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
		_spacer_before_rearrange.visible = show_rearrange_layout
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


## Stretch each Elements row to the menu width. The title stays icon+text.
## The gap absorbs leftover space so the list button and + sit at the right edge.
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
			if hbox_child is TextureButton:
				(hbox_child as TextureButton).size_flags_horizontal = Control.SIZE_SHRINK_END
			elif hbox_child.name == String(COMBO_ROW_GAP_NAME):
				var gap: Control = hbox_child as Control
				gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			else:
				var list_btn: Control = hbox_child as Control
				list_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
				_shrink_combo_list_labels(list_btn)


## List labels must not expand-fill. That used to put the text hit box under +.
static func _shrink_combo_list_labels(node: Node) -> void:
	if node is Label:
		(node as Label).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	for child in node.get_children():
		_shrink_combo_list_labels(child)


## Menu-row buttons must not steal focus or the hamburger closes before the click lands.
func _set_connectome_menu_row_focus_none() -> void:
	var rows: Array[Control] = [
		_btn_brain_regions_list,
		_btn_brain_regions_add,
		_btn_interconnect_list,
		_btn_interconnect_add,
		_btn_memory_list,
		_btn_memory_add,
	]
	for row in rows:
		if row != null:
			row.focus_mode = Control.FOCUS_NONE


## True while the Elements menu popup is visible.
func is_connectome_menu_open() -> bool:
	return _connectome_menu != null and _connectome_menu.visible


## Open the Elements menu from a hover or click on the Circuit Builder / Brain Monitor tab strip.
func _open_elements_menu_from_pointer() -> void:
	if _btn_connectome == null:
		return
	if not should_open_elements_menu_on_hover(_global_topbar_mode, _btn_connectome.disabled):
		return
	_cancel_elements_menu_close()
	if is_connectome_menu_open():
		return
	_open_connectome_menu()


func _ensure_elements_menu_close_timer() -> Timer:
	if _elements_menu_close_timer != null:
		return _elements_menu_close_timer
	var timer := Timer.new()
	timer.one_shot = true
	timer.timeout.connect(_close_elements_menu_if_pointer_left)
	add_child(timer)
	_elements_menu_close_timer = timer
	return timer


func _schedule_elements_menu_close() -> void:
	if not is_connectome_menu_open():
		return
	_ensure_elements_menu_close_timer().start(ELEMENTS_MENU_HOVER_CLOSE_DELAY_SEC)


func _cancel_elements_menu_close() -> void:
	if _elements_menu_close_timer != null:
		_elements_menu_close_timer.stop()


func _close_elements_menu_if_pointer_left() -> void:
	if not is_connectome_menu_open():
		return
	if should_keep_connectome_menu_open_after_focus_lost(_is_pointer_over_connectome_menu(), _is_pointer_over_connectome_button()):
		return
	_close_connectome_menu()
	if not _is_pointer_over_connectome_button():
		_reset_connectome_label_hover()


func _open_connectome_menu() -> void:
	if _connectome_menu == null or _btn_connectome == null:
		return
	if BV.UI:
		_connectome_menu.theme = BV.UI.loaded_theme
	_reparent_connectome_menu_to_root_viewport()
	align_connectome_menu_add_buttons(_connectome_menu_items)
	_connectome_menu.size = Vector2.ZERO
	var anchor_screen := _get_connectome_anchor_screen_position()
	var menu_y: float = _btn_connectome.size.y - float(ELEMENTS_MENU_ANCHOR_OVERLAP_PX)
	_connectome_menu.position = Vector2i(anchor_screen + Vector2(0, menu_y))
	_connectome_menu.popup()


func _close_connectome_menu() -> void:
	if _connectome_menu == null:
		return
	_connectome_menu.hide()


## Keep the hamburger open when focus moves to the popup Window, but the
## pointer is still on the trigger (Brain Monitor: button lives in a SubViewport).
static func should_keep_connectome_menu_open_after_focus_lost(pointer_over_menu: bool, pointer_over_button: bool) -> bool:
	return pointer_over_menu or pointer_over_button


## Close the hamburger when the trigger loses focus, unless the click stayed in the menu.
func _on_connectome_focus_exited() -> void:
	call_deferred("_close_connectome_menu_if_focus_lost")


func _close_connectome_menu_if_focus_lost() -> void:
	if not is_connectome_menu_open():
		return
	if should_keep_connectome_menu_open_after_focus_lost(_is_pointer_over_connectome_menu(), _is_pointer_over_connectome_button()):
		return
	_close_connectome_menu()


## True when the Elements trigger owns the pointer in its own viewport.
func _is_pointer_over_connectome_button() -> bool:
	if _btn_connectome == null:
		return false
	var vp := _btn_connectome.get_viewport()
	if vp == null:
		return false
	var hovered: Control = vp.gui_get_hovered_control()
	if hovered == null:
		return false
	return _btn_connectome == hovered or _btn_connectome.is_ancestor_of(hovered)


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


## After the menu closes, spawn list/create UI from the still-visible Elements button.
func _connectome_action_anchor() -> Control:
	_close_connectome_menu()
	return _btn_connectome


## Open the dropdown with the provided items.
func _open_dropdown_for_items(anchor_button: Control, items: Array[Dictionary], placeholder_text: String, selection_handler: Callable) -> void:
	var anchor := anchor_button
	if is_connectome_menu_open() or _is_connectome_menu_row(anchor_button):
		anchor = _connectome_action_anchor()
	_ensure_list_popup()
	_ensure_list_popup_hover_hooks()
	_list_popup.open_with_items(anchor, items, selection_handler, placeholder_text, ELEMENTS_MENU_ANCHOR_OVERLAP_PX)


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
	# Main top bar keeps a shared plate. Tab combos must not, or Elements
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

func _focus_cortical(area: AbstractCorticalArea) -> void:
	if area == null:
		return
	var cortical_id := String(area.cortical_ID)
	var active_bm := BV.UI.get_brain_monitor_for_active_tab()
	var active_cb := BV.UI.get_circuit_builder_for_active_tab()
	var visible_bm := BV.UI.find_visible_brain_monitor_with_cortical_area(cortical_id)
	var target := cortical_list_focus_target(
		_bm_scene != null,
		_cb_scene != null,
		active_bm != null and active_bm.has_cortical_area_visualization(cortical_id),
		active_cb != null,
		visible_bm != null
	)
	if target == CORTICAL_FOCUS_MONITOR:
		var monitor := _bm_scene
		if monitor == null and active_bm != null and active_bm.has_cortical_area_visualization(cortical_id):
			monitor = active_bm
		if monitor == null:
			monitor = visible_bm
		_focus_cortical_on_monitor(monitor, area)
		return
	if target == CORTICAL_FOCUS_BUILDER:
		var builder := _cb_scene if _cb_scene != null else active_cb
		if builder != null:
			builder.focus_on_cortical_area(area)


func _focus_cortical_on_monitor(monitor: UI_BrainMonitor_3DScene, area: AbstractCorticalArea) -> void:
	if monitor == null or monitor.get_pancake_camera() == null:
		return
	monitor.focus_on_cortical_area(area)
	monitor.flash_indicator_for_cortical_area(area)


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
