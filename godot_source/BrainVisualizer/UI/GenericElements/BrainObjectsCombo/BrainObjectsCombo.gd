extends HBoxContainer
class_name BrainObjectsCombo

var context_region: BrainRegion = null

var _is_3d_context: bool = true
var _bm_scene: UI_BrainMonitor_3DScene = null
var _cb_scene: CircuitBuilder = null

var _btn_brain_regions_list: BasePanelContainerButton
var _btn_brain_regions_add: TextureButton
var _btn_cortical_list: BasePanelContainerButton
var _btn_cortical_add: TextureButton

const HOVER_SCALE := Vector2(1.15, 1.15)
const NORMAL_SCALE := Vector2(1.0, 1.0)

func _ready() -> void:
	_btn_brain_regions_list = $BrainRegionsList
	_btn_brain_regions_add = $TextureButton_BrainRegions
	_btn_cortical_list = $CorticalAreasList
	_btn_cortical_add = $TextureButton_Cortical

	# Ensure the combo captures events within its bounds; individual buttons will stop events
	mouse_filter = Control.MOUSE_FILTER_STOP
	_btn_cortical_add.mouse_filter = Control.MOUSE_FILTER_STOP
	_btn_cortical_add.z_index = 100

	_btn_brain_regions_list.pressed.connect(_open_brain_regions)
	_btn_brain_regions_add.pressed.connect(_add_brain_region)
	_btn_cortical_list.pressed.connect(_open_cortical_areas)
	# Robust press handling with debug
	_btn_cortical_add.pressed.connect(func():
		print("BrainObjectsCombo: pressed cortical add")
		_add_cortical_area()
	)
	_btn_cortical_add.button_down.connect(func(): print("BrainObjectsCombo: button_down cortical add"))
	_btn_cortical_add.button_up.connect(func(): print("BrainObjectsCombo: button_up cortical add"))
	# Hover visuals for Add Cortical Area button
	_btn_cortical_add.mouse_entered.connect(func():
		print("BrainObjectsCombo: hover cortical add")
		_apply_hover_visual(_btn_cortical_add, true)
	)
	_btn_cortical_add.mouse_exited.connect(func():
		print("BrainObjectsCombo: leave cortical add")
		_apply_hover_visual(_btn_cortical_add, false)
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
		_btn_cortical_list.disabled = true
		_btn_cortical_add.disabled = true
		return
	# Allow cortical area creation in any region; enforce type restrictions in creation window
	_btn_cortical_add.disabled = false
	# Listing is always enabled (direct-only; will be empty if none)
	_btn_brain_regions_list.disabled = false
	_btn_cortical_list.disabled = false
	# Regions can always be created
	_btn_brain_regions_add.disabled = false

func _open_brain_regions() -> void:
	if context_region == null:
		return
	BV.WM.spawn_brain_regions_view_with_context(context_region, func(region: BrainRegion): _focus_region(region))

func _add_brain_region() -> void:
	if context_region == null:
		return
	BV.WM.spawn_create_region(context_region, [])

func _open_cortical_areas() -> void:
	if context_region == null:
		return
	BV.WM.spawn_cortical_view_with_context(context_region, func(area: AbstractCorticalArea): _focus_cortical(area))

func _add_cortical_area() -> void:
	if context_region == null:
		return
	print("BrainObjectsCombo: Opening create cortical window for region:", context_region.region_ID)
	BV.WM.spawn_create_cortical_for_region(context_region)

func _apply_hover_visual(button: Control, hovered: bool) -> void:
	# Subtle scale-up on hover to match main 3D view visual feedback style
	button.scale = HOVER_SCALE if hovered else NORMAL_SCALE

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
