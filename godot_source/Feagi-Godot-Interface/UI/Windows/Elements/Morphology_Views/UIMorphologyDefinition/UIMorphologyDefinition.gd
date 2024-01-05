extends VBoxContainer
class_name UIMorphologyDefinition
## Intellegently shows the correct window segment representing the current morphology type

@export var title_enabled: bool = true
@export var type_enabled: bool = true
@export var morphology_editable: bool = true

var morphology_type_loaded: Morphology.MORPHOLOGY_TYPE:
	get: return _type_loaded

var composite_view: ElementMorphologyCompositeView
var vectors_view: ElementMorphologyVectorsView
var patterns_view: ElementMorphologyPatternView

var _header_title: LineEdit
var _header_type: LineEdit
var _type_loaded: Morphology.MORPHOLOGY_TYPE

func _ready() -> void:
	$Header/HBoxContainer.enabled = title_enabled
	$Header/HBoxContainer2.enabled = type_enabled
	
	_header_title = $Header/HBoxContainer/Title_text
	_header_type = $Header/HBoxContainer2/Pattern_Text

	composite_view = $ElementMorphologyCompositeView
	vectors_view = $ElementMorphologyVectorsView
	patterns_view = $ElementMorphologyPatternView
	
## Loads in a given morphology, and open the correct view to view that morphology type
func load_morphology(morphology: Morphology, update_FEAGI_cache: bool = true) -> void:
	_header_title.text = morphology.name
	if _type_loaded != morphology.type:
		# We are changing size, shrink as much as possible
		size = Vector2(0,0)
	_type_loaded = morphology.type
	_header_type.text = Morphology.MORPHOLOGY_TYPE.keys()[morphology.type]
	match morphology.type:
		Morphology.MORPHOLOGY_TYPE.COMPOSITE:
			composite_view.visible = true
			vectors_view.visible = false
			patterns_view.visible = false

			composite_view.set_from_composite_morphology(morphology as CompositeMorphology)
		Morphology.MORPHOLOGY_TYPE.VECTORS:
			composite_view.visible = false
			vectors_view.visible = true
			patterns_view.visible = false
			
			vectors_view.set_from_vector_morphology(morphology as VectorMorphology)
		Morphology.MORPHOLOGY_TYPE.PATTERNS:
			composite_view.visible = false
			vectors_view.visible = false
			patterns_view.visible = true

			patterns_view.set_from_pattern_morphology(morphology as PatternMorphology)
		Morphology.MORPHOLOGY_TYPE.FUNCTIONS:
			composite_view.visible = false
			vectors_view.visible = false
			patterns_view.visible = false
			VisConfig.UI_manager.make_notification("Function morphology editing is not supported at this time!", SingleNotification.NOTIFICATION_TYPE.WARNING)
		_:
			composite_view.visible = false
			vectors_view.visible = false
			patterns_view.visible = false
			push_error("Null or unknown Morphology type loaded into UIMorphologyDefinition!")
	print("UIMorphologyDefinition finished loading in Morphology of name " + morphology.name)
	if update_FEAGI_cache:
		FeagiRequests.refresh_morphology_properties(morphology.name)

## Loads in a blank morphology of given type
func load_blank_morphology(morphology_type: Morphology.MORPHOLOGY_TYPE) -> void:
	print("UIMorphologyDefinition is loading in a blank morphology")
	match morphology_type:
		Morphology.MORPHOLOGY_TYPE.COMPOSITE:
			var src_pattern: Array[Vector2i] = []
			load_morphology(CompositeMorphology.new("NO_NAME", true, Vector3i(0,0,0), src_pattern, ""))
		Morphology.MORPHOLOGY_TYPE.VECTORS:
			var vectors: Array[Vector3i] = []
			load_morphology(VectorMorphology.new("NO_NAME", true, vectors))
		Morphology.MORPHOLOGY_TYPE.PATTERNS:
			var patterns: Array[PatternVector3Pairs] = []
			load_morphology(PatternMorphology.new("NO_NAME", true, patterns))
		_:
			load_morphology(NullMorphology.new())
	
## Retrieves the current UI view as a morphology of its type
func retrieve_morphology(morphology_name: StringName, _morphology_details: StringName) -> Morphology:
	## TODO make use of morphology details - Requires FEAGI support first
	match _type_loaded:
		Morphology.MORPHOLOGY_TYPE.COMPOSITE:
			return composite_view.get_as_composite_morphology(morphology_name)
		Morphology.MORPHOLOGY_TYPE.VECTORS:
			return vectors_view.get_as_vector_morphology(morphology_name)
		Morphology.MORPHOLOGY_TYPE.PATTERNS:
			return patterns_view.get_as_pattern_morphology(morphology_name)
		_:
			push_error("Unable to retrieve null or unknown type morphology. Return Null Morphology Instead...")
			return NullMorphology.new()

