extends BaseDraggableWindow
class_name WindowCreateMorphology

const HEADER_CHOOSE_TYPE: StringName = "Select Connectivity Rule Type:"
const HEADER_VECTOR: StringName = "Adding Vector Connectivity Rule"
const HEADER_PATTERN: StringName = "Adding Pattern Connectivity Rule"
const NAME_VECTOR: StringName = "Vector Title:"
const NAME_PATTERN: StringName = "Pattern Title:"
const DESCRIPTION_VECTOR: StringName = "Vector Description:"
const DESCRIPTION_PATTERN: StringName = "Pattern Description:"

var _header_label: Label
var _options: PartWindowCreateMorphologyOptions
var _name_holder: HBoxContainer
var _morphology_name: TextInput
var _morphology_name_header: Label
var _composite: ElementMorphologyCompositeView
var _vectors: ElementMorphologyVectorsView
var _patterns: ElementMorphologyPatternView
var _morphology_description: TextEdit
var _description_label: Label
var _bottom_buttons: HBoxContainer

var _selected_morphology_type: Morphology.MORPHOLOGY_TYPE = Morphology.MORPHOLOGY_TYPE.NULL



func _ready():
	super()
	_header_label = _window_internals.get_node("Header")
	_options = _window_internals.get_node("Options")
	_name_holder = _window_internals.get_node("Name")
	_morphology_name_header = _window_internals.get_node("Name/Label")
	_morphology_name = _window_internals.get_node("Name/Name")
	_vectors = _window_internals.get_node("ElementMorphologyVectorsView")
	_patterns = _window_internals.get_node("ElementMorphologyPatternView")
	_composite = _window_internals.get_node("ElementMorphologyCompositeView")
	_description_label = _window_internals.get_node("Description")
	_morphology_description = _window_internals.get_node("Description_text")
	_bottom_buttons = _window_internals.get_node("Buttons")
	FeagiRequests.refresh_morphology_list()
	
	_composite.setup(true)
	_vectors.setup(true)
	_patterns.setup(true)
	
	
	print("initialized create morphology window")

func setup() -> void:
	_setup_base_window("create_morphology")
	

func _step_1_pick_type():
	_options.visible = true
	_composite.visible = false
	_vectors.visible = false
	_patterns.visible = false
	_name_holder.visible = false
	_description_label.visible = false
	_morphology_description.visible = false
	_bottom_buttons.visible = false
	
	_header_label.text = HEADER_CHOOSE_TYPE
	shrink_window()

func _step_2_input_properties(morphology_type: Morphology.MORPHOLOGY_TYPE):
	_selected_morphology_type = morphology_type
	_options.visible = false
	_name_holder.visible = true
	_description_label.visible = true
	_morphology_description.visible = true
	_bottom_buttons.visible = true
	
	match morphology_type:
		Morphology.MORPHOLOGY_TYPE.VECTORS:
			_composite.visible = false
			_vectors.visible = true
			_patterns.visible = false
			_header_label.text = HEADER_VECTOR
			_morphology_name_header.text = NAME_VECTOR
			_description_label.text = DESCRIPTION_VECTOR
		Morphology.MORPHOLOGY_TYPE.PATTERNS:
			_composite.visible = false
			_vectors.visible = false
			_patterns.visible = true
			_header_label.text = HEADER_PATTERN
			_morphology_name_header.text = NAME_PATTERN
			_description_label.text = DESCRIPTION_PATTERN
			
	shrink_window()

func _on_create_morphology_pressed():

	if _morphology_name.text == "":
		#TODO
		return
	
	if _morphology_name.text in FeagiCache.morphology_cache.available_morphologies.keys():
		#TODO
		return

	match _selected_morphology_type:
		Morphology.MORPHOLOGY_TYPE.VECTORS:
			FeagiRequests.request_create_morphology(_vectors.get_as_vector_morphology(_morphology_name.text))	
		Morphology.MORPHOLOGY_TYPE.PATTERNS:
			FeagiRequests.request_create_morphology(_patterns.get_as_pattern_morphology(_morphology_name.text))
	
	close_window()
