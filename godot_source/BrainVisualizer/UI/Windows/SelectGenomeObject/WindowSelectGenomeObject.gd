extends BaseDraggableWindow
class_name WindowSelectGenomeObject

const WINDOW_NAME: StringName = "select_genome_object"
const ScenePick = preload("res://BrainVisualizer/UI/Windows/SelectGenomeObject/CorticalExplorerScenePick.gd")

signal final_selection(genome_objects: Array[GenomeObject])

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
	
func setup(config: SelectGenomeObjectSettings) -> void:
	_setup_base_window(WINDOW_NAME)
	_selection_config = config
	_scroll_genome_object.setup_from_starting_region(_selection_config)
	_instructions.text = _selection_config.pick_instructions
	_updated_selected_objects(config.preselected_objects)
	_select.disabled = len(config.preselected_objects) == 0
	_listen_for_scene_picks()

func _exit_tree() -> void:
	_stop_listening_for_scene_picks()

## Checks [param area] in this explorer. Returns true when that area is now selected.
func choose_scene_area(area: AbstractCorticalArea) -> bool:
	if area == null or _scroll_genome_object == null:
		return false
	var picked: Array[GenomeObject] = [area]
	_scroll_genome_object.apply_mouse_pick(picked)
	return _scroll_genome_object.has_selected_id(area)

## A mouse click chooses that area or circuit in this explorer instead of bypassing it.
func _on_scene_selection(objects: Array[GenomeObject], context: SelectionSystem.SOURCE_CONTEXT, _override_usecases: Array[SelectionSystem.OVERRIDE_USECASE]) -> void:
	if not ScenePick.accepts_mouse_context(context):
		return
	if _scroll_genome_object == null:
		return
	_scroll_genome_object.apply_mouse_pick(objects)

func _listen_for_scene_picks() -> void:
	if BV == null or BV.UI == null or BV.UI.selection_system == null:
		return
	if BV.UI.selection_system.objects_selection_event_called.is_connected(_on_scene_selection):
		return
	BV.UI.selection_system.objects_selection_event_called.connect(_on_scene_selection)

func _stop_listening_for_scene_picks() -> void:
	if BV == null or BV.UI == null or BV.UI.selection_system == null:
		return
	if BV.UI.selection_system.objects_selection_event_called.is_connected(_on_scene_selection):
		BV.UI.selection_system.objects_selection_event_called.disconnect(_on_scene_selection)

func _proxy_object_added_or_removed(_irrelevant) -> void:
	_updated_selected_objects(_scroll_genome_object.selected_objects)

func _select_pressed() -> void:
	final_selection.emit(_scroll_genome_object.selected_objects)
	close_window()

func _updated_selected_objects(selected: Array[GenomeObject]) -> void:
	if len(selected) == 0:
		_selection_label.text = "Nothing Selected!"
		_select.disabled = true
		return
	
	var text: String = "Selected: " 
	for object: GenomeObject in _scroll_genome_object.selected_objects:
		text += object.friendly_name + ", "
	text = text.erase(len(text) - 2)
	_selection_label.text = text
	_select.disabled = false
