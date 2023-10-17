extends DraggableWindow
class_name WindowMorphologyManager

var _main_container: BoxContainer
var _morphology_scroll: MorphologyScroll
var _smart_morphology_view: SmartMorphologyView
var _morphology_generic_details: MorphologyGenericDetails

var _selected_morphology: Morphology

func _ready() -> void:
	super()
	_main_container = $Container
	_morphology_scroll = $Container/MorphologyScroll
	_smart_morphology_view = $Container/SmartMorphologyView
	_morphology_generic_details = $Container/MorphologyGenericDetails
	
	_morphology_scroll.morphology_selected.connect(load_morphology)
	FeagiCacheEvents.morphology_updated.connect(morphology_updated_from_FEAGI)

## Loads in a given morphology to the window panel
func load_morphology(morphology: Morphology, update_FEAGI_cache: bool = true) -> void:
	_selected_morphology = morphology
	_smart_morphology_view.load_in_morphology(morphology)
	_morphology_generic_details.load_in_morphology(morphology)
	if update_FEAGI_cache:
		FeagiRequests.refresh_morphology_properties(morphology.name)

func morphology_updated_from_FEAGI(updated_morphology: Morphology) -> void:
	if _selected_morphology.name != updated_morphology.name:
		return
	load_morphology(updated_morphology, false)



# Connected via Apply Changes Button Signal
#func send_updated_values_to_feagi() -> void:
	
	#var morphology_to_send: Morphology = _smart_morphology_view.retrieve_morphology()

	#FeagiRequests.request_updating_morphology(morphology_to_send)

## Called from Window manager, to save previous position
func save_to_memory() -> Dictionary:
	return {
		"position": position,
	}

## Called from Window manager, to load previous position
func load_from_memory(previous_data: Dictionary) -> void:
	position = previous_data["position"]



