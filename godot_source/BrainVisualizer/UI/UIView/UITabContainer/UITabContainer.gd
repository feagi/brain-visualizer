extends TabContainer
class_name UITabContainer

const PREFAB_CIRCUITBUILDER: PackedScene = preload("res://BrainVisualizer/UI/CircuitBuilder/CircuitBuilder.tscn")
const ICON_CB: Texture2D = preload("res://BrainVisualizer/UI/GenericResources/ButtonIcons/Circuit_Builder_S.png")

signal all_tabs_removed() ## Emitted when all tabs are removed, this container should be destroyed
signal requested_view_region_as_CB(region: BrainRegion, request_origin: UITabContainer)

var parent_UI_view: UIView:
	get: return _parent_UI_view

var _tab_bar: TabBar
var _parent_UI_view: UIView

func _ready():
	_tab_bar = get_tab_bar()
	_tab_bar.select_with_rmb = true
	_tab_bar.tab_close_pressed.connect(_on_user_close_tab)
	tab_changed.connect(_on_top_tab_change)

func setup(inital_tabs: Array[Control]) -> void:
	for tab in inital_tabs:
		_add_control_view_as_tab(tab)

## If CB of given region exists, brings it to the top. Otherwise, instantiates it and brings it to the top
func show_CB_of_region(region: BrainRegion) -> void:
	if does_contain_CB_of_region(region):
		bring_existing_region_CB_to_top(region)
		return
	spawn_CB_of_region(region)

## SPECIFCIALLY creates a CB of a region, and then adds it to this UITabContainer
func spawn_CB_of_region(region: BrainRegion) -> void:
	if does_contain_CB_of_region(region):
		push_error("UI UITabCOntainer: This tab container already contains region ID %s!" % region.region_ID)
		return
	var new_cb: CircuitBuilder = PREFAB_CIRCUITBUILDER.instantiate()
	new_cb.setup(region)
	_add_control_view_as_tab(new_cb)

## Brings an existing CB of given region in this tab container to the top
func bring_existing_region_CB_to_top(region: BrainRegion) -> void:
	var cb: CircuitBuilder = return_CB_of_region(region)
	if cb == null:
		push_warning("UI: Unable to find CB for region %s to bring to the top!" % region.region_ID)
		return
	var tab_idx: int = get_tab_idx_from_control(cb)
	current_tab = tab_idx

## Closes all nonroot CB and BM views. If this results in all tabs being removed, it will emit all_tabs_removed
func close_all_nonroot_views() -> void:
	for child in get_children():
		if child is CircuitBuilder:
			if !(child as CircuitBuilder).representing_region.is_root_region():
				child.queue_free()
			continue
		#TODO BM
	
	if len(get_children()) == 0:
		all_tabs_removed.emit()
	

#region Queries

## Returns an array of all CB tabs
func get_CB_tabs() -> Array[CircuitBuilder]:
	var output: Array[CircuitBuilder] = []
	for child in get_children():
		if child is CircuitBuilder:
			output.append(child as CircuitBuilder)
	return output

## Returns true if the open tab is representing the root region
func is_current_top_view_root_region() -> bool:
	var top_control = get_current_tab_control()
	if top_control is CircuitBuilder:
		return (top_control as CircuitBuilder).representing_region.is_root_region()
	push_error("UI: Unknown top control!")
	return false

## Returns true if we have a CB of the specified region
func does_contain_CB_of_region(searching_region: BrainRegion) -> bool:
	for child in get_children():
		if child is CircuitBuilder:
			if (child as CircuitBuilder).representing_region.region_ID == searching_region.region_ID:
				return true
	return false

## Returns true if there is a CB of the root region as a tab here
func does_contain_root_region_CB() -> bool:
	return does_contain_CB_of_region(FeagiCore.feagi_local_cache.brain_regions.get_root_region())

## Returns the CB of the given region. Returns null if it doesn't exist
func return_CB_of_region(searching_region: BrainRegion) -> CircuitBuilder:
	for child in get_children():
		if child is CircuitBuilder:
			if (child as CircuitBuilder).representing_region.region_ID == searching_region.region_ID:
				return (child as CircuitBuilder)
	return null

func get_tab_IDX_as_control(idx: int) -> Control:
	return get_child(idx) as Control


#endregion
func _on_user_close_tab(tab_idx: int) -> void:
	_remove_control_view_as_tab(get_tab_IDX_as_control(tab_idx))

func _on_top_tab_change(_tab_index: int) -> void:
	if is_current_top_view_root_region():
		_tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_NEVER
	else:
		_tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_ACTIVE_ONLY

func _add_control_view_as_tab(region_view: Control) -> void:
	if region_view is CircuitBuilder:
		var cb: CircuitBuilder = region_view as CircuitBuilder
		add_child(cb)
		var tab_idx: int = get_tab_idx_from_control(cb)
		set_tab_icon(tab_idx , ICON_CB)
		_tab_bar.set_tab_icon_max_width(tab_idx, 20) #TODO
		current_tab = tab_idx
		cb.user_request_viewing_subregion.connect(_internal_CB_requesting_CB_view_of_region)
		return
	push_error("UI: Unknown control type added to UITabContainer! Ignoring!")

func _remove_control_view_as_tab(region_view: Control) -> void:
	if region_view is CircuitBuilder:
		var cb: CircuitBuilder = region_view as CircuitBuilder
		cb.user_request_viewing_subregion.disconnect(_internal_CB_requesting_CB_view_of_region)
		remove_child(cb)
		cb.queue_free()
	if len(get_children()) == 0:
		all_tabs_removed.emit()

func _internal_CB_requesting_CB_view_of_region(region: BrainRegion) -> void:
	requested_view_region_as_CB.emit(region, self)
