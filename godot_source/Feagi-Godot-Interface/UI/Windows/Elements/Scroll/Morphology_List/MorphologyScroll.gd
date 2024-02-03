extends GenericTextIDScroll
class_name MorphologyScroll
## Keeps up to date with the morphology listing to show a scroll list of all morphologies

signal morphology_selected(morphology: Morphology)

@export var load_morphologies_on_load: bool = true
@export var call_for_morphology_reload_on_load: bool = true

func _ready():
	super()
	item_selected.connect(_morphology_button_pressed)
	FeagiCacheEvents.morphology_removed.connect(_respond_to_deleted_morphology)
	FeagiCacheEvents.morphology_added.connect(_respond_to_added_morphology)
	if call_for_morphology_reload_on_load:
		FeagiRequests.refresh_morphology_list()
	if load_morphologies_on_load:
		repopulate_from_cache()

## Clears list, then loads morphology list from FeagiCache
func repopulate_from_cache() -> void:
	delete_all()
	for morphology in FeagiCache.morphology_cache.available_morphologies.values():
		append_single_item(morphology, morphology.name)

## Sets the morphologies froma  manual list
func set_morphologies(morphologies: Array[Morphology]) -> void:
	delete_all()
	for morphology in morphologies:
		append_single_item(morphology, morphology.name)

## Manually set the selected morphology through code. Causes the button to emit the selected signal
func select_morphology(morphology: Morphology) -> void:
	# This is essentially a pointless proxy, only existing for convinient naming purposes
	set_selected(morphology)

## User selected morpholgy from the list
func _morphology_button_pressed(morphology_selection: Morphology) -> void:
	# This is essentially a pointless proxy, only existing for convinient naming purposes
	morphology_selected.emit(morphology_selection)


func _respond_to_deleted_morphology(morphology: Morphology) -> void:
	remove_by_ID(morphology)


func _respond_to_added_morphology(morphology: Morphology) -> void:
	append_single_item(morphology, morphology.name)
