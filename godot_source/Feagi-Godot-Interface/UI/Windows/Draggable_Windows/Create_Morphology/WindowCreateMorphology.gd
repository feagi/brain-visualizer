extends GrowingPanel
class_name WindowCreateMorphology



var _morphology_name: TextInput
var _radio_selector: ButtonGroup
var _section_vectors: VBoxContainer
var _section_patterns: VBoxContainer
var _button_create_morphology: TextButton_Element

var _composite: ElementMorphologyComposeView

var _vectors_vector_list: VBoxContainer

var _patterns_vector_list: VBoxContainer


func _ready():
	super._ready()
	_morphology_name = $Container/Name/Name
	_radio_selector = $Container/Type.button_group
	_section_vectors = $Container/Vectors
	_section_patterns = $Container/Patterns
	_button_create_morphology = $Container/CreateMorphologyButton
	
	_composite = $Container/ElementMorphologyCompositeView

	_vectors_vector_list = $Container/Vectors/Vectors/VBoxContainer

	_patterns_vector_list = $Container/Patterns/Patterns/VBoxContainer

	_composite.visible = false
	_section_vectors.visible = false
	_section_patterns.visible = false

	print("initialized create morphology window")
	# ensure we have the latest list of morphologies
	if !get_parent() is Window:
		# we are not testing this individual scene
		FeagiRequests.refresh_morphology_list()


	
func _on_type_button_pressed(_button_index: int, morphology_type: StringName) -> void:
	match morphology_type:
		&"Composite":
			_composite.visible = true
			_section_vectors.visible = false
			_section_patterns.visible = false
			return
		&"Vectors":
			# Vectors
			_composite.visible = false
			_section_vectors.visible = true
			_section_patterns.visible = false
			return
		&"Patterns":
			# Patterns
			_composite.visible = false
			_section_vectors.visible = false
			_section_patterns.visible = true
			return

func _on_create_morphology_pressed():

	if _morphology_name.text == "":

		#TODO notify that morphology name cannot be empty
		return
	
	
	if _morphology_name.text in FeagiCache.morphology_cache.available_morphologies.keys():
		#TODO notify user that they cannot use a morphology name that exists
		return
	
	if !_radio_selector.get_pressed_button():

		#TODO notify a type must be selected
		return

	var selected_morphology_type: StringName = _radio_selector.get_pressed_button().text # hacky but whatever
	
	if get_parent() is Window:
		# we are testing this individual scene, do not proceed
		print("Not Spawning Morphology due to testing individual scene")
		return

	match selected_morphology_type:
		&"Composite":
			FeagiRequests.request_creating_composite_morphology(_composite.get_as_composite_morphology(_morphology_name.text))
			return
		&"Vectors":
			var vectors: Array[Vector3i] = []
			for child in _vectors_vector_list.get_children():
				vectors.append(child.current_vector)
			FeagiRequests.request_creating_vector_morphology(_morphology_name.text, vectors)
			return
		&"Patterns":
			var pattern_pairs: Array[PatternVector3Pairs] = []
			for child in _patterns_vector_list.get_children():
				pattern_pairs.append(child.current_vector_pair)
			FeagiRequests.request_creating_pattern_morphology(_morphology_name.text, pattern_pairs)
			return
