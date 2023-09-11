extends OptionButton
class_name MorphologyDropDown
## Dropdown specifically intended to list Morphologies by name

signal user_selected_morphology(morphology_reference: Morphology)

## If true, show names in the dropdown instead of the cortical IDs
#@export var display_names_instead_of_IDs: bool = true
# If true, will automatically remove morphologies from the drop down that were removed from cache
@export var sync_removed_morphologies: bool = true

var _listed_morphologies: Array[Morphology] = []

func _ready():
	if sync_removed_morphologies:
		FeagiCacheEvents.morphology_removed.connect(_morphology_was_deleted_from_cache)
	item_selected.connect(_user_selected_option)

## Clears all listed morphologies
func clear_all_morphologys() -> void:
	_listed_morphologies = []
	clear()

## Replace morphology listing with a new one
func overwrite_morphologys(new_morphology: Array[Morphology]) -> void:
	clear_all_morphologys()
	for morphology in new_morphology:
		add_morphology(morphology)
	_remove_radio_buttons()

## Add a singular morphology to the end of the drop down
func add_morphology(new_morphology: Morphology) -> void:
	_listed_morphologies.append(new_morphology)
	#if(display_names_instead_of_IDs):
	#	add_item(new_area.name)
	#else:
	#	add_item(new_area.cortical_ID)
	add_item(new_morphology.name) # using name only since as of writing, morphologies do not have IDs

## Set the drop down selection to a specific (contained) morphology
func set_selected_morphology(set_morphology: Morphology) -> void:
	var index: int = _listed_morphologies.find(set_morphology)
	if index == -1:
		push_warning("Attemped to set morphology drop down to an item that the drop down does not contain! Skipping!")
		return
	select(index)

## Set the dropdown to select nothing
func deselect_all() -> void:
	select(-1)

## Remove morphology from listing
func remove_morphology(removing: Morphology) -> void:
	var index: int = _listed_morphologies.find(removing)
	if index == -1:
		push_warning("Attempted to remove cortical area that the drop down does not contain! Skipping!")
		return
	_listed_morphologies.remove_at(index)
	remove_item(index)

func _user_selected_option(index: int) -> void:
	user_selected_morphology.emit(_listed_morphologies[index])

func _morphology_was_deleted_from_cache(deleted_morphology: Morphology) -> void:
	if deleted_morphology not in _listed_morphologies:
		return
	remove_morphology(deleted_morphology)

func _remove_radio_buttons() -> void:
	var pm: PopupMenu = get_popup()
	for i in pm.get_item_count():
		if pm.is_item_radio_checkable(i):
			pm.set_item_as_radio_checkable(i, false)
