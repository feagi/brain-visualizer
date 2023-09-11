extends GrowingPanel
class_name WindowMorphologyManager

var _morphology_scroll: MorphologyScroll
var _view_patterns: VBoxContainer
var _view_composite: VBoxContainer
var _view_vectors: VBoxContainer
var _morphology_description: VBoxContainer

func _ready() -> void:
	_morphology_scroll = $Container/MorphologyScroll
	_view_patterns = $Container/Morphology_Details/Patterns
	_view_composite = $Container/Morphology_Details/Composite
	_view_vectors = $Container/Morphology_Details/Vectors
	_morphology_description = $Container/Morphology_Details/Description

	_morphology_scroll.morphology_selected.connect(selected_morphology)




func selected_morphology(morphology: Morphology) -> void:
	_toggle_between_morphology_type_views(morphology.type)

	pass

# TODO function morphologies?
func _toggle_between_morphology_type_views(type: Morphology.MORPHOLOGY_TYPE) -> void:
	match(type):
		Morphology.MORPHOLOGY_TYPE.PATTERNS:
			_view_patterns.visible = true
			_view_composite.visible = false
			_view_vectors.visible = false
		Morphology.MORPHOLOGY_TYPE.VECTORS:
			_view_patterns.visible = false
			_view_composite.visible = false
			_view_vectors.visible = true
		Morphology.MORPHOLOGY_TYPE.COMPOSITE:
			_view_patterns.visible = false
			_view_composite.visible = true
			_view_vectors.visible = false
