extends BaseDraggableWindow
class_name WindowSelectGenomeObject

const WINDOW_NAME: StringName = "select_genome_object"

signal final_selection(genome_objects: Array[GenomeObject])

var _selected_object: GenomeObject
var _selection_config: SelectGenomeObjectSettings
var _scroll_genome_object: ScrollGenomeObjectSelector
var _selection_label: Label
var _instructions: Label
var _select: Button

func _ready() -> void:
	super()
	_scroll_genome_object = _window_internals.get_node('ScrollGenomeObjectSelector')
	_selection_label = _window_internals.get_node('Label')
	_select = _window_internals.get_node('HBoxContainer/Select')
	_instructions = _window_internals.get_node("Instructions")
	_select.disabled = true
	

func setup(config: SelectGenomeObjectSettings) -> void:
	_setup_base_window(WINDOW_NAME)
	_selection_config = config
	_scroll_genome_object.setup_from_starting_region(_selection_config)
	_instructions = _selection_config.pick_instructions
	_updated_selected_objects()


func _select_pressed() -> void:
	if _selected_object == null:
		close_window()
		return
	final_selection.emit(_scroll_genome_object.selected_objects)
	close_window()

func _updated_selected_objects() -> void:
	var text: String = "Selected: " 
	for object: GenomeObject in _scroll_genome_object.selected_objects:
		text += object.friendly_name + ", "
