extends PanelContainerButton
class_name GenomeObjectSelectorButton

signal object_selected(object: GenomeObject)

var current_selected: GenomeObject:
	get: return _current_selected

var _current_selected: GenomeObject
var _selection_allowed: GenomeObject.SINGLE_MAKEUP
var _cortical_icon: TextureRect
var _region_icon: TextureRect
var _text: Label

func _ready() -> void:
	super()
	_cortical_icon = $MarginContainer/HBoxContainer/IconCortical
	_region_icon = $MarginContainer/HBoxContainer/IconRegion
	_text = $MarginContainer/HBoxContainer/Label

#NOTE: Yes you can init with a type not allowed for the user to select
func setup(genome_object: GenomeObject, restricted_to: GenomeObject.SINGLE_MAKEUP) -> void:
	_selection_allowed = restricted_to
	_current_selected = genome_object
	_switch_button_visuals(genome_object)
	pressed.connect(_button_pressed)

func update_selection(genome_object: GenomeObject) -> void:
	if !GenomeObject.is_given_object_covered_by_makeup(genome_object, _selection_allowed):
		push_error("UI: Invalid GenomeObject type selected for button given restriction! Ignoring!")
		return
	_current_selected = genome_object
	_switch_button_visuals(genome_object)
	object_selected.emit(_current_selected)



func _button_pressed() -> void:
	var window: WindowSelectGenomeObject = BV.WM.spawn_select_genome_object(FeagiCore.feagi_local_cache.brain_regions.get_root_region(), _selection_allowed)
	window.user_selected_object_final.connect(update_selection)

func _switch_button_visuals(selected: GenomeObject) -> void:
	var type: GenomeObject.SINGLE_MAKEUP = GenomeObject.get_makeup_of_single_object(selected)
	_cortical_icon.visible = type == GenomeObject.SINGLE_MAKEUP.SINGLE_CORTICAL_AREA
	_region_icon.visible = type == GenomeObject.SINGLE_MAKEUP.SINGLE_BRAIN_REGION
	if type == GenomeObject.SINGLE_MAKEUP.UNKNOWN:
		_text.text = "None Selected"
	else:
		_text.text = selected.friendly_name

