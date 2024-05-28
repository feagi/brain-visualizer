extends BaseDraggableWindow
class_name SelectGenomeObject

enum SELECTION_TYPE {
	GENOME_OBJECT,
	BRAIN_REGION,
	CORTICAL_AREA
}

var _selected_object: GenomeObject
var _type_of_selection: SELECTION_TYPE
var _scroll_genome_object: ScrollGenomeObjectSelector
var _selection_label: Label
var _select: Button

func _ready() -> void:
	super()
	_scroll_genome_object = _window_internals.get_node('ScrollGenomeObjectSelector')
	_selection_label = _window_internals.get_node('Label')
	_select = _window_internals.get_node('HBoxContainer/Select')
	_window_internals.get_node('HBoxContainer/Cancel').pressed.connect(close_window)
	_select.disabled = true
	

func setup(starting_region: BrainRegion, type_of_selection: SELECTION_TYPE) -> void:
	_setup_base_window("select_genome_object")
	_type_of_selection = type_of_selection
	_scroll_genome_object.setup_from_starting_region(starting_region)
	
	match(_type_of_selection):
		SELECTION_TYPE.GENOME_OBJECT:
			_selection_label.text = "Please select a target"
			_scroll_genome_object.region_selected.connect(_object_selected)
			_scroll_genome_object.area_selected.connect(_object_selected)
		SELECTION_TYPE.BRAIN_REGION:
			_selection_label.text = "Please select a Brain Region"
			_scroll_genome_object.region_selected.connect(_region_selected)
		SELECTION_TYPE.CORTICAL_AREA:
			_selection_label.text = "Please select a Cortical Area"
			_scroll_genome_object.area_selected.connect(_area_selected)
	

func _object_selected(object: GenomeObject) -> void:
	if object is BaseCorticalArea:
		_area_selected(object as BaseCorticalArea)
	if object is BrainRegion:
		_region_selected(object as BrainRegion)

func _area_selected(area: BaseCorticalArea) -> void:
	_selected_object = area
	_selection_label.text = "Selected cortical area %s" % area.name

func _region_selected(region: BrainRegion) -> void:
	_selected_object = region
	_selection_label.text = "Selected brain region %s" % region.name

