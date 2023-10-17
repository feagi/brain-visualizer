extends VBoxContainer
class_name ElementMorphologyVectorsView

var _vectors_scroll: BaseScroll
var _vectors_vector_list: VBoxContainer
var _is_editable: bool = true

var vectors: Array[Vector3i]:
	get:
		var _vectors: Array[Vector3i] = []
		for child in _vectors_vector_list.get_children():
			_vectors.append(child.current_vector)
		return _vectors
	set(v):
		_set_vector_array(v)
		

func _ready() -> void:
	_vectors_scroll = $Vectors
	_vectors_vector_list = $Vectors/VBoxContainer

func get_as_vector_morphology(morphology_name: StringName, is_placeholder: bool = false) -> VectorMorphology:
	return VectorMorphology.new(morphology_name, is_placeholder, vectors)
	
func set_from_vector_morphology(vector_morphology: VectorMorphology) -> void:
	vectors = vector_morphology.vectors

func set_editable(is_editable: bool) -> void:
	_is_editable = is_editable
	$labels/deletegap.visible = is_editable

func _set_vector_array(input_vectors: Array[Vector3i]) -> void:
	_vectors_scroll.remove_all_children()
	for vector in input_vectors:
		_add_vector_row(vector)

func _add_vector_row(input_vector: Vector3i = Vector3i(0,0,0)) -> void:
	var specific_vector_row: Node = _vectors_scroll.spawn_list_item({
		"editable": _is_editable,
		"vector": input_vector})
	
	
