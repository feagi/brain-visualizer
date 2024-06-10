extends BaseDraggableWindow
class_name WindowSelectGenomeObject

const WINDOW_NAME: StringName = "select_genome_object"

signal user_selected_object_nonfinal(object: GenomeObject)
signal user_selected_object_final(object: GenomeObject)

var _selected_object: GenomeObject
var _type_of_selection: GenomeObject.SINGLE_MAKEUP
var _starting_region: BrainRegion
var _scroll_genome_object: ScrollGenomeObjectSelector
var _selection_label: Label
var _select: Button

func _ready() -> void:
	super()
	_scroll_genome_object = _window_internals.get_node('ScrollGenomeObjectSelector')
	_selection_label = _window_internals.get_node('Label')
	_select = _window_internals.get_node('HBoxContainer/Select')
	_select.disabled = true
	

func setup(starting_region: BrainRegion, type_of_selection: GenomeObject.SINGLE_MAKEUP) -> void:
	_setup_base_window(WINDOW_NAME)
	_type_of_selection = type_of_selection
	_starting_region = starting_region
	_scroll_genome_object.setup_from_starting_region(starting_region)
	
	match(_type_of_selection):
		GenomeObject.SINGLE_MAKEUP.ANY_GENOME_OBJECT:
			_selection_label.text = "Please select a target"
			_scroll_genome_object.region_selected.connect(_object_selected)
			_scroll_genome_object.area_selected.connect(_object_selected)
		GenomeObject.SINGLE_MAKEUP.SINGLE_BRAIN_REGION:
			_selection_label.text = "Please select a Brain Region"
			_scroll_genome_object.region_selected.connect(_region_selected)
		GenomeObject.SINGLE_MAKEUP.SINGLE_CORTICAL_AREA:
			_selection_label.text = "Please select a Cortical Area"
			_scroll_genome_object.area_selected.connect(_area_selected)
	

func _object_selected(object: GenomeObject) -> void:
	if object is AbstractCorticalArea:
		_area_selected(object as AbstractCorticalArea)
	if object is BrainRegion:
		_region_selected(object as BrainRegion)
	user_selected_object_nonfinal.emit(object)
	_select.disabled = !GenomeObject.is_given_object_covered_by_makeup(object, _type_of_selection)


func _area_selected(area: AbstractCorticalArea) -> void:
	_selected_object = area
	_selection_label.text = "Selected cortical area %s" % area.friendly_name
	_select.disabled = false

func _region_selected(region: BrainRegion) -> void:
	_selected_object = region
	_selection_label.text = "Selected brain region %s" % region.friendly_name
	_select.disabled = false

func _select_pressed() -> void:
	if _selected_object == null:
		close_window()
		return
	match(_type_of_selection):
		GenomeObject.SINGLE_MAKEUP.ANY_GENOME_OBJECT:
			user_selected_object_final.emit(_selected_object)
		GenomeObject.SINGLE_MAKEUP.SINGLE_BRAIN_REGION:
			if _selected_object is BrainRegion:
				user_selected_object_final.emit(_selected_object)
		GenomeObject.SINGLE_MAKEUP.SINGLE_CORTICAL_AREA:
			if _selected_object is AbstractCorticalArea:
				user_selected_object_final.emit(_selected_object)
	close_window()
