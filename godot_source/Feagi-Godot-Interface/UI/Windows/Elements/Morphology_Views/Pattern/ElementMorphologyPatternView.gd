extends VBoxContainer
class_name ElementMorphologyPatternView

var _pattern_pair_scroll: BaseScroll
var _pattern_pair_list: VBoxContainer

var pattern_pairs: Array[PatternVector3Pairs]:
	get:
		var pairs: Array[PatternVector3Pairs] = []
		for child in _pattern_pair_list.get_children():
			pairs.append(child.current_vector_pair)
		return pairs
	set(v):
		_set_pattern_pair_array(v)

func _ready() -> void:
	_pattern_pair_scroll = $Patterns
	_pattern_pair_list = $Patterns/VBoxContainer

func get_as_pattern_morphology(morphology_name: StringName, is_placeholder: bool = false) -> PatternMorphology:
	return PatternMorphology.new(morphology_name, is_placeholder, pattern_pairs)
	
func set_from_pattern_morphology(pattern_morphology: PatternMorphology) -> void:
	pattern_pairs = pattern_morphology.patterns

func _set_pattern_pair_array(input_pattern_pairs: Array[PatternVector3Pairs]) -> void:
	_pattern_pair_scroll.remove_all_children()
	for pattern_pair in input_pattern_pairs:
		var specific_pattern_pair_row: Node = _pattern_pair_scroll.spawn_list_item()
		specific_pattern_pair_row.current_vector_pair = pattern_pair
	

