extends VBoxContainer
class_name SmartMorphologyView
## Intellegently shows the correct window segment representing the current morphology type

@export var header_enabled: bool = true
@export var morphology_editable: bool = true

var composite_view: ElementMorphologyCompositeView
var vectors_view: ElementMorphologyVectorsView

var _header: VBoxContainer
var _header_title: LineEdit
var _header_type: LineEdit

func _ready() -> void:
	_header = $Header
	_header_title = $Header/HBoxContainer/Title_text
	_header_type = $Header/HBoxContainer2/Pattern_Text
	_header.visible = header_enabled

	composite_view = $ElementMorphologyCompositeView
	vectors_view = $ElementMorphologyVectorsView

	composite_view.is_editable(morphology_editable)
	vectors_view.is_editable(morphology_editable)
	

func load_in_morphology(morphology: Morphology) -> void:
	_header_title.text = morphology.name
	match morphology.type:
		Morphology.MORPHOLOGY_TYPE.NULL:
			_header_type.text = "NULL"
			composite_view.visible = false
			vectors_view.visible = false
			push_error("Null Morphology loaded into SmartMorphologyView!")
		Morphology.MORPHOLOGY_TYPE.COMPOSITE:
			_header_type.text = "Composite"
			composite_view.visible = true
			vectors_view.visible = false

			composite_view.set_from_composite_morphology(morphology as CompositeMorphology)
		Morphology.MORPHOLOGY_TYPE.VECTORS:
			_header_type.text = "Vector"
			composite_view.visible = false
			vectors_view.visible = true
			
			vectors_view.set_from_vector_morphology(morphology as VectorMorphology)

func retrieve_morphology(morphology_name: StringName, morphology_details: StringName) -> Morphology:
	pass


