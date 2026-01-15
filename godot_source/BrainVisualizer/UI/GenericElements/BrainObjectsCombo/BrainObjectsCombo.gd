extends HBoxContainer
class_name BrainObjectsCombo

var context_region: BrainRegion = null

var _is_3d_context: bool = true
var _bm_scene: UI_BrainMonitor_3DScene = null
var _cb_scene: CircuitBuilder = null

var _btn_brain_regions_list: BasePanelContainerButton
var _btn_brain_regions_add: TextureButton
var _btn_interconnect_list: BasePanelContainerButton
var _btn_interconnect_add: TextureButton
var _btn_memory_list: BasePanelContainerButton
var _btn_memory_add: TextureButton
var _btn_inputs_list: BasePanelContainerButton
var _btn_inputs_add: TextureButton
var _btn_outputs_list: BasePanelContainerButton
var _btn_outputs_add: TextureButton

const HOVER_SCALE := Vector2(1.15, 1.15)
const NORMAL_SCALE := Vector2(1.0, 1.0)
const PREFAB_FILTERABLE_LIST_POPUP: PackedScene = preload("res://BrainVisualizer/UI/GenericElements/DropDown/FilterableListPopup.tscn")

var _list_popup: FilterableListPopup

## Wire the combo buttons and dropdown popup.
func _ready() -> void:
	_btn_brain_regions_list = $BrainRegionsList
	_btn_brain_regions_add = $TextureButton_BrainRegions
	_btn_interconnect_list = $InterconnectAreasList
	_btn_interconnect_add = $TextureButton_Interconnect
	_btn_memory_list = $MemoryAreasList
	_btn_memory_add = $TextureButton_Memory
	_btn_inputs_list = $InputsList
	_btn_inputs_add = $TextureButton_Inputs
	_btn_outputs_list = $OutputsList
	_btn_outputs_add = $TextureButton_Outputs

	# Ensure the combo captures events within its bounds; individual buttons will stop events
	mouse_filter = Control.MOUSE_FILTER_STOP

	_btn_brain_regions_list.pressed.connect(_open_brain_regions)
	_btn_brain_regions_add.pressed.connect(_add_brain_region)
	_btn_interconnect_list.pressed.connect(_open_interconnect_areas)
	_btn_interconnect_add.pressed.connect(_add_interconnect_area)
	_btn_memory_list.pressed.connect(_open_memory_areas)
	_btn_memory_add.pressed.connect(_add_memory_area)
	_btn_inputs_list.pressed.connect(_open_inputs)
	_btn_inputs_add.pressed.connect(_add_input_area)
	_btn_outputs_list.pressed.connect(_open_outputs)
	_btn_outputs_add.pressed.connect(_add_output_area)
	_ensure_list_popup()
	_update_buttons_state()
	queue_redraw()
	# Ensure background redraws on resize/theme changes for consistent back plate
	resized.connect(func(): queue_redraw())
	
	# BrainMonitor tabs run inside a SubViewport; theme inheritance may not reach this subtree.
	# Opt-in to BV's theme-driven scaling so these "top bar" buttons resize with +/- UI scaling.
	BV.UI.theme_changed.connect(_on_theme_changed)
	_on_theme_changed(BV.UI.loaded_theme)

func _on_theme_changed(new_theme: Theme) -> void:
	theme = new_theme
	_apply_theme_sizes_recursive(self)

func _apply_theme_sizes_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is TextureButton:
			(child as TextureButton).custom_minimum_size = BV.UI.get_minimum_size_from_loaded_theme_variant_given_control(child, "TextureButton")
		elif child is TextureRect:
			(child as TextureRect).custom_minimum_size = BV.UI.get_minimum_size_from_loaded_theme_variant_given_control(child, "TextureRect")
		_apply_theme_sizes_recursive(child)

func set_3d_context(bm_scene: UI_BrainMonitor_3DScene, region: BrainRegion) -> void:
	_is_3d_context = true
	_bm_scene = bm_scene
	context_region = region
	_update_buttons_state()

## Switch to 2D context and refresh listings.
func set_2d_context(cb_scene: CircuitBuilder, region: BrainRegion) -> void:
	_is_3d_context = false
	_cb_scene = cb_scene
	context_region = region
	_update_buttons_state()

## Enable or disable buttons based on whether a region is active.
func _update_buttons_state() -> void:
	if context_region == null:
		_btn_brain_regions_list.disabled = true
		_btn_brain_regions_add.disabled = true
		_btn_interconnect_list.disabled = true
		_btn_interconnect_add.disabled = true
		_btn_memory_list.disabled = true
		_btn_memory_add.disabled = true
		_btn_inputs_list.disabled = true
		_btn_inputs_add.disabled = true
		_btn_outputs_list.disabled = true
		_btn_outputs_add.disabled = true
		_set_visibility_for_context(false, false)
		return
	# Listing is always enabled (direct-only; will be empty if none)
	_btn_brain_regions_list.disabled = false
	_btn_brain_regions_add.disabled = false
	_btn_interconnect_list.disabled = false
	_btn_interconnect_add.disabled = false
	_btn_memory_list.disabled = false
	_btn_memory_add.disabled = false
	_btn_inputs_list.disabled = false
	_btn_inputs_add.disabled = false
	_btn_outputs_list.disabled = false
	_btn_outputs_add.disabled = false
	# Root region shows Inputs/Outputs; non-root shows Interconnect/Memory
	var is_root := _is_root_region()
	_set_visibility_for_context(not is_root, is_root)

## Open circuits dropdown for the current region.
func _open_brain_regions() -> void:
	if context_region == null:
		return
	var items := _build_region_items()
	_open_dropdown_for_items(_btn_brain_regions_list, items, "Filter circuits...", func(region: BrainRegion):
		_focus_region(region)
	)

func _add_brain_region() -> void:
	if context_region == null:
		return
	var selected_objects: Array[GenomeObject] = []
	BV.WM.spawn_create_region(context_region, selected_objects)

## Open interconnect areas dropdown for the current region.
func _open_interconnect_areas() -> void:
	if context_region == null:
		return
	var items := _build_cortical_items_for_type(AbstractCorticalArea.CORTICAL_AREA_TYPE.CUSTOM)
	_open_dropdown_for_items(_btn_interconnect_list, items, "Filter interconnect areas...", func(area: AbstractCorticalArea):
		_focus_cortical(area)
	)

## Open memory areas dropdown for the current region.
func _open_memory_areas() -> void:
	if context_region == null:
		return
	var items := _build_cortical_items_for_type(AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY)
	_open_dropdown_for_items(_btn_memory_list, items, "Filter memory areas...", func(area: AbstractCorticalArea):
		_focus_cortical(area)
	)

## Open input areas dropdown for the current region.
func _open_inputs() -> void:
	if context_region == null:
		return
	var items := _build_cortical_items_for_type(AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU)
	_open_dropdown_for_items(_btn_inputs_list, items, "Filter inputs...", func(area: AbstractCorticalArea):
		_focus_cortical(area)
	)

## Open output areas dropdown for the current region.
func _open_outputs() -> void:
	if context_region == null:
		return
	var items := _build_cortical_items_for_type(AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU)
	_open_dropdown_for_items(_btn_outputs_list, items, "Filter outputs...", func(area: AbstractCorticalArea):
		_focus_cortical(area)
	)

func _add_interconnect_area() -> void:
	if context_region == null:
		return
	print("BrainObjectsCombo: Opening create interconnect window for region:", context_region.region_ID)
	BV.WM.spawn_create_cortical_with_type_for_region(context_region, AbstractCorticalArea.CORTICAL_AREA_TYPE.CUSTOM)

func _add_memory_area() -> void:
	if context_region == null:
		return
	print("BrainObjectsCombo: Opening create memory window for region:", context_region.region_ID)
	BV.WM.spawn_create_cortical_with_type_for_region(context_region, AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY)

func _add_input_area() -> void:
	if context_region == null:
		return
	print("BrainObjectsCombo: Opening create input window for region:", context_region.region_ID)
	BV.WM.spawn_create_cortical_with_type_for_region(context_region, AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU)

func _add_output_area() -> void:
	if context_region == null:
		return
	print("BrainObjectsCombo: Opening create output window for region:", context_region.region_ID)
	BV.WM.spawn_create_cortical_with_type_for_region(context_region, AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU)

func _is_root_region() -> bool:
	if context_region == null:
		return false
	if not FeagiCore or not FeagiCore.feagi_local_cache or not FeagiCore.feagi_local_cache.brain_regions:
		return false
	var root_region: BrainRegion = FeagiCore.feagi_local_cache.brain_regions.get_root_region()
	return root_region != null and root_region == context_region

func _set_visibility_for_context(show_interconnect_and_memory: bool, show_inputs_and_outputs: bool) -> void:
	# Circuits always visible
	$BrainRegionsList.visible = true
	if _btn_brain_regions_add:
		_btn_brain_regions_add.visible = true
	# Interconnect/Memory visibility
	$InterconnectAreasList.visible = show_interconnect_and_memory
	if _btn_interconnect_add:
		_btn_interconnect_add.visible = show_interconnect_and_memory
	$MemoryAreasList.visible = show_interconnect_and_memory
	if _btn_memory_add:
		_btn_memory_add.visible = show_interconnect_and_memory
	# Inputs/Outputs visibility
	$InputsList.visible = show_inputs_and_outputs
	if _btn_inputs_add:
		_btn_inputs_add.visible = show_inputs_and_outputs
	$OutputsList.visible = show_inputs_and_outputs
	if _btn_outputs_add:
		_btn_outputs_add.visible = show_inputs_and_outputs

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
		var regions: Array[BrainRegion] = []
		regions.assign(FeagiCore.feagi_local_cache.brain_regions.available_brain_regions.values())
		for region in regions:
			items.append({"label": region.friendly_name, "payload": region})
	if items.is_empty():
		var fallback_regions: Array[BrainRegion] = []
		fallback_regions.assign(FeagiCore.feagi_local_cache.brain_regions.available_brain_regions.values())
		for region in fallback_regions:
			items.append({"label": region.friendly_name, "payload": region})
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("label", "")).to_lower() < String(b.get("label", "")).to_lower()
	)
	return items

## Build dropdown items for cortical areas of the given type.
func _build_cortical_items_for_type(area_type: AbstractCorticalArea.CORTICAL_AREA_TYPE) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var areas: Array[AbstractCorticalArea] = []
	if context_region != null:
		for area in context_region.contained_cortical_areas:
			if area.cortical_type == area_type:
				areas.append(area)
	else:
		areas = FeagiCore.feagi_local_cache.cortical_areas.search_for_available_cortical_areas_by_type(area_type)
	if areas.is_empty():
		areas = FeagiCore.feagi_local_cache.cortical_areas.search_for_available_cortical_areas_by_type(area_type)
	areas.sort_custom(func(a: AbstractCorticalArea, b: AbstractCorticalArea) -> bool:
		return String(a.friendly_name).to_lower() < String(b.friendly_name).to_lower()
	)
	for area in areas:
		items.append({"label": area.friendly_name, "payload": area})
	return items

func _draw() -> void:
	# Draw a themed back plate behind the combo buttons, matching root scene styling
	var back_rect: Rect2 = Rect2(Vector2.ZERO, size)
	# Try to reuse the panel style used by BasePanelContainerButton to keep consistent visuals
	if has_theme_stylebox("panel", "BasePanelContainerButton"):
		var style: StyleBox = get_theme_stylebox("panel", "BasePanelContainerButton")
		draw_style_box(style, back_rect)
		return
	# Fallback: simple semi-transparent rounded rect (should rarely be used if theme is loaded)
	draw_rect(back_rect, Color(0, 0, 0, 0.25), true)

func _focus_region(region: BrainRegion) -> void:
	if _is_3d_context and _bm_scene and _bm_scene.get_pancake_camera():
		_bm_scene.get_pancake_camera().teleport_to_look_at_without_changing_angle(Vector3(region.coordinates_3D))
		return
	if (not _is_3d_context) and _cb_scene:
		_cb_scene.focus_on_region(region)

func _focus_cortical(area: AbstractCorticalArea) -> void:
	if _is_3d_context and _bm_scene and _bm_scene.get_pancake_camera():
		var center_pos = Vector3(area.coordinates_3D) + (area.dimensions_3D / 2.0)
		_bm_scene.get_pancake_camera().teleport_to_look_at_without_changing_angle(center_pos)
		return
	if (not _is_3d_context) and _cb_scene:
		_cb_scene.focus_on_cortical_area(area)
