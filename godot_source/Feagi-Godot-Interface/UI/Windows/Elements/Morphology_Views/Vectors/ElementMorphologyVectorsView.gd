extends VBoxContainer
class_name ElementMorphologyVectorsView

var _vectors_scroll: BaseScroll
var _vectors_vector_list: VBoxContainer
var _is_editable: bool = true

var vectors: Array[Vector3i]:
	get:
		return _get_vector_array()
	set(v):
		_set_vector_array(v)
		

func _ready() -> void:
	_vectors_scroll = $Vectors
	_vectors_vector_list = $Vectors/VBoxContainer

## Return current UI view as a [VectorMorphology] object
func get_as_vector_morphology(morphology_name: StringName, is_placeholder: bool = false) -> VectorMorphology:
	return VectorMorphology.new(morphology_name, is_placeholder, vectors)
	
## Overwrite the current UI view with a [VectorMorphology] object
func set_from_vector_morphology(vector_morphology: VectorMorphology) -> void:
	vectors = vector_morphology.vectors

## Defines if UI view is editable. NOTE: ONLY WORKS ON '_ready' OR AFTER A UI CLEAR
func set_editable(is_editable: bool) -> void:
	_is_editable = is_editable
	$labels/deletegap.visible = is_editable


func _get_vector_array() -> Array[Vector3i]:
	var _vectors: Array[Vector3i] = []
	for child in _vectors_vector_list.get_children():
		_vectors.append(child.current_vector)
	return _vectors


func _set_vector_array(input_vectors: Array[Vector3i]) -> void:
	_vectors_scroll.remove_all_children()
	for vector in input_vectors:
		_vectors_scroll.spawn_list_item({
			"editable": _is_editable,
			"vector": vector})

