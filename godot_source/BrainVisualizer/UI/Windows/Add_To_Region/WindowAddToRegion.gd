extends BaseDraggableWindow
class_name WindowAddToRegion

var _region_to_move_to: BrainRegion = null
var _objects_adding: Array[GenomeObject]
var _explorer: ScrollGenomeObjectSelector
var _region_label: Label
var _select: Button

func _ready():
	super()
	_explorer = _window_internals.get_node("ScrollGenomeObjectSelector")
	_region_label = _window_internals.get_node("Label")
	_select = _window_internals.get_node("HBoxContainer/Select")

func setup(adding: Array[GenomeObject]) -> void:
	_setup_base_window("add_to_region")
	_objects_adding = adding
	_explorer.setup_from_starting_region(FeagiCore.feagi_local_cache.brain_regions.return_root_region())

func _region_selected(region: BrainRegion) -> void:
	_region_to_move_to = region
	_region_label.text = region.name
	_select.disabled = false

func _add_region_pressed() -> void:
	if _region_to_move_to == null:
		_region_to_move_to = FeagiCore.feagi_local_cache.brain_regions.return_root_region()
	BV.WM.spawn_create_region(_region_to_move_to, _objects_adding)

func _select_pressed() -> void:
	FeagiCore.requests.move_objects_to_region(_region_to_move_to, _objects_adding)
	close_window()
