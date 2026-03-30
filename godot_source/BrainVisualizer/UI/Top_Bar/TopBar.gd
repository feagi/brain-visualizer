extends HBoxContainer
class_name TopBar

@export var starting_size_index: int = 3
@export var theme_scalar_nodes_to_not_include_or_search: Array[Node] = []

signal request_UI_mode(mode: TempSplit.STATES)

var _theme_custom_scaler: ScaleThemeApplier = ScaleThemeApplier.new()
var _refresh_rate_field: FloatInput # bburst engine
var _index_scale: int

var _neuron_count: TextInput
var _synapse_count: TextInput
const COMBO_STYLER = preload("res://BrainVisualizer/UI/GenericElements/Buttons/ComboButtonStripStyler.gd")
const PREFAB_BRAIN_OBJECTS_COMBO: PackedScene = preload("res://BrainVisualizer/UI/GenericElements/BrainObjectsCombo/BrainObjectsCombo.tscn")
var _shared_combo: BrainObjectsCombo = null

var _increase_scale_button: TextureButton
var _decrease_scale_button: TextureButton
var _activity_visualization_dropdown: ActivityVisualizationDropDown
const PREFAB_FILTERABLE_LIST_POPUP: PackedScene = preload("res://BrainVisualizer/UI/GenericElements/DropDown/FilterableListPopup.tscn")
var _list_popup: FilterableListPopup


func _ready():
	# references
	_refresh_rate_field = $DetailsPanel/MarginContainer/Details/Place_child_nodes_here/HBoxContainer/RR_Float
	_index_scale = starting_size_index
	
	_increase_scale_button = $ChangeSize/MarginContainer/HBoxContainer/Bigger
	_decrease_scale_button = $ChangeSize/MarginContainer/HBoxContainer/Smaller
	
	_activity_visualization_dropdown = $TopBarControlsPanel/MarginContainer/HBoxContainer/ActivityVisualizationDropDown
	BV.UI.brain_monitor_activity_mode = UIManager.BRAIN_MONITOR_ACTIVITY_MODE.GLOBAL_NEURAL_CONNECTIONS
	
	_neuron_count = $DetailsPanel/MarginContainer/Details/Place_child_nodes_here/HBoxContainer2/neuron
	_synapse_count = $DetailsPanel/MarginContainer/Details/Place_child_nodes_here/HBoxContainer3/synapse
	_mount_shared_combo_strip()
	_apply_shared_combo_spacing_tokens()
	
	# FEAGI data
	# Burst rate
	_refresh_rate_field.float_confirmed.connect(_user_on_burst_delay_change)
	FeagiCore.delay_between_bursts_updated.connect(_FEAGI_on_burst_delay_change)
	_FEAGI_on_burst_delay_change(FeagiCore.delay_between_bursts)
	
	## Count Limits
	FeagiCore.feagi_local_cache.neuron_count_current_changed.connect(_update_neuron_count_current)
	FeagiCore.feagi_local_cache.synapse_count_current_changed.connect(_update_synapse_count_current)

	_theme_custom_scaler.setup(self, theme_scalar_nodes_to_not_include_or_search, BV.UI.loaded_theme)
	BV.UI.theme_changed.connect(_theme_updated)
	_theme_updated(BV.UI.loaded_theme)
	FeagiCore.about_to_reload_genome.connect(_on_genome_about_to_reload)
	toggle_buttons_interactability(false)


## Apply shared spacing tokens to keep top bar combo strips consistent with Circuit Builder.
func _apply_shared_combo_spacing_tokens() -> void:
	var list_hbox_paths := []
	list_hbox_paths.append(NodePath("Buttons/MarginContainer/HBoxContainer/HBoxContainer/BrainRegionsList/HBoxContainer"))
	list_hbox_paths.append(NodePath("Buttons/MarginContainer/HBoxContainer/HBoxContainer/InputsList/HBoxContainer"))
	list_hbox_paths.append(NodePath("Buttons/MarginContainer/HBoxContainer/HBoxContainer/OutputsList/HBoxContainer"))
	list_hbox_paths.append(NodePath("Buttons/MarginContainer/HBoxContainer/HBoxContainer3/BrainAreasList/HBoxContainer"))
	COMBO_STYLER.apply_list_hbox_spacing(self, list_hbox_paths)
	var spacer_paths := []
	spacer_paths.append(NodePath("Buttons/MarginContainer/HBoxContainer/HBoxContainer/Spacer_AfterAddCircuits"))
	spacer_paths.append(NodePath("Buttons/MarginContainer/HBoxContainer/HBoxContainer/Spacer_AfterAddInputs"))
	spacer_paths.append(NodePath("Buttons/MarginContainer/HBoxContainer/HBoxContainer/Spacer_AfterAddOutputs"))
	spacer_paths.append(NodePath("Buttons/MarginContainer/HBoxContainer/HBoxContainer3/Spacer_AfterAddBrainAreas"))
	COMBO_STYLER.apply_spacer_width(self, spacer_paths)


## Mount the shared combo implementation used across Circuit Builder and Brain Monitor.
func _mount_shared_combo_strip() -> void:
	var root_row := $Buttons/MarginContainer/HBoxContainer
	var legacy_strip := $Buttons/MarginContainer/HBoxContainer/HBoxContainer
	legacy_strip.visible = false
	legacy_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _shared_combo == null:
		_shared_combo = PREFAB_BRAIN_OBJECTS_COMBO.instantiate() as BrainObjectsCombo
		_shared_combo.name = "SharedBrainObjectsCombo"
		root_row.add_child(_shared_combo)
		root_row.move_child(_shared_combo, 0)
	_shared_combo.set_global_topbar_mode()


## Toggle button interactability of top bar (ignoring those that are not relevant to FEAGI directly)
func toggle_buttons_interactability(pressable: bool) -> void:
	if _refresh_rate_field == null:
		push_error("Too early to call for toggle_buttons_interactability! Skipping!")
		return
	print("TOPBAR: Setting pressability to %s" % pressable)
	_refresh_rate_field.editable = pressable
	$Buttons/MarginContainer/HBoxContainer/HBoxContainer/BrainRegionsList.disabled = !pressable
	$Buttons/MarginContainer/HBoxContainer/HBoxContainer/TextureButton_BrainRegions.disabled = !pressable
	$Buttons/MarginContainer/HBoxContainer/HBoxContainer/InputsList.disabled = !pressable
	$Buttons/MarginContainer/HBoxContainer/HBoxContainer/TextureButton_Inputs.disabled = !pressable
	$Buttons/MarginContainer/HBoxContainer/HBoxContainer/OutputsList.disabled = !pressable
	$Buttons/MarginContainer/HBoxContainer/HBoxContainer/TextureButton_Outputs.disabled = !pressable
	if _shared_combo != null:
		_shared_combo.set_force_disabled(!pressable)
	
	

func _set_scale(index_movement: int) -> void:
	_index_scale += index_movement
	_index_scale = mini(_index_scale, len(BV.UI.possible_UI_scales) - 1)
	_index_scale = maxi(_index_scale, 0)
	_increase_scale_button.disabled =  _index_scale == len(BV.UI.possible_UI_scales) - 1
	_decrease_scale_button.disabled =  _index_scale == 0
	print("Topbar requesting scale change to " + str(BV.UI.possible_UI_scales[_index_scale]))
	BV.UI.request_switch_to_theme(BV.UI.possible_UI_scales[_index_scale], UIManager.THEME_COLORS.DARK)



func _FEAGI_on_burst_delay_change(new_delay_between_bursts_seconds: float) -> void:
	print("🔥 TOPBAR: FEAGI updated delay to %s seconds" % new_delay_between_bursts_seconds)
	
	# Don't disable the field based on FEAGI data - let the genome state control editability
	# _refresh_rate_field.editable = new_delay_between_bursts_seconds != 0.0
	
	if new_delay_between_bursts_seconds == 0.0:
		print("🔥 TOPBAR: FEAGI sent 0.0 delay - setting display to 0.0 Hz")
		_refresh_rate_field.current_float = 0.0
		return
	
	var frequency_hz = 1.0 / new_delay_between_bursts_seconds
	print("🔥 TOPBAR: Converting %s seconds delay to %s Hz display" % [new_delay_between_bursts_seconds, frequency_hz])
	_refresh_rate_field.current_float = frequency_hz

func _user_on_burst_delay_change(new_refresh_rate_hz: float) -> void:
	print("🔥 TOPBAR: User changed refresh rate to %s Hz" % new_refresh_rate_hz)
	
	if new_refresh_rate_hz <= 0.0:
		print("🔥 TOPBAR: Invalid refresh rate (<= 0), resetting to current value")
		_refresh_rate_field.current_float = 1.0 / FeagiCore.delay_between_bursts
		return
	
	# Convert frequency (Hz) to delay (seconds) and send to FEAGI
	var delay_seconds = 1.0 / new_refresh_rate_hz
	print("🔥 TOPBAR: Converting %s Hz to %s seconds delay, calling API..." % [new_refresh_rate_hz, delay_seconds])
	
	# Check if FeagiCore.requests is available
	if not FeagiCore or not FeagiCore.requests:
		print("🔥 TOPBAR: ERROR - FeagiCore.requests not available!")
		return
		
	FeagiCore.requests.update_burst_delay(delay_seconds)


func _view_selected(new_state: TempSplit.STATES) -> void:
	request_UI_mode.emit(new_state)

func _open_inputs() -> void:
	var items := _build_topbar_cortical_items(AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU)
	_open_dropdown_for_items($Buttons/MarginContainer/HBoxContainer/HBoxContainer/InputsList, items, "Filter inputs...", func(area: AbstractCorticalArea):
		_focus_cortical_from_topbar(area)
	)

func _open_create_input() -> void:
	if _shared_combo != null:
		BV.WM.spawn_create_cortical_with_type(AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU, _shared_combo.get_inputs_add_button())
		return
	BV.WM.spawn_create_cortical_with_type(AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU)

func _open_brain_regions() -> void:
	var items := _build_topbar_region_items()
	_open_dropdown_for_items($Buttons/MarginContainer/HBoxContainer/HBoxContainer/BrainRegionsList, items, "Filter circuits...", func(region: BrainRegion):
		_focus_region_from_topbar(region)
	)

func _open_create_brain_region() -> void:
	# Open circuit selection window (first tile opens Create Brain Region).
	BV.WM.spawn_select_region_template()

#VisConfig.UI_manager.window_manager.spawn_create_cortical()

func _open_outputs() -> void:
	var items := _build_topbar_cortical_items(AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU)
	_open_dropdown_for_items($Buttons/MarginContainer/HBoxContainer/HBoxContainer/OutputsList, items, "Filter outputs...", func(area: AbstractCorticalArea):
		_focus_cortical_from_topbar(area)
	)

func _open_create_output() -> void:
	if _shared_combo != null:
		BV.WM.spawn_create_cortical_with_type(AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU, _shared_combo.get_outputs_add_button())
		return
	BV.WM.spawn_create_cortical_with_type(AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU)

func _open_neuron_morphologies() -> void:
	BV.WM.spawn_manager_morphology()

func _open_create_morpology() -> void:
	BV.WM.spawn_create_morphology()

func _open_options() -> void:
	BV.WM.spawn_options()

func _open_camera_animations() -> void:
	BV.WM.spawn_camera_animations()

func _open_guide() -> void:
	BV.WM.spawn_guide()

#func _FEAGI_retireved_latency(latency_ms: int) -> void:
#	_latency_field.current_int = latency_ms

func _smaller_scale() -> void:
	_set_scale(-1)
	
func _bigger_scale() -> void:
	_set_scale(1)

func _preview_button_pressed() -> void:
	BV.WM.spawn_view_previews()

func _on_activity_visualization_mode_changed(action: StringName, enabled: bool) -> void:
	if action == ActivityVisualizationDropDown.ACTION_GLOBAL_NEURAL_CONNECTIONS:
		_toggle_global_neural_connections(enabled)
	elif action == ActivityVisualizationDropDown.ACTION_VOXEL_INSPECTOR:
		BV.UI.brain_monitor_activity_mode = UIManager.BRAIN_MONITOR_ACTIVITY_MODE.VOXEL_INSPECTOR
		BV.WM.spawn_voxel_inspector()
	elif action == ActivityVisualizationDropDown.ACTION_MEMORY_INSPECTOR:
		BV.UI.brain_monitor_activity_mode = UIManager.BRAIN_MONITOR_ACTIVITY_MODE.MEMORY_INSPECTOR
		BV.WM.spawn_memory_inspector()

func _toggle_global_neural_connections(enabled: bool) -> void:
	print("🔗 Toggling global neural connections: ", enabled)
	
	# Find the brain monitor scene
	var brain_monitor = _find_brain_monitor_scene()
	if not brain_monitor:
		print("🔗 ❌ Could not find brain monitor scene")
		return
	
	# Get all cortical area objects in the 3D scene
	var cortical_area_objects = _find_all_cortical_area_objects(brain_monitor)
	if cortical_area_objects.is_empty():
		print("🔗 ❌ No cortical area objects found in brain monitor")
		return
	
	print("🔗 Found ", cortical_area_objects.size(), " cortical area objects")
	
	# Toggle connections for all cortical areas
	for cortical_area_obj in cortical_area_objects:
		if enabled:
			# Show connections (simulate hover) with global mode
			cortical_area_obj.set_hover_over_volume_state(true)
		else:
			# Hide connections (simulate unhover)
			cortical_area_obj.set_hover_over_volume_state(false)
	
	if enabled:
		print("🔗 ✅ Global neural connections ENABLED for ", cortical_area_objects.size(), " areas")
	else:
		print("🔗 ❌ Global neural connections DISABLED for ", cortical_area_objects.size(), " areas")

func _find_brain_monitor_scene() -> Node:
	# Try to find the brain monitor scene in the scene tree
	# Look for UI_BrainMonitor_3DScene or similar
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	return _recursive_find_node_by_class(tree.root, "UI_BrainMonitor_3DScene")

func _recursive_find_node_by_class(node: Node, target_class_name: String) -> Node:
	# Check if current node matches
	if node.get_script() and node.get_script().get_global_name() == target_class_name:
		return node
	
	# Check children recursively
	for child in node.get_children():
		var result = _recursive_find_node_by_class(child, target_class_name)
		if result:
			return result
	
	return null

func _find_all_cortical_area_objects(brain_monitor: Node) -> Array:
	# Find all UI_BrainMonitor_CorticalArea objects in the brain monitor
	var cortical_areas = []
	_recursive_find_cortical_areas(brain_monitor, cortical_areas)
	return cortical_areas

func _recursive_find_cortical_areas(node: Node, cortical_areas: Array) -> void:
	# Check if current node is a cortical area
	if node.get_script() and node.get_script().get_global_name() == "UI_BrainMonitor_CorticalArea":
		cortical_areas.append(node)
		# Debug: Check if this is a memory area
		if node._representing_cortial_area and node._representing_cortial_area.cortical_type == 1:  # MEMORY type
			print("🔗 Found MEMORY cortical area in global toggle: ", node._representing_cortial_area.cortical_ID)
	
	# Check children recursively
	for child in node.get_children():
		_recursive_find_cortical_areas(child, cortical_areas)

func _theme_updated(new_theme: Theme) -> void:
	theme = new_theme
	_sync_refresh_rate_background_style()


## Keep refresh-rate input background visually aligned with neurons/synapses fields.
func _sync_refresh_rate_background_style() -> void:
	if _refresh_rate_field == null or _neuron_count == null:
		return
	var unified_style: StyleBox = null
	if _neuron_count.has_theme_stylebox(&"read_only"):
		unified_style = _neuron_count.get_theme_stylebox(&"read_only")
	elif _neuron_count.has_theme_stylebox(&"normal"):
		unified_style = _neuron_count.get_theme_stylebox(&"normal")
	if unified_style == null:
		return
	var style_names: Array[StringName] = []
	style_names.append(&"normal")
	style_names.append(&"focus")
	style_names.append(&"read_only")
	for style_name in style_names:
		_refresh_rate_field.add_theme_stylebox_override(style_name, unified_style.duplicate())




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


## Build dropdown items: all sub-circuits under the genome root (matches global top-bar Circuits combo).
func _build_topbar_region_items() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var scope_region: BrainRegion = null
	if FeagiCore != null and FeagiCore.feagi_local_cache != null and FeagiCore.feagi_local_cache.brain_regions != null:
		scope_region = FeagiCore.feagi_local_cache.brain_regions.get_root_region()
	if scope_region != null:
		for region in scope_region.get_all_subregions_recursive():
			items.append({"label": region.friendly_name, "payload": region})
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("label", "")).to_lower() < String(b.get("label", "")).to_lower()
	)
	return items


## Build dropdown items for cortical areas of the given type.
func _build_topbar_cortical_items(area_type: AbstractCorticalArea.CORTICAL_AREA_TYPE) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var areas: Array[AbstractCorticalArea] = FeagiCore.feagi_local_cache.cortical_areas.search_for_available_cortical_areas_by_type(area_type)
	areas.sort_custom(func(a: AbstractCorticalArea, b: AbstractCorticalArea) -> bool:
		return String(a.friendly_name).to_lower() < String(b.friendly_name).to_lower()
	)
	for area in areas:
		items.append({"label": area.friendly_name, "payload": area})
	return items


## Focus the selected region in the active view.
func _focus_region_from_topbar(region: BrainRegion) -> void:
	var bm := BV.UI.get_active_brain_monitor()
	if bm != null:
		if bm.has_method("focus_on_brain_region"):
			bm.focus_on_brain_region(region)
			bm.flash_indicator_for_brain_region(region)
			return
		if bm.get_pancake_camera():
			bm.get_pancake_camera().teleport_to_look_at_without_changing_angle(Vector3(region.coordinates_3D))
		return
	var cb := _get_active_cb()
	if cb != null:
		cb.focus_on_region(region)


## Focus the selected cortical area in the active view.
func _focus_cortical_from_topbar(area: AbstractCorticalArea) -> void:
	var bm := BV.UI.get_active_brain_monitor()
	if bm != null:
		if bm.has_method("focus_on_cortical_area"):
			bm.focus_on_cortical_area(area)
			bm.flash_indicator_for_cortical_area(area)
			return
		if bm.get_pancake_camera():
			var center_pos = Vector3(area.coordinates_3D) + (area.dimensions_3D / 2.0)
			bm.get_pancake_camera().teleport_to_look_at_without_changing_angle(center_pos)
		return
	var cb := _get_active_cb()
	if cb != null:
		cb.focus_on_cortical_area(area)


## Find the active Circuit Builder tab if one is focused.
func _get_active_cb() -> CircuitBuilder:
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

	
func _update_neuron_count_current(val: int) -> void:
	_neuron_count.text = _format_int(val) 
	
func _update_synapse_count_current(val: int) -> void:
	_synapse_count.text = _format_int(val)

func _on_genome_about_to_reload() -> void:
	#_neuron_count.text = ""
	#_synapse_count.text = ""
	pass

#TODO remove this?
func _shorten_number(num: float) -> String:
	var a: int
	if num > 1000000:
		a = roundi(num / 1000000.0)
		return str(a) + "M"
	if num > 1000:
		a = roundi(num / 1000.0)
		return str(a) + "K"
	return str(a)

func _format_int(number: int) -> String:
	var number_str: String = str(number)
	var formatted_str: String = "" 
	var digit_count: int = 0

	for i in range(number_str.length() - 1, -1, -1):
		formatted_str = number_str[i] + formatted_str
		digit_count += 1
		if digit_count % 3 == 0 and i != 0:
			formatted_str = "," + formatted_str
	return formatted_str
