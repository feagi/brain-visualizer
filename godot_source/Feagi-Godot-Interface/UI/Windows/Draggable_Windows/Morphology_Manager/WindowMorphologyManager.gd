extends GrowingPanel
class_name WindowMorphologyManager

var _main_container: HBoxContainer
var _morphology_scroll: MorphologyScroll
var _view_patterns: ElementMorphologyPatternView
var _view_composite: ElementMorphologyCompositeView
var _view_vectors: ElementMorphologyVectorsView
var _morphology_description: MorphologyManagerDescription

var _selected_morphology: Morphology

func _ready() -> void:
	super()
	_main_container = $Container
	_morphology_scroll = $Container/MorphologyScroll
	_view_patterns = $Container/Morphology_Details/ElementMorphologyPatternView
	_view_composite = $Container/Morphology_Details/ElementMorphologyCompositeView
	_view_vectors = $Container/Morphology_Details/ElementMorphologyVectorsView
	_morphology_description = $Container/Morphology_Details/Description


	_morphology_scroll.morphology_selected.connect(selected_morphology)
	FeagiCacheEvents.morphology_updated.connect(_retrieved_morphology_properties_from_feagi)


func selected_morphology(morphology: Morphology) -> void:
	_selected_morphology = morphology
	_toggle_between_morphology_type_views(morphology.type)
	FeagiRequests.refresh_morphology_properties(morphology.name)
	_morphology_description.update_image_with_morphology(morphology.name)
	_main_container.size = Vector2(0,0) # stupid sizing fix - by trying to force a zero size, the window will scale to its appropriate min size instead

# TODO function morphologies?
func _toggle_between_morphology_type_views(morphology_type: Morphology.MORPHOLOGY_TYPE) -> void:
	match(morphology_type):
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

# Connected via Apply Changes Button Signal
func send_updated_values_to_feagi() -> void:
	var morphology_to_send: Morphology
	match(_selected_morphology.type):
		Morphology.MORPHOLOGY_TYPE.PATTERNS:
			morphology_to_send = _view_patterns.get_as_pattern_morphology(_selected_morphology.name)
		Morphology.MORPHOLOGY_TYPE.VECTORS:
			morphology_to_send = _view_vectors.get_as_vector_morphology(_selected_morphology.name)
		Morphology.MORPHOLOGY_TYPE.COMPOSITE:
			morphology_to_send = _view_composite.get_as_composite_morphology(_selected_morphology.name)
		_:
			push_error("Unknown morphology type to request! Skipping!")
			return

	FeagiRequests.request_updating_morphology(morphology_to_send)


func _retrieved_morphology_properties_from_feagi(morphology: Morphology) -> void:
	if morphology.name != _selected_morphology.name:
		# we dont care if a non-selected morphology was updated
		# NOTE: we are comparing names instead of direct addresses to avoid reference shenaigans
		return
	
	print("morphology manager displaying updated info for morphology" + morphology.name)
	match(morphology.type):
		Morphology.MORPHOLOGY_TYPE.PATTERNS:
			_view_patterns.set_from_pattern_morphology(morphology)
		Morphology.MORPHOLOGY_TYPE.VECTORS:
			_view_vectors.set_from_vector_morphology(morphology)
		Morphology.MORPHOLOGY_TYPE.COMPOSITE:
			_view_composite.set_from_composite_morphology(morphology)
