extends GenericTextIDScroll
class_name MorphologyScroll
## Keeps up to date with the morphology listing to show a scroll list of all morphologies

signal morphology_selected(morphology:BaseMorphology) # Mostly  proxy of item_selected, but also will emit NullMorphology when no morphology is selected

@export var load_morphologies_on_load: bool = true
@export var refresh_morphology_from_FEAGI_on_select = true

var selected_morphology:BaseMorphology:
	get: return _selected_morphology

var _selected_morphology:BaseMorphology = NullMorphology.new()

func _ready():
	super()
	item_selected.connect(_morphology_button_pressed)
	if load_morphologies_on_load:
		repopulate_from_cache()
	FeagiCore.feagi_local_cache.morphologies.morphology_about_to_be_removed.connect(_respond_to_deleted_morphology)
	FeagiCore.feagi_local_cache.morphologies.morphology_added.connect(_respond_to_added_morphology)

## Clears list, then loads morphology list from FeagiCache
func repopulate_from_cache() -> void:
	delete_all()
	for morphology in FeagiCore.feagi_local_cache.morphologies.available_morphologies.values():
		append_single_item(morphology, morphology.name)

## Sets the morphologies froma  manual list
func set_morphologies(morphologies: Array[BaseMorphology]) -> void:
	delete_all()
	for morphology in morphologies:
		append_single_item(morphology, morphology.name)

## Manually set the selected morphology through code. Causes the button to emit the selected signal
func select_morphology(morphology: BaseMorphology) -> void:
	# This is essentially a pointless proxy, only existing for convinient naming purposes
	set_selected(morphology)
	_selected_morphology = morphology
	if refresh_morphology_from_FEAGI_on_select:
		FeagiCore.requests.get_morphology(morphology.name)

## User selected morpholgy from the list
func _morphology_button_pressed(morphology_selection:BaseMorphology) -> void:
	_selected_morphology = morphology_selection
	morphology_selected.emit(morphology_selection)
	if refresh_morphology_from_FEAGI_on_select:
		FeagiCore.requests.get_morphology(morphology_selection.name)

func _respond_to_deleted_morphology(morphology:BaseMorphology) -> void:
	remove_by_ID(morphology)
	if morphology.name == _selected_morphology.name:
		_selected_morphology = NullMorphology.new()
		morphology_selected.emit(_selected_morphology)

func _respond_to_added_morphology(morphology:BaseMorphology) -> void:
	append_single_item(morphology, morphology.name)


