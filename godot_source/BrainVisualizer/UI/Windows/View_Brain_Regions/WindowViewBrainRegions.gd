extends BaseDraggableWindow
class_name WindowViewBrainRegions

const WINDOW_NAME: StringName = "view_brain_regions"
const ITEM_PREFAB: PackedScene = preload("res://BrainVisualizer/UI/Windows/View_Brain_Regions/WindowViewBrainRegionItem.tscn")

var _scroll_section: ScrollSectionGenericWithFilter

func _ready() -> void:
	super()
	_scroll_section = _window_internals.get_node("ScrollSectionGenericWithFilter")
	FeagiCore.feagi_local_cache.brain_regions.region_about_to_be_removed.connect(_region_removed)
	FeagiCore.feagi_local_cache.brain_regions.region_added.connect(_region_added)

func setup() -> void:
	_setup_base_window(WINDOW_NAME)
	for region: BrainRegion in FeagiCore.feagi_local_cache.brain_regions.available_brain_regions.values():
		_region_added(region)

func _press_add_region() -> void:
	BV.WM.spawn_create_region(FeagiCore.feagi_local_cache.brain_regions.get_root_region(), [])
	close_window()

func _region_added(region: BrainRegion) -> void:
	var item: Control = ITEM_PREFAB.instantiate()
	var button: Button = item.get_node("Button")
	var checkbox: CheckBox = item.get_node("CheckBox")
	button.text = region.friendly_name
	button.pressed.connect(_press_region.bind(region))
	# Keep checkbox for structural parity; behavior TBD for brain regions
	region.name_updated.connect(button.set_text)
	_scroll_section.scroll_section.add_generic_item(item, region, region.friendly_name)

func _region_removed(region: BrainRegion) -> void:
	_scroll_section.scroll_section.attempt_remove_item(region)

func _button_update_visabilities() -> void:
	# Placeholder for parity with cortical areas window
	close_window()

func _press_region(region: BrainRegion) -> void:
	# Teleport camera to the region's 3D coordinates (center point)
	if BV.UI.temp_root_bm and BV.UI.temp_root_bm._pancake_cam:
		BV.UI.temp_root_bm._pancake_cam.teleport_to_look_at_without_changing_angle(Vector3(region.coordinates_3D))
		return

