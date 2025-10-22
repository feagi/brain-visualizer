extends BaseDraggableWindow
class_name WindowEditRegion

const WINDOW_NAME: StringName = "edit_region"
const BUTTON_PREFAB: PackedScene = preload("res://BrainVisualizer/UI/GenericElements/Scroll/ScrollIItemPrefab.tscn")

var _region_name: TextInput
var _region_ID: TextInput
var _region_parent: Button
var _region_3D_position: Vector3iSpinboxField
var _scroll_section: ScrollSectionGeneric
var _editing_region: BrainRegion
var _editing_region_parent: BrainRegion
var _brain_region_preview: UI_BrainMonitor_BrainRegionPreview

func _ready() -> void:
	super()
	_region_name = _window_internals.get_node("HBoxContainer3/TextInput")
	_region_ID = _window_internals.get_node("HBoxContainer/TextInput")
	_region_parent = _window_internals.get_node("HBoxContainer5/Button")
	_region_3D_position = _window_internals.get_node("HBoxContainer2/Vector3fField")
	_scroll_section = _window_internals.get_node("ScrollSectionGenericTemplate/PanelContainer/ScrollSectionGeneric")

func setup(editing_region: BrainRegion) -> void:
	_setup_base_window(WINDOW_NAME)
	if editing_region.is_root_region():
		push_warning("UI WINDOW: Unable to create window for editing regions for the root region! Closing the window!")
		close_window()
		return
	_editing_region = editing_region
	_editing_region_parent = editing_region.current_parent_region
	_region_name.text = editing_region.friendly_name
	_region_ID.text = editing_region.region_ID
	_region_parent.text = editing_region.current_parent_region.friendly_name
	_region_3D_position.current_vector = editing_region.coordinates_3D
	for areas in editing_region.contained_cortical_areas:
		_load_internal_listing(areas)
	for regions in editing_region.contained_regions:
		_load_internal_listing(regions)
	
	# Create brain region preview to show where it will be positioned
	_create_brain_region_preview()
	
	# Connect 3D position changes to update preview
	if _region_3D_position.user_updated_vector.connect(_update_preview_position):
		print("🔮 Connected brain region preview to 3D position updates")
	else:
		push_warning("Failed to connect brain region preview to position updates")

func _load_internal_listing(genome_object: GenomeObject) -> void:
	if genome_object == null:
		return
	_scroll_section.add_text_button(genome_object, genome_object.friendly_name, Callable())

func _create_brain_region_preview() -> void:
	# Find the brain monitor scene that contains this region
	var brain_monitor_3d = _find_brain_monitor_containing_region()
	if brain_monitor_3d == null:
		push_warning("🔮 Could not find brain monitor to create preview")
		return
	
	# Create the preview
	_brain_region_preview = brain_monitor_3d.create_brain_region_preview(_editing_region, _editing_region.coordinates_3D)
	print("🔮 Brain region preview created for editing: %s" % _editing_region.friendly_name)

func _find_brain_monitor_containing_region() -> UI_BrainMonitor_3DScene:
	# Look for any brain monitor that has this region
	var brain_monitors = get_tree().get_nodes_in_group("brain_monitors")
	for bm in brain_monitors:
		if bm is UI_BrainMonitor_3DScene:
			if bm._brain_region_visualizations_by_ID.has(_editing_region.friendly_name):
				return bm
	
	# If not found in groups, try through the UI manager
	if BV.UI != null and BV.UI.temp_root_bm != null:
		return BV.UI.temp_root_bm
	
	return null

func _update_preview_position(new_position: Vector3i) -> void:
	if _brain_region_preview:
		_brain_region_preview.update_position_with_new_FEAGI_coordinate(new_position)
		print("🔮 Updated preview position to: %s" % new_position)

func _cleanup_preview() -> void:
	if _brain_region_preview:
		_brain_region_preview.cleanup()
		_brain_region_preview = null
		print("🔮 Cleaned up brain region preview")

## Override to ensure preview cleanup
func close_window() -> void:
	_cleanup_preview()
	super()

func _on_press_cancel():
	close_window()

func _on_press_open_circuit_builder(): #TODO change the spawn region to the last active one
	var root_region: BrainRegion = FeagiCore.feagi_local_cache.brain_regions.get_root_region()
	var root_region_tab: UITabContainer = BV.UI.root_UI_view.return_UITabContainer_holding_CB_of_given_region(root_region)
	BV.UI.root_UI_view.show_or_create_CB_of_region(_editing_region, root_region_tab)


func _on_press_update():
	FeagiCore.requests.edit_region_object(_editing_region, _editing_region_parent, _region_name.text, "", _editing_region.coordinates_2D, _region_3D_position.current_vector) # TODO description, 2d location?
	close_window()

