extends BaseDraggableWindow
class_name WindowViewCorticalArea

const WINDOW_NAME: StringName = "view_cortical"
const ITEM_PREFAB: PackedScene = preload("res://BrainVisualizer/UI/Windows/View_Cortical_Areas/WindowViewCorticalAreaItem.tscn")

var _scroll_section: ScrollSectionGenericWithFilter


func _ready() -> void:
	super()
	_scroll_section = _window_internals.get_node("ScrollSectionGenericWithFilter")
	FeagiCore.feagi_local_cache.cortical_areas.cortical_area_about_to_be_removed.connect(_cortical_area_removed)
	FeagiCore.feagi_local_cache.cortical_areas.cortical_area_added.connect(_cortical_area_added)

func setup() -> void:
	_setup_base_window(WINDOW_NAME)
	for cortical_area: AbstractCorticalArea in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.values():
		_cortical_area_added(cortical_area)

func _press_add_cortical_area() -> void:
	BV.WM.spawn_create_cortical()
	close_window()
 
func _cortical_area_added(cortical_area: AbstractCorticalArea) -> void:
	var item: Control = ITEM_PREFAB.instantiate()
	var button: Button = item.get_node("Button")
	var checkbox: CheckBox = item.get_node("CheckBox")
	button.text = cortical_area.friendly_name
	button.pressed.connect(_press_cortical.bind(cortical_area))
	checkbox.button_pressed = cortical_area.cortical_visibility
	cortical_area.friendly_name_updated.connect(button.set_text)
	
	_scroll_section.scroll_section.add_generic_item(item, cortical_area, cortical_area.friendly_name)

func _cortical_area_removed(cortical_area: AbstractCorticalArea) -> void:
	_scroll_section.scroll_section.attempt_remove_item(cortical_area)

func _button_update_visabilities() -> void:
	var visible_cortical_areas: Array[AbstractCorticalArea] = []
	for cortical_area in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.values():
		var item: ScrollSectionGenericItem = _scroll_section.scroll_section.attempt_retrieve_item(cortical_area)
		var checkbox: CheckBox = item.get_control().get_node("CheckBox")
		if !checkbox.button_pressed:
			visible_cortical_areas.append(cortical_area)
	FeagiCore.requests.set_cortical_areas_that_are_invisible(visible_cortical_areas)
	close_window()

func _press_cortical(cortical_area: AbstractCorticalArea) -> void:
	BV.UI.snap_camera_to_cortical_area(cortical_area)
	BV.UI.selection_system.clear_all_highlighted()
	BV.UI.selection_system.add_to_highlighted(cortical_area)
