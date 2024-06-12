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

func _load_internal_listing(genome_object: GenomeObject) -> void:
	if genome_object == null:
		return
	var button: Button = BUTTON_PREFAB.instantiate()
	button.text = genome_object.friendly_name
	#_scroll_section.add_item(button, genome_object, false)

func _on_press_cancel():
	close_window()

func _on_press_open_circuit_builder(): #TODO change the spawn region to the last active one
	var root_region: BrainRegion = FeagiCore.feagi_local_cache.brain_regions.get_root_region()
	var root_region_tab: UITabContainer = BV.UI.root_UI_view.return_UITabContainer_holding_CB_of_given_region(root_region)
	BV.UI.root_UI_view.show_or_create_CB_of_region(_editing_region, root_region_tab)


func _on_press_update():
	FeagiCore.requests.edit_region_object(_editing_region, _editing_region_parent, _region_name.text, "", _editing_region.coordinates_2D, _region_3D_position.current_vector) # TODO description, 2d location?
	close_window()

