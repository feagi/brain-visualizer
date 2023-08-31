extends GrowingPanel
class_name WindowCreateMorphology



var _morphology_name: TextInput
var _radio_selector: ButtonGroup
var _section_composite: VBoxContainer
var _section_vectors: VBoxContainer
var _section_patterns: VBoxContainer
var _button_create_morphology: TextButton_Element

var _composite_seed: Vector3iField
var _composite_patternX: Vector2iField
var _composite_patternY: Vector2iField
var _composite_patternZ: Vector2iField
var _composite_mapped_morphology: DropDown

var _vectors_vector_list: BaseScroll

var _patterns_vector_list: BaseScroll


func _ready():
	super._ready()
	_morphology_name = $Container/Name/Name
	_radio_selector = $Container/Type.button_group
	_section_composite = $Container/Composite
	_section_vectors = $Container/Vectors
	_section_patterns = $Container/Patterns
	_button_create_morphology = $Container/CreateMorphologyButton
	
	_composite_seed = $Container/Composite/Seed/Seed_Vector
	_composite_patternX = $Container/Composite/Patterns/X/X
	_composite_patternY = $Container/Composite/Patterns/Y/Y
	_composite_patternZ = $Container/Composite/Patterns/Z/Z
	_composite_mapped_morphology = $Container/Composite/mapper/Available_Morphologies

	_vectors_vector_list = $Container/Vectors/Vectors

	_patterns_vector_list = $Container/Patterns/Patterns

	_section_composite.visible = false
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
			_section_composite.visible = true
			_section_vectors.visible = false
			_section_patterns.visible = false
			return
		&"Vectors":
			# Vectors
			_section_composite.visible = false
			_section_vectors.visible = true
			_section_patterns.visible = false
			return
		&"Patterns":
			# Patterns
			_section_composite.visible = false
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
			var source_seed: Vector3i = _composite_seed.current_vector
			var patternX: Vector2i = _composite_patternX.current_vector
			var patternY: Vector2i = _composite_patternY.current_vector
			var patternZ: Vector2i = _composite_patternZ.current_vector
			var patterns: Array[Vector2i] = [patternX, patternY, patternZ]
			FeagiRequests.request_creating_composite_morphology(_morphology_name.text, source_seed, patterns)
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
