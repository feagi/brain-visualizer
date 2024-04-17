extends TextEdit
class_name UIMorphologyDescription

var _loaded_morphology: BaseMorphology

func load_morphology(morphology: BaseMorphology) -> void:
	if _loaded_morphology != null:
		if _loaded_morphology.retrieved_description.is_connected(_description_updated):
			_loaded_morphology.retrieved_description.disconnect(_description_updated)
	_loaded_morphology = morphology
	text = morphology.description
	#TODO enable editing?

func clear_morphology() -> void:
	_loaded_morphology = null
	text = ""
	editable = false

func _description_updated(new_description: StringName, _self_reference: BaseMorphology) -> void:
	text = new_description
