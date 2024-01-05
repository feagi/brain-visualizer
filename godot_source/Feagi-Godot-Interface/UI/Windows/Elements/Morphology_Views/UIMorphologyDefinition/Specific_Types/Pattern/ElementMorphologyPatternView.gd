extends VBoxContainer
class_name ElementMorphologyPatternView

var pattern_pairs: Array[PatternVector3Pairs]:
	get:
		return _get_pattern_pair_array()
	set(v):
		_set_pattern_pair_array(v)

var _pattern_pair_scroll: BaseScroll
var _pattern_pair_list: VBoxContainer
var _is_editable: bool = true

func _ready() -> void:
	_pattern_pair_scroll = $Patterns
	_pattern_pair_list = $Patterns/VBoxContainer

## Return current UI view as a [PatternMorphology] object
func get_as_pattern_morphology(morphology_name: StringName, is_placeholder: bool = false) -> PatternMorphology:
	return PatternMorphology.new(morphology_name, is_placeholder, pattern_pairs)
	
## Overwrite the current UI view with a [PatternMorphology] object
func set_from_pattern_morphology(pattern_morphology: PatternMorphology) -> void:
	set_editable(pattern_morphology.is_user_editable)
	pattern_pairs = pattern_morphology.patterns

## Defines if UI view is editable. NOTE: ONLY WORKS ON '_ready' OR AFTER A UI CLEAR
func set_editable(is_field_editable: bool) -> void:
	_is_editable = is_field_editable

func add_pattern_pair_row() -> void:
	var pattern_pair: PatternVector3Pairs = PatternVector3Pairs.create_empty()
	_pattern_pair_scroll.spawn_list_item({
		"editable": _is_editable,
		"vectorPair": pattern_pair
	})

func _get_pattern_pair_array() -> Array[PatternVector3Pairs]:
	var pairs: Array[PatternVector3Pairs] = []
	for child in _pattern_pair_list.get_children():
		pairs.append(child.current_vector_pair)
	return pairs


func _set_pattern_pair_array(input_pattern_pairs: Array[PatternVector3Pairs]) -> void:
	_pattern_pair_scroll.remove_all_children()
	for pattern_pair in input_pattern_pairs:
		_pattern_pair_scroll.spawn_list_item({
			"editable": _is_editable,
			"vectorPair": pattern_pair
		})

	

