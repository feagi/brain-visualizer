extends VBoxContainer
class_name ElementMorphologyVectorsView

var _vectors_scroll: BaseScroll
var _vectors_vector_list: VBoxContainer
var _add_vector: TextureButton
var _is_UI_editable: bool
var _is_morphology_editable: bool = true # in case no morphology is defined, default to true


func _ready() -> void:
	_vectors_scroll = $Vectors
	_vectors_vector_list = $Vectors/VBoxContainer
	_add_vector = $header/add_vector

func setup(allow_editing_if_morphology_editable: bool) -> void:
	_is_UI_editable = allow_editing_if_morphology_editable

## Return current UI view as a [VectorMorphology] object
func get_as_vector_morphology(morphology_name: StringName, is_placeholder: bool = false) -> VectorMorphology:
	return VectorMorphology.new(morphology_name, is_placeholder, _get_vector_array())
	
## Overwrite the current UI view with a [VectorMorphology] object
func set_from_vector_morphology(vector_morphology: VectorMorphology) -> void:
	_is_morphology_editable = vector_morphology.is_user_editable
	_add_vector.disabled = !(_is_UI_editable && vector_morphology.is_user_editable)
	_set_vector_array(vector_morphology.vectors, vector_morphology.is_user_editable && _is_UI_editable)

## Spawn in an additional row, usually for editing
func add_vector_row() -> void:
	# NOTE: Theoretically, "editable" will always end up true, because the only time we can call this function is if we can edit...
	_vectors_scroll.spawn_list_item({
		"editable": _is_morphology_editable && _is_UI_editable,
		"vector": Vector3i(0,0,0)
	})

func _get_vector_array() -> Array[Vector3i]:
	var _vectors: Array[Vector3i] = []
	for child in _vectors_vector_list.get_children():
		_vectors.append(child.current_vector)
	return _vectors


func _set_vector_array(input_vectors: Array[Vector3i], is_morphology_editable: bool) -> void:
	_vectors_scroll.remove_all_children()
	for vector in input_vectors:
		_vectors_scroll.spawn_list_item({
			"editable": is_morphology_editable,
			"vector": vector})
