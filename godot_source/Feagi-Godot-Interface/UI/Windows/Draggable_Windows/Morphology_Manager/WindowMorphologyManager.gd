extends DraggableWindow
class_name WindowMorphologyManager

var _main_container: BoxContainer
var _morphology_scroll: MorphologyScroll
var _smart_morphology_view: SmartMorphologyView
var _morphology_generic_details: MorphologyGenericDetails
var _delete_morphology_button: TextureButton

var _selected_morphology: Morphology

func _ready() -> void:
	super()
	_main_container = $Container
	_morphology_scroll = $Container/MorphologyScroll
	_smart_morphology_view = $Container/SmartMorphologyView
	_morphology_generic_details = $Container/DetailsAndButtons/MorphologyGenericDetails
	_delete_morphology_button = $Container/DetailsAndButtons/Delete
	_morphology_scroll.morphology_selected.connect(load_morphology)
	FeagiCacheEvents.morphology_updated.connect(morphology_updated_from_FEAGI)

## Loads in a given morphology to the window panel
func load_morphology(morphology: Morphology, update_FEAGI_cache: bool = true) -> void:
	print("UI: WINDOWS: MORPHOLOGY_MANAGER: User loading Morphology " + morphology.name)
	_selected_morphology = morphology
	_smart_morphology_view.load_in_morphology(morphology)
	_morphology_generic_details.load_in_morphology(morphology)
	_automatically_set_delete_button_availability()
	if update_FEAGI_cache:
		FeagiRequests.refresh_morphology_properties(morphology.name)

func set_selected_morphology(morphology: Morphology) -> void:
	_morphology_scroll.select_morphology(morphology) # fires back here

## FEAGI sent back new morphlogy values. Update
func morphology_updated_from_FEAGI(updated_morphology: Morphology) -> void:
	if _selected_morphology.name != updated_morphology.name:
		return
	load_morphology(updated_morphology, false)

## User selected 'Ignore' Button, revert to cached morphology
func reload_morphology():
	print("UI: WINDOWS: MORPHOLOGY_MANAGER: User Reloading current morphology")
	load_morphology(_selected_morphology, false)

## User is requesting submission of new morphology settings via Update button
func send_updated_values_to_feagi() -> void:
	print("UI: WINDOWS: MORPHOLOGY_MANAGER: User sending values for " + _selected_morphology.name)
	var morphology_to_send: Morphology = _smart_morphology_view.retrieve_morphology(_selected_morphology.name, _morphology_generic_details.details_text)
	FeagiRequests.request_updating_morphology(morphology_to_send)

func _automatically_set_delete_button_availability() -> void:
	_delete_morphology_button.disabled = (!_selected_morphology.is_user_editable) or (_selected_morphology.is_being_used)

func _request_delete_selected_morphology() -> void:
	if _selected_morphology == null:
		return
	FeagiRequests.request_delete_morphology(_selected_morphology)
	
	

