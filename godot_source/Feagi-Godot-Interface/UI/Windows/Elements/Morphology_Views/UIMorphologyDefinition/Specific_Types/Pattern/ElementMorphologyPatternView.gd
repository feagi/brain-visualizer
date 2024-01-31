extends VBoxContainer
class_name ElementMorphologyPatternView


var _pattern_pair_scroll: BaseScroll
var _pattern_pair_list: VBoxContainer
var _add_pattern: TextureButton
var _is_UI_editable: bool
var _is_morphology_editable: bool = true # in case no morphology is defined, default to true
var _subheader: HBoxContainer

func _ready() -> void:
	_pattern_pair_scroll = $Patterns
	_pattern_pair_list = $Patterns/VBoxContainer
	_add_pattern = $header/add_vector
	_subheader = $subheader
	_update_subheader_positions()

func setup(allow_editing_if_morphology_editable: bool) -> void:
	_is_UI_editable = allow_editing_if_morphology_editable

## Return current UI view as a [PatternMorphology] object
func get_as_pattern_morphology(morphology_name: StringName, is_placeholder: bool = false) -> PatternMorphology:
	return PatternMorphology.new(morphology_name, is_placeholder, _get_pattern_pair_array())
	
## Overwrite the current UI view with a [PatternMorphology] object
func set_from_pattern_morphology(pattern_morphology: PatternMorphology) -> void:
	_is_morphology_editable = pattern_morphology.is_user_editable
	_add_pattern.disabled = !(_is_UI_editable && pattern_morphology.is_user_editable)
	_set_pattern_pair_array(pattern_morphology.patterns, pattern_morphology.is_user_editable && _is_UI_editable)

## Spawn in an additional row, usually for editing
func add_pattern_pair_row() -> void:
	# NOTE: Theoretically, "editable" will always end up true, because the only time we can call this function is if we can edit...
	var pattern_pair: PatternVector3Pairs = PatternVector3Pairs.create_empty()
	_pattern_pair_scroll.spawn_list_item({
		"editable": _is_morphology_editable && _is_UI_editable,
		"vectorPair": pattern_pair
	})

func _get_pattern_pair_array() -> Array[PatternVector3Pairs]:
	var pairs: Array[PatternVector3Pairs] = []
	for child in _pattern_pair_list.get_children():
		pairs.append(child.current_vector_pair)
	return pairs

func _set_pattern_pair_array(input_pattern_pairs: Array[PatternVector3Pairs], is_editable: bool) -> void:
	_pattern_pair_scroll.remove_all_children()
	for pattern_pair in input_pattern_pairs:
		_pattern_pair_scroll.spawn_list_item({
			"editable": is_editable,
			"vectorPair": pattern_pair
		})

func _update_subheader_positions() -> void:
	var gap1: Control = $subheader/initial_gap
	var gap2: Control = $subheader/end_gap
	
	var new_width: int = int( (size.x - _subheader.size.x) / 2.0 )
	gap1.custom_minimum_size.x = new_width
	gap2.custom_minimum_size.x = new_width
