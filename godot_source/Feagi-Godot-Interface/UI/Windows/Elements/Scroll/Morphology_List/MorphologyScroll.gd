extends Control
class_name MorphologyScroll
## Keeps up to date with the morphology listing to show a scroll list of all morphologies

signal morphology_selected(morphology: Morphology)
signal previously_selected_morphology_removed(morphology: Morphology)

@export var load_morphologies_on_load: bool = true

var selected_morphology: Morphology

var _scroll_ref: BaseScroll

func _ready():
	_scroll_ref = $Scroll_Vertical
	FeagiCacheEvents.morphology_removed.connect(_respond_to_deleted_morphology)
	FeagiCacheEvents.morphology_added.connect(_respond_to_added_morphology)
	if load_morphologies_on_load:
		populate_from_cache()
	_scroll_ref.custom_minimum_size = custom_minimum_size

func populate_from_cache() -> void:
	clear_list()
	for morphology in FeagiCache.morphology_cache.available_morphologies.values():
		_spawn_morphology_button(morphology)

func clear_list() -> void:
	_scroll_ref.remove_all_children()

func select_morphology(morphology: Morphology) -> void:
	selected_morphology = morphology
	#TODO there should be some button highlighting in here!

func _spawn_morphology_button(morphology: Morphology) -> void:
	var morphology_button: ScrollButtonPrefab = _scroll_ref.spawn_list_item({
		"name": morphology.name,
		"text": morphology.name
	})
	morphology_button.prefab_pressed.connect(_morphology_button_pressed)

func _morphology_button_pressed(button: ScrollButtonPrefab) -> void:
	selected_morphology = FeagiCache.morphology_cache.available_morphologies[button.name]
	morphology_selected.emit(FeagiCache.morphology_cache.available_morphologies[button.name])

func _respond_to_deleted_morphology(morphology: Morphology) -> void:
	_scroll_ref.remove_child_by_name(morphology.name)

func _respond_to_added_morphology(morphology: Morphology) -> void:
	_spawn_morphology_button(morphology)
