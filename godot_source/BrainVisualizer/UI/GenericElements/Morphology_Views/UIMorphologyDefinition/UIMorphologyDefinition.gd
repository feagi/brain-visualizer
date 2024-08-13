extends VBoxContainer
class_name UIMorphologyDefinition
## Intellegently shows the correct window segment representing the current morphology type

@export var title_enabled: bool = true
@export var type_enabled: bool = true
@export var editing_allowed_from_this_window: bool = true

var morphology_type_loaded: BaseMorphology.MORPHOLOGY_TYPE:
	get:  
		if _morphology_loaded != null:
			return _morphology_loaded.type
		else:
			return BaseMorphology.MORPHOLOGY_TYPE.NULL

var composite_view: ElementMorphologyCompositeView
var vectors_view: ElementMorphologyVectorsView
var patterns_view: ElementMorphologyPatternView

var _header_title: LineEdit
var _header_type: LineEdit
var _morphology_loaded: BaseMorphology

func _ready() -> void:
	$Header/HBoxContainer.visible = title_enabled
	$Header/HBoxContainer2.visible = type_enabled
	
	_header_title = $Header/HBoxContainer/Title_text
	_header_type = $Header/HBoxContainer2/Pattern_Text

	composite_view = $ElementMorphologyCompositeView
	vectors_view = $ElementMorphologyVectorsView
	patterns_view = $ElementMorphologyPatternView
	
	composite_view.setup(editing_allowed_from_this_window)
	vectors_view.setup(editing_allowed_from_this_window)
	patterns_view.setup(editing_allowed_from_this_window)
	
## Loads in a given morphology, and open the correct view to view that morphology type
func load_morphology(morphology: BaseMorphology) -> void:
	if _morphology_loaded != null:
		if _morphology_loaded.numerical_properties_updated.is_connected(_morphology_updated):
			_morphology_loaded.numerical_properties_updated.disconnect(_morphology_updated)


	size = Vector2(0,0) # Shrink
	_morphology_loaded = morphology
	_morphology_loaded.numerical_properties_updated.connect(_morphology_updated)
	_header_title.text = _morphology_loaded.name
	_header_type.text = BaseMorphology.MORPHOLOGY_TYPE.keys()[morphology.type]
	match morphology.type:
		BaseMorphology.MORPHOLOGY_TYPE.COMPOSITE:
			composite_view.visible = true
			vectors_view.visible = false
			patterns_view.visible = false

			composite_view.set_from_composite_morphology(morphology as CompositeMorphology)
		BaseMorphology.MORPHOLOGY_TYPE.VECTORS:
			composite_view.visible = false
			vectors_view.visible = true
			patterns_view.visible = false
			
			vectors_view.set_from_vector_morphology(morphology as VectorMorphology)
		BaseMorphology.MORPHOLOGY_TYPE.PATTERNS:
			composite_view.visible = false
			vectors_view.visible = false
			patterns_view.visible = true

			patterns_view.set_from_pattern_morphology(morphology as PatternMorphology)
		BaseMorphology.MORPHOLOGY_TYPE.FUNCTIONS:
			composite_view.visible = false
			vectors_view.visible = false
			patterns_view.visible = false
		_:
			composite_view.visible = false
			vectors_view.visible = false
			patterns_view.visible = false
			push_error("Null or unknown Morphology type loaded into UIMorphologyDefinition!")
	print("UIMorphologyDefinition finished loading in Morphology of name " + morphology.name)

## Loads in a blank morphology of given type
func load_blank_morphology(morphology_type: BaseMorphology.MORPHOLOGY_TYPE, morphology_internal_class: BaseMorphology.MORPHOLOGY_INTERNAL_CLASS = BaseMorphology.MORPHOLOGY_INTERNAL_CLASS.CUSTOM) -> void:
	print("UIMorphologyDefinition is loading in a blank morphology")
	match morphology_type:
		BaseMorphology.MORPHOLOGY_TYPE.COMPOSITE:
			var src_pattern: Array[Vector2i] = []
			load_morphology(CompositeMorphology.new("NO_NAME", true, morphology_internal_class, Vector3i(0,0,0), src_pattern, ""))
		BaseMorphology.MORPHOLOGY_TYPE.VECTORS:
			var vectors: Array[Vector3i] = []
			load_morphology(VectorMorphology.new("NO_NAME", true, morphology_internal_class, vectors))
		BaseMorphology.MORPHOLOGY_TYPE.PATTERNS:
			var patterns: Array[PatternVector3Pairs] = []
			load_morphology(PatternMorphology.new("NO_NAME", true, morphology_internal_class, patterns))
		_:
			load_morphology(NullMorphology.new())

func request_feagi_apply_morphology_settings(morphology_name: StringName) -> void:
	match _morphology_loaded.type:
		BaseMorphology.MORPHOLOGY_TYPE.COMPOSITE:
			return composite_view.request_feag_to_set_morphology(morphology_name)
		BaseMorphology.MORPHOLOGY_TYPE.VECTORS:
			return vectors_view.request_feag_to_set_morphology(morphology_name)
		BaseMorphology.MORPHOLOGY_TYPE.PATTERNS:
			return patterns_view.request_feag_to_set_morphology(morphology_name)
		_:
			push_error("Unable to send null or unknown type morphology!")


func _morphology_updated(_self_morphology: BaseMorphology) -> void:
	load_morphology(_morphology_loaded)

