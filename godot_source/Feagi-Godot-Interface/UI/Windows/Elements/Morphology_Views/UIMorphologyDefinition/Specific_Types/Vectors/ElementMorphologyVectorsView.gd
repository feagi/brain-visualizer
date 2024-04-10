extends VBoxContainer
class_name ElementMorphologyVectorsView

signal editability_changed(can_edit: bool) # used by scroll element children to update editability state

var _vectors_scroll: BaseScroll
var _add_vector: TextureButton
var _loaded_morphology: VectorMorphology
var _allow_editing_if_morphology_editable: bool

func _ready() -> void:
	_vectors_scroll = $Vectors
	_add_vector = $header/add_vector

func setup(allow_editing_if_morphology_editable: bool) -> void:
	_allow_editing_if_morphology_editable = allow_editing_if_morphology_editable

## Return current UI view as a [VectorMorphology] object
func get_as_vector_morphology(morphology_name: StringName, is_placeholder: bool = false) -> VectorMorphology:
	if _loaded_morphology != null:
		return VectorMorphology.new(morphology_name, is_placeholder, _loaded_morphology.internal_class, get_vector_array())
	# In the case of creating new morphologies, we would have not loaded in one, spo we cannot use the class from a loaded one
	# we can assume however, that any created morphology will always be of class Custom
	return VectorMorphology.new(morphology_name, is_placeholder, BaseMorphology.MORPHOLOGY_INTERNAL_CLASS.CUSTOM, get_vector_array())
	
	
## Overwrite the current UI view with a [VectorMorphology] object
func set_from_vector_morphology(vector_morphology: VectorMorphology) -> void:
	if _loaded_morphology != null:
		if _loaded_morphology.editability_changed.is_connected(_editability_updated):
			_loaded_morphology.editability_changed.disconnect(_editability_updated)
	_loaded_morphology = vector_morphology
	_loaded_morphology.editability_changed.connect(_editability_updated)
	var can_edit: bool = _determine_boolean_editability(vector_morphology.get_latest_known_editability())
	_add_vector.disabled = !can_edit
	_set_vector_array(vector_morphology.vectors, can_edit)

## Spawn in an additional row, usually for editing
func add_vector_row() -> void:
	# NOTE: "allow_editing" will always end up true, because the only time we can call this function is if we can edit...
	_vectors_scroll.spawn_list_item({
		"allow_editing_signal": editability_changed,
		"allow_editing": true,
		"vector": Vector3i(0,0,0)
	})

## Get the number of vectors
func get_number_rows() -> int:
	return _vectors_scroll.get_number_of_children()

func _editability_updated(new_editability: BaseMorphology.EDITABILITY) -> void:
	#NOTE: Due to how this is used in signals, we cannot simplify the input to a bool
	var can_edit: bool = _determine_boolean_editability(new_editability)
	_add_vector.disabled = !can_edit
	editability_changed.emit(can_edit)
	
func _determine_boolean_editability(editability: BaseMorphology.EDITABILITY) -> bool:
	if !_allow_editing_if_morphology_editable:
		return false
	match editability:
		BaseMorphology.EDITABILITY.IS_EDITABLE:
			return true
		BaseMorphology.EDITABILITY.WARNING_EDITABLE_USED:
			return true
		_: # any thing else
			return false

func get_vector_array() -> Array[Vector3i]:
	var _vectors: Array[Vector3i] = []
	for child in _vectors_scroll.get_children_as_list():
		_vectors.append(child.current_vector)
	return _vectors

func _set_vector_array(input_vectors: Array[Vector3i], is_morphology_editable: bool) -> void:
	_vectors_scroll.remove_all_children()
	for vector: Vector3i in input_vectors:
		_vectors_scroll.spawn_list_item(
			{
				"allow_editing_signal": editability_changed,
				"allow_editing": is_morphology_editable,
				"vector": vector
			}
		)
