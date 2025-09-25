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
	_btn_interconnect_add.mouse_filter = Control.MOUSE_FILTER_STOP
	_btn_interconnect_add.z_index = 100
	_btn_memory_add.mouse_filter = Control.MOUSE_FILTER_STOP
	_btn_memory_add.z_index = 100
	_btn_inputs_add.mouse_filter = Control.MOUSE_FILTER_STOP
	_btn_inputs_add.z_index = 100
	_btn_outputs_add.mouse_filter = Control.MOUSE_FILTER_STOP
	_btn_outputs_add.z_index = 100

	_btn_brain_regions_list.pressed.connect(_open_brain_regions)
	_btn_brain_regions_add.pressed.connect(_add_brain_region)
	_btn_interconnect_list.pressed.connect(_open_interconnect_areas)
	_btn_memory_list.pressed.connect(_open_memory_areas)
	_btn_inputs_list.pressed.connect(_open_inputs)
	_btn_outputs_list.pressed.connect(_open_outputs)
	# Robust press handling with debug
	_btn_interconnect_add.pressed.connect(func():
		print("BrainObjectsCombo: pressed interconnect add")
		_add_interconnect_area()
	)
	_btn_interconnect_add.button_down.connect(func(): print("BrainObjectsCombo: button_down interconnect add"))
	_btn_interconnect_add.button_up.connect(func(): print("BrainObjectsCombo: button_up interconnect add"))
	_btn_interconnect_add.mouse_entered.connect(func():
		print("BrainObjectsCombo: hover interconnect add")
		_apply_hover_visual(_btn_interconnect_add, true)
	)
	_btn_interconnect_add.mouse_exited.connect(func():
		print("BrainObjectsCombo: leave interconnect add")
		_apply_hover_visual(_btn_interconnect_add, false)
	)

	_btn_memory_add.pressed.connect(func():
		print("BrainObjectsCombo: pressed memory add")
		_add_memory_area()
	)
	_btn_memory_add.button_down.connect(func(): print("BrainObjectsCombo: button_down memory add"))
	_btn_memory_add.button_up.connect(func(): print("BrainObjectsCombo: button_up memory add"))
	_btn_memory_add.mouse_entered.connect(func():
		print("BrainObjectsCombo: hover memory add")
		_apply_hover_visual(_btn_memory_add, true)
	)
	_btn_memory_add.mouse_exited.connect(func():
		print("BrainObjectsCombo: leave memory add")
		_apply_hover_visual(_btn_memory_add, false)
	)

	_btn_inputs_add.pressed.connect(func():
		print("BrainObjectsCombo: pressed input add")
		_add_input_area()
	)
	_btn_inputs_add.button_down.connect(func(): print("BrainObjectsCombo: button_down input add"))
	_btn_inputs_add.button_up.connect(func(): print("BrainObjectsCombo: button_up input add"))
	_btn_inputs_add.mouse_entered.connect(func():
		print("BrainObjectsCombo: hover input add")
		_apply_hover_visual(_btn_inputs_add, true)
	)
	_btn_inputs_add.mouse_exited.connect(func():
		print("BrainObjectsCombo: leave input add")
		_apply_hover_visual(_btn_inputs_add, false)
	)

	_btn_outputs_add.pressed.connect(func():
		print("BrainObjectsCombo: pressed output add")
		_add_output_area()
	)
	_btn_outputs_add.button_down.connect(func(): print("BrainObjectsCombo: button_down output add"))
	_btn_outputs_add.button_up.connect(func(): print("BrainObjectsCombo: button_up output add"))
	_btn_outputs_add.mouse_entered.connect(func():
		print("BrainObjectsCombo: hover output add")
		_apply_hover_visual(_btn_outputs_add, true)
	)
	_btn_outputs_add.mouse_exited.connect(func():
		print("BrainObjectsCombo: leave output add")
		_apply_hover_visual(_btn_outputs_add, false)
	)
	# Hover visuals for Add Circuits (Brain Regions) button
	_btn_brain_regions_add.mouse_entered.connect(func():
		print("BrainObjectsCombo: hover circuits add")
		_apply_hover_visual(_btn_brain_regions_add, true)
	)
	_btn_brain_regions_add.mouse_exited.connect(func():
		print("BrainObjectsCombo: leave circuits add")
		_apply_hover_visual(_btn_brain_regions_add, false)
	)

	_update_buttons_state()
	queue_redraw()
	# Ensure background redraws on resize/theme changes for consistent back plate
	resized.connect(func(): queue_redraw())

func set_3d_context(bm_scene: UI_BrainMonitor_3DScene, region: BrainRegion) -> void:
	_is_3d_context = true
	_bm_scene = bm_scene
	context_region = region
	_update_buttons_state()

func set_2d_context(cb_scene: CircuitBuilder, region: BrainRegion) -> void:
	_is_3d_context = false
	_cb_scene = cb_scene
	context_region = region
	_update_buttons_state()

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
		_set_visibility_for_context(false, false) # hide all specialized by default
		return
	# Allow cortical area creation in any region; enforce type restrictions in creation window
	_btn_interconnect_add.disabled = false
	_btn_memory_add.disabled = false
	_btn_inputs_add.disabled = false
	_btn_outputs_add.disabled = false
	# Listing is always enabled (direct-only; will be empty if none)
	_btn_brain_regions_list.disabled = false
	_btn_interconnect_list.disabled = false
	_btn_memory_list.disabled = false
	_btn_inputs_list.disabled = false
	_btn_outputs_list.disabled = false
	# Regions can always be created
	_btn_brain_regions_add.disabled = false

	# Set visibility based on context (3D vs 2D) and whether region is root
	var is_root := _is_root_region()
	if _is_3d_context:
		# 3D: root shows Circuits + Inputs + Outputs; subregions show Circuits + Interconnect + Memory
		_set_visibility_for_context(not is_root, is_root)
	else:
		# 2D CB: root shows Circuits + Inputs + Outputs; non-root shows Circuits + Interconnect + Memory
		_set_visibility_for_context(not is_root, is_root)

func _open_brain_regions() -> void:
	if context_region == null:
		return
	BV.WM.spawn_brain_regions_view_with_context(context_region, func(region: BrainRegion): _focus_region(region))

func _add_brain_region() -> void:
	if context_region == null:
		return
	var selected_objects: Array[GenomeObject] = []
	BV.WM.spawn_create_region(context_region, selected_objects)

func _open_interconnect_areas() -> void:
	if context_region == null:
		return
	BV.WM.spawn_cortical_view_with_context_filtered(
		context_region,
		func(area: AbstractCorticalArea): _focus_cortical(area),
		AbstractCorticalArea.CORTICAL_AREA_TYPE.CUSTOM
	)

func _open_memory_areas() -> void:
	if context_region == null:
		return
	BV.WM.spawn_cortical_view_with_context_filtered(
		context_region,
		func(area: AbstractCorticalArea): _focus_cortical(area),
		AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY
	)

func _open_inputs() -> void:
	if context_region == null:
		return
	BV.WM.spawn_cortical_view_with_context_filtered(
		context_region,
		func(area: AbstractCorticalArea): _focus_cortical(area),
		AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU
	)

func _open_outputs() -> void:
	if context_region == null:
		return
	BV.WM.spawn_cortical_view_with_context_filtered(
		context_region,
		func(area: AbstractCorticalArea): _focus_cortical(area),
		AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU
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
	$TextureButton_BrainRegions.visible = true
	# Interconnect/Memory visibility
	$InterconnectAreasList.visible = show_interconnect_and_memory
	$TextureButton_Interconnect.visible = show_interconnect_and_memory
	$MemoryAreasList.visible = show_interconnect_and_memory
	$TextureButton_Memory.visible = show_interconnect_and_memory
	# Inputs/Outputs visibility
	$InputsList.visible = show_inputs_and_outputs
	$TextureButton_Inputs.visible = show_inputs_and_outputs
	$OutputsList.visible = show_inputs_and_outputs
	$TextureButton_Outputs.visible = show_inputs_and_outputs

func _apply_hover_visual(button: Control, hovered: bool) -> void:
	# Subtle scale-up on hover to match main 3D view visual feedback style
	button.scale = HOVER_SCALE if hovered else NORMAL_SCALE

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
	if _is_3d_context and _bm_scene and _bm_scene._pancake_cam:
		_bm_scene._pancake_cam.teleport_to_look_at_without_changing_angle(Vector3(region.coordinates_3D))
		return
	if (not _is_3d_context) and _cb_scene:
		_cb_scene.focus_on_region(region)

func _focus_cortical(area: AbstractCorticalArea) -> void:
	if _is_3d_context and _bm_scene and _bm_scene._pancake_cam:
		var center_pos = Vector3(area.coordinates_3D) + (area.dimensions_3D / 2.0)
		_bm_scene._pancake_cam.teleport_to_look_at_without_changing_angle(center_pos)
		return
	if (not _is_3d_context) and _cb_scene:
		_cb_scene.focus_on_cortical_area(area)
