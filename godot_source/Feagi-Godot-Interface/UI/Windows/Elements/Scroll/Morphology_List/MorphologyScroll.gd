extends GenericTextIDScroll
class_name MorphologyScroll
## Keeps up to date with the morphology listing to show a scroll list of all morphologies

signal morphology_selected(morphology: Morphology) # Mostly  proxy of item_selected, but also will emit NullMorphology when no morphology is selected

@export var load_morphologies_on_load: bool = true
@export var call_for_morphology_reload_on_load: bool = true

var selected_morphology: Morphology:
	get: return _selected_morphology

var _selected_morphology: Morphology = NullMorphology.new()

func _ready():
	super()
	item_selected.connect(_morphology_button_pressed)
	if call_for_morphology_reload_on_load:
		FeagiRequests.refresh_morphology_list()
	if load_morphologies_on_load:
		repopulate_from_cache()
	FeagiCache.morphology_cache.morphology_about_to_be_removed.connect(_respond_to_deleted_morphology)
	FeagiCache.morphology_cache.morphology_added.connect(_respond_to_added_morphology)

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
	_selected_morphology = morphology

## User selected morpholgy from the list
func _morphology_button_pressed(morphology_selection: Morphology) -> void:
	_selected_morphology = morphology_selection
	morphology_selected.emit(morphology_selection)

func _respond_to_deleted_morphology(morphology: Morphology) -> void:
	remove_by_ID(morphology)
	if morphology.name == _selected_morphology.name:
		_selected_morphology = NullMorphology.new()
		morphology_selected.emit(_selected_morphology)

func _respond_to_added_morphology(morphology: Morphology) -> void:
	append_single_item(morphology, morphology.name)

