extends OptionButton
class_name CorticalDropDown
## Dropdown specifically intended to list cortical areas by name

signal user_selected_cortical_area(cortical_area_reference: BaseCorticalArea)

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

var _listed_areas: Array[BaseCorticalArea] = []
var _popup: PopupMenu
var _default_font_size: int
var _default_min_size: Vector2

func _ready():
	_popup = get_popup()
	if sync_removed_cortical_areas:
		FeagiCacheEvents.cortical_area_removed.connect(_cortical_area_was_deleted_from_cache)
	if sync_added_cortical_areas:
		FeagiCacheEvents.cortical_area_added.connect(_cortical_area_was_added_to_cache)
	if sync_all_areas_on_load:
		list_all_cached_areas()
	item_selected.connect(_user_selected_option)
	_default_font_size = get_theme_font_size(&"font_size")
	if custom_minimum_size != Vector2(0,0):
		_default_min_size = custom_minimum_size
	_update_size(VisConfig.UI_manager.UI_scale)
	VisConfig.UI_manager.UI_scale_changed.connect(_update_size)

## Clears all listed cortical areas
func clear_all_cortical_areas() -> void:
	_listed_areas = []
	clear()

## Replace cortical area listing with a new one
func overwrite_cortical_areas(new_areas: Array[BaseCorticalArea]) -> void:
	clear_all_cortical_areas()
	for area in new_areas:
		add_cortical_area(area)

## Display all cortical areas
func list_all_cached_areas() -> void:
	var cortical_areas: Array[BaseCorticalArea] = []
	cortical_areas.assign(FeagiCache.cortical_areas_cache.cortical_areas.values())
	overwrite_cortical_areas(cortical_areas)
	
## Add a singular cortical area to the end of the drop down
func add_cortical_area(new_area: BaseCorticalArea) -> void:
	_listed_areas.append(new_area)
	if(display_names_instead_of_IDs):
		add_item(new_area.name)
	else:
		add_item(new_area.cortical_ID)
	if hide_circle_select_icon:
		_popup.set_item_as_radio_checkable(_popup.get_item_count() - 1, false) # Remove Circle Selection
	

## Set the drop down selection to a specific (contained) cortical area
func set_selected_cortical_area(set_area: BaseCorticalArea) -> void:
	var index: int = _listed_areas.find(set_area)
	if index == -1:
		push_warning("Attemped to set cortical area drop down to an item that the drop down does not contain! Skipping!")
		return
	select(index)

## Set the dropdown to select nothing
func deselect_all() -> void:
	select(-1)

## Remove cortical area from listing
func remove_cortical_area(removing: BaseCorticalArea) -> void:
	var index: int = _listed_areas.find(removing)
	if index == -1:
		push_warning("Attempted to remove cortical area that the drop down does not contain! Skipping!")
		return
	_listed_areas.remove_at(index)
	remove_item(index)

## Populate dropdown with cortical areas of specific types
func list_cortical_area_types(types_to_show: Array[BaseCorticalArea.CORTICAL_AREA_TYPE]) -> void:
	var areas_to_show: Array[BaseCorticalArea] = []
	for array_type in types_to_show:
		areas_to_show.append_array(FeagiCache.cortical_areas_cache.search_for_cortical_areas_by_type(array_type))
	overwrite_cortical_areas(areas_to_show)

func _user_selected_option(index: int) -> void:
	user_selected_cortical_area.emit(_listed_areas[index])

func _cortical_area_was_deleted_from_cache(deleted_cortical: BaseCorticalArea) -> void:
	if deleted_cortical not in _listed_areas:
		return
	remove_cortical_area(deleted_cortical)

func _cortical_area_was_added_to_cache(added_cortical: BaseCorticalArea) -> void:
	if added_cortical not in _listed_areas:
		add_cortical_area(added_cortical)

func _update_size(multiplier: float) -> void:
	add_theme_font_size_override(&"font_size", int(float(_default_font_size) * multiplier))
	if _default_min_size != Vector2(0,0):
		custom_minimum_size = _default_min_size * multiplier
	size = Vector2(0,0)
