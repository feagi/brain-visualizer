extends OptionButton
class_name CorticalDropDown
## Dropdown specifically intended to list cortical areas by name

signal user_selected_cortical_area(cortical_area_reference: AbstractCorticalArea)

## If true, show names in the dropdown instead of the cortical IDs
@export var display_names_instead_of_IDs: bool = true
## If true, will automatically remove cortical areas from the drop down that were removed from cache
@export var sync_removed_cortical_areas: bool = true
## If true, will automatically sff cortical areas to the drop down that were added to the cache
@export var sync_added_cortical_areas: bool = true
## If True, will load all cached cortical areas on Startup
@export var sync_all_areas_on_load: bool = true
## If True, will hide the circle selection icon on the dropdown
@export var hide_circle_select_icon: bool = true
## If True, adds a "(None)" entry at index 0 so the user can clear the selection
@export var include_none_option: bool = false

var _listed_areas: Array[AbstractCorticalArea] = []
var _popup: PopupMenu
var _default_width: float
var _none_offset: int = 0

func _ready():
	_default_width = custom_minimum_size.x
	_popup = get_popup()
	if include_none_option:
		add_item("(None)")
		if hide_circle_select_icon:
			_popup.set_item_as_radio_checkable(0, false)
		_none_offset = 1
		select(0)
	if sync_removed_cortical_areas:
		FeagiCore.feagi_local_cache.cortical_areas.cortical_area_about_to_be_removed.connect(_cortical_area_was_deleted_from_cache)
	if sync_added_cortical_areas:
		FeagiCore.feagi_local_cache.cortical_areas.cortical_area_added.connect(_cortical_area_was_added_to_cache)
	if sync_all_areas_on_load:
		list_all_cached_areas()
	item_selected.connect(_user_selected_option)
	BV.UI.theme_changed.connect(_on_theme_change)
	_on_theme_change()

## Clears all listed cortical areas
func clear_all_cortical_areas() -> void:
	_listed_areas = []
	clear()
	if include_none_option:
		add_item("(None)")
		if hide_circle_select_icon:
			_popup.set_item_as_radio_checkable(0, false)
		select(0)

## Replace cortical area listing with a new one (sorted by display name or ID per export).
func overwrite_cortical_areas(new_areas: Array[AbstractCorticalArea]) -> void:
	var sorted: Array[AbstractCorticalArea] = new_areas.duplicate()
	sorted.sort_custom(_compare_cortical_areas_by_display_name)
	_rebuild_items_from_area_array(sorted)

## Display all cortical areas
func list_all_cached_areas() -> void:
	var cortical_areas: Array[AbstractCorticalArea] = []
	cortical_areas.assign(FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.values())
	overwrite_cortical_areas(cortical_areas)
	
## Add a singular cortical area to the end of the drop down
func add_cortical_area(new_area: AbstractCorticalArea) -> void:
	_listed_areas.append(new_area)
	if(display_names_instead_of_IDs):
		add_item(new_area.friendly_name)
	else:
		add_item(new_area.cortical_ID)
	if hide_circle_select_icon:
		_popup.set_item_as_radio_checkable(_popup.get_item_count() - 1, false) # Remove Circle Selection
	

## Set the drop down selection to a specific (contained) cortical area
func set_selected_cortical_area(set_area: AbstractCorticalArea) -> void:
	var index: int = _listed_areas.find(set_area)
	if index == -1:
		push_warning("Attemped to set cortical area drop down to an item that the drop down does not contain! Skipping!")
		return
	select(index + _none_offset)

## Returns the currently selected cortical area, or null if none.
func get_selected_cortical_area() -> AbstractCorticalArea:
	var idx: int = selected - _none_offset
	if idx < 0 or idx >= _listed_areas.size():
		return null
	return _listed_areas[idx]


## Set the dropdown to select nothing (or the "(None)" entry if available)
func deselect_all() -> void:
	if include_none_option:
		select(0)
	else:
		select(-1)

## Remove cortical area from listing
func remove_cortical_area(removing: AbstractCorticalArea) -> void:
	var index: int = _listed_areas.find(removing)
	if index == -1:
		push_warning("Attempted to remove cortical area that the drop down does not contain! Skipping!")
		return
	_listed_areas.remove_at(index)
	remove_item(index + _none_offset)

## Populate dropdown with cortical areas of specific types
func list_cortical_area_types(types_to_show: Array[AbstractCorticalArea.CORTICAL_AREA_TYPE]) -> void:
	var areas_to_show: Array[AbstractCorticalArea] = []
	for array_type in types_to_show:
		areas_to_show.append_array(FeagiCore.feagi_local_cache.cortical_areas.search_for_available_cortical_areas_by_type(array_type))
	overwrite_cortical_areas(areas_to_show)

func _user_selected_option(index: int) -> void:
	var area_index: int = index - _none_offset
	if area_index < 0 or area_index >= _listed_areas.size():
		user_selected_cortical_area.emit(null)
		return
	user_selected_cortical_area.emit(_listed_areas[area_index])

func _cortical_area_was_deleted_from_cache(deleted_cortical: AbstractCorticalArea) -> void:
	if deleted_cortical not in _listed_areas:
		return
	remove_cortical_area(deleted_cortical)

func _cortical_area_was_added_to_cache(added_cortical: AbstractCorticalArea) -> void:
	if added_cortical in _listed_areas:
		return
	var merged: Array[AbstractCorticalArea] = _listed_areas.duplicate()
	merged.append(added_cortical)
	merged.sort_custom(_compare_cortical_areas_by_display_name)
	_rebuild_items_from_area_array(merged)

func _on_theme_change(_new_theme: Theme = null) -> void:
	custom_minimum_size.x = _default_width * BV.UI.loaded_theme_scale.x


func _rebuild_items_from_area_array(areas: Array[AbstractCorticalArea]) -> void:
	var selected_id: StringName = &""
	var selected_area: AbstractCorticalArea = get_selected_cortical_area()
	if selected_area != null:
		selected_id = selected_area.cortical_ID
	clear_all_cortical_areas()
	for area in areas:
		add_cortical_area(area)
	_restore_selection_by_cortical_id(selected_id)


func _compare_cortical_areas_by_display_name(a: AbstractCorticalArea, b: AbstractCorticalArea) -> bool:
	var sa: String
	var sb: String
	if display_names_instead_of_IDs:
		sa = String(a.friendly_name).to_lower()
		sb = String(b.friendly_name).to_lower()
	else:
		sa = String(a.cortical_ID).to_lower()
		sb = String(b.cortical_ID).to_lower()
	return sa < sb

func _restore_selection_by_cortical_id(cortical_id: StringName) -> void:
	if cortical_id == &"":
		if include_none_option:
			select(0)
		return
	for i in _listed_areas.size():
		var area: AbstractCorticalArea = _listed_areas[i]
		if area != null and area.cortical_ID == cortical_id:
			select(i + _none_offset)
			return
	if include_none_option:
		select(0)
	else:
		select(-1)
