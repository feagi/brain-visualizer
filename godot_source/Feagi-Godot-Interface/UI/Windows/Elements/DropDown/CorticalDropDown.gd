extends OptionButton
class_name CorticalDropDown
## Dropdown specifically intended to list cortical areas by name

signal user_selected_cortical_area(cortical_area_reference: CorticalArea)

## If true, show names in the dropdown instead of the cortical IDs
@export var display_names_instead_of_IDs: bool = true
# If true, will automatically remove cortical areas from the drop down that were removed from cache
@export var sync_removed_cortical_areas: bool = true

var _listed_areas: Array[CorticalArea] = []

func _ready():
	if sync_removed_cortical_areas:
		FeagiCacheEvents.cortical_area_removed.connect(_cortical_area_was_deleted_from_cache)
	item_selected.connect(_user_selected_option)

## Clears all listed cortical areas
func clear_all_cortical_areas() -> void:
	_listed_areas = []
	clear()

## Replace cortical area listing with a new one
func overwrite_cortical_areas(new_areas: Array[CorticalArea]) -> void:
	clear_all_cortical_areas()
	for area in new_areas:
		add_cortical_area(area)
	_remove_radio_buttons()

## Add a singular cortical area to the end of the drop down
func add_cortical_area(new_area: CorticalArea) -> void:
	_listed_areas.append(new_area)
	if(display_names_instead_of_IDs):
		add_item(new_area.name)
	else:
		add_item(new_area.cortical_ID)

## Set the drop down selection to a specific (contained) cortical area
func set_selected_cortical_area(set_area: CorticalArea) -> void:
	var index: int = _listed_areas.find(set_area)
	if index == -1:
		push_warning("Attemped to set cortical area drop down to an item that the drop down does not contain! Skipping!")
		return
	select(index)

## Set the dropdown to select nothing
func deselect_all() -> void:
	select(-1)

## Remove cortical area from listing
func remove_cortical_area(removing: CorticalArea) -> void:
	var index: int = _listed_areas.find(removing)
	if index == -1:
		push_warning("Attempted to remove cortical area that the drop down does not contain! Skipping!")
		return
	_listed_areas.remove_at(index)
	remove_item(index)

## Populate dropdown with cortical areas of specific types
func list_cortical_area_types(types_to_show: Array[CorticalArea.CORTICAL_AREA_TYPE]) -> void:
	var areas_to_show: Array[CorticalArea] = []
	for array_type in types_to_show:
		areas_to_show.append_array(FeagiCache.cortical_areas_cache.search_for_cortical_areas_by_type(array_type))
	overwrite_cortical_areas(areas_to_show)

func _user_selected_option(index: int) -> void:
	user_selected_cortical_area.emit(_listed_areas[index])

func _cortical_area_was_deleted_from_cache(deleted_cortical: CorticalArea) -> void:
	if deleted_cortical not in _listed_areas:
		return
	remove_cortical_area(deleted_cortical)

func _remove_radio_buttons() -> void:
	var pm: PopupMenu = get_popup()
	for i in pm.get_item_count():
		if pm.is_item_radio_checkable(i):
			pm.set_item_as_radio_checkable(i, false)
