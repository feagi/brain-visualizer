extends HBoxContainer
class_name PartWindowCreateMorphologyOptions

signal morphology_type_selected(type: Morphology.MORPHOLOGY_TYPE)

func _vector_select() -> void:
	morphology_type_selected.emit(Morphology.MORPHOLOGY_TYPE.VECTORS)

func _pattern_select() -> void:
	morphology_type_selected.emit(Morphology.MORPHOLOGY_TYPE.PATTERNS)
