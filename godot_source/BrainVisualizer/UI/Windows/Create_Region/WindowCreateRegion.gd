extends BaseDraggableWindow
class_name WindowCreateRegion

const BUTTON_PREFAB: PackedScene = preload("res://BrainVisualizer/UI/GenericElements/Scroll/ScrollIItemPrefab.tscn")

var _selected: Array[GenomeObject]
var _parent_region: BrainRegion
var _name_box: TextInput
var _vector: Vector3iSpinboxField
var _add_button: ButtonTextureRectScaling

func _ready():
	super()
	_name_box = _window_internals.get_node("HBoxContainer/TextInput")
	_vector = _window_internals.get_node("HBoxContainer2/Vector3fField")
	_add_button = _window_internals.get_node("ScrollSectionGenericTemplate/HBoxContainer/Add")


func setup(parent_region: BrainRegion, selected_items: Array[GenomeObject] = []) -> void:
	_setup_base_window("create_region")
	_selected = selected_items
	_parent_region = parent_region


func _add_button_pressed() -> void:
	## TODO open menu
	pass

func _add_button_response(genome_object: GenomeObject) -> void:
	if genome_object == null:
		return
	var button: Button = BUTTON_PREFAB.instantiate()
	button.text = genome_object.get_name()
	_selected.append(genome_object)

func _create_region_button_pressed() -> void:
	#TODO check name collesions
	pass
