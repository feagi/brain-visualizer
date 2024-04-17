extends HBoxContainer
class_name PartWindowCreateMorphologyOptions

signal morphology_type_selected(type: BaseMorphology.MORPHOLOGY_TYPE)

func _vector_select() -> void:
	morphology_type_selected.emit(BaseMorphology.MORPHOLOGY_TYPE.VECTORS)

func _pattern_select() -> void:
	morphology_type_selected.emit(BaseMorphology.MORPHOLOGY_TYPE.PATTERNS)
