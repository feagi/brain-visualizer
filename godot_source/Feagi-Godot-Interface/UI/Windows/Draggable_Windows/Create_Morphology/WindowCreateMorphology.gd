extends DraggableWindow
class_name WindowCreateMorphology



var _morphology_name: TextInput
var _radio_selector: ButtonGroup
var _button_create_morphology: TextButton_Element

var _composite: ElementMorphologyCompositeView
var _vectors: ElementMorphologyVectorsView
var _patterns: ElementMorphologyPatternView

func _ready():
	super._ready()
	_morphology_name = $Container/Name/Name
	_radio_selector = $Container/Type.button_group
	_button_create_morphology = $Container/CreateMorphologyButton
	
	_composite = $Container/ElementMorphologyCompositeView
	_vectors = $Container/ElementMorphologyVectorsView
	_patterns = $Container/ElementMorphologyPatternView


	_composite.visible = false
	_vectors.visible = false
	_patterns.visible = false

	print("initialized create morphology window")
	# ensure we have the latest list of morphologies
	if !get_parent() is Window:
		# we are not testing this individual scene
		FeagiRequests.refresh_morphology_list()

## Called from Window manager, to save previous position
func save_to_memory() -> Dictionary:
	return {
		"position": position,
	}

## Called from Window manager, to load previous position
func load_from_memory(previous_data: Dictionary) -> void:
	position = previous_data["position"]
	
func _on_type_button_pressed(_button_index: int, morphology_type: StringName) -> void:
	match morphology_type:
		&"Composite":
			_composite.visible = true
			_vectors.visible = false
			_patterns.visible = false
			return
		&"Vectors":
			# Vectors
			_composite.visible = false
			_vectors.visible = true
			_patterns.visible = false
			return
		&"Patterns":
			# Patterns
			_composite.visible = false
			_vectors.visible = false
			_patterns.visible = true
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
			FeagiRequests.request_create_morphology(_composite.get_as_composite_morphology(_morphology_name.text))
			return
		&"Vectors":
			FeagiRequests.request_create_morphology(_vectors.get_as_vector_morphology(_morphology_name.text))
			return
		&"Patterns":
			FeagiRequests.request_create_morphology(_patterns.get_as_pattern_morphology(_morphology_name.text))
			return
