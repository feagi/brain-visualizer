extends BaseDraggableWindow
class_name WindowCreateRegion

const BUTTON_PREFAB: PackedScene = preload("res://BrainVisualizer/UI/GenericElements/Scroll/ScrollIItemPrefab.tscn")


var _region_drop_down: RegionDropDown
var _name_box: TextInput
var _vector: Vector3iSpinboxField
var _add_button: ButtonTextureRectScaling
var _scroll_section: ScrollSectionGeneric

func _ready():
	super()
	_region_drop_down = _window_internals.get_node("HBoxContainer3/RegionDropDown")
	_name_box = _window_internals.get_node("HBoxContainer/TextInput")
	_vector = _window_internals.get_node("HBoxContainer2/Vector3fField")
	_add_button = _window_internals.get_node("ScrollSectionGenericTemplate/HBoxContainer/Add")
	_scroll_section = _window_internals.get_node("ScrollSectionGenericTemplate/PanelContainer/ScrollSectionGeneric")


func setup(parent_region: BrainRegion, selected_items: Array[GenomeObject] = []) -> void:
	_setup_base_window("create_region")
	_region_drop_down.set_selected_region(parent_region)
	for selected in selected_items:
		var button: Button = BUTTON_PREFAB.instantiate()
		button.text = selected.get_name()
		_scroll_section.add_item(button, selected)

func _add_button_pressed() -> void:
	## TODO open menu
	pass

func _add_button_response(genome_object: GenomeObject) -> void:
	if genome_object == null:
		return
	var button: Button = BUTTON_PREFAB.instantiate()
	button.text = genome_object.get_name()
	_scroll_section.add_item(button, genome_object)
	

func _create_region_button_pressed() -> void:
	var region: BrainRegion = _region_drop_down.get_selected_region()
	var selected: Array[GenomeObject] = []
	selected.assign(_scroll_section.get_key_array())
	var region_name: StringName = _name_box.text
	var coords_2D: Vector2i = Vector2i(0,0) #TODO
	var coords_3D: Vector3i = _vector.current_vector
	FeagiCore.requests.create_region(region, selected, region_name, coords_2D, coords_3D)
	close_window()
