extends PanelContainer
class_name UIView

const PREFAB_UI_VIEW: PackedScene = preload("res://BrainVisualizer/UI/UIView/UIView.tscn")
const PREFAB_UI_TAB_CONTAINER: PackedScene = preload("res://BrainVisualizer/UI/UIView/UITabContainer/UITabContainer.tscn")

enum MODE {
	SPLIT,
	TAB
}

var is_root_view: bool: ## Is this the top layer [UIView]
	get: return _is_root_view
var mode: MODE: ## Is this [UIView] acting as a split container holding 2 [UIView]s or holding a tab container?
	get: return _mode

var _is_root_view: bool = false
var _mode: MODE
var _split_container: SplitContainer
var _primary_container: MarginContainer
var _secondary_container: MarginContainer


# Called when the node enters the scene tree for the first time.
func _ready():
	_split_container = $SplitContainer
	_primary_container = $SplitContainer/Primary
	_secondary_container = $SplitContainer/Secondary

## Only called for the root view [UIView] by [UIManager]. NOTE: NOTHING TO DO WITH BRAIN REGIONS
func set_this_as_root_view() -> void: 
	_is_root_view = true

func setup_as_single_tab(tabs: Array[Control]) -> void:
	_mode = MODE.TAB
	_secondary_container.visible = false
	_split_container.collapsed = true
	var new_tab: UITabContainer = PREFAB_UI_TAB_CONTAINER.instantiate()
	_primary_container.add_child(new_tab)
	new_tab.setup(tabs)
	new_tab.requested_view_region_as_CB.connect(show_or_create_CB_of_region)
	new_tab.requested_view_region_as_BM.connect(show_or_create_BM_of_region)

## Sets up the UIView as a split view with secondary container visible  
func setup_as_split() -> void:
	_mode = MODE.SPLIT
	_secondary_container.visible = true
	_split_container.collapsed = false
	_split_container.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	
	# Create a new tab container for the secondary view if it doesn't exist
	if _secondary_container.get_child_count() == 0:
		var secondary_tab: UITabContainer = PREFAB_UI_TAB_CONTAINER.instantiate()
		_secondary_container.add_child(secondary_tab)
		secondary_tab.requested_view_region_as_CB.connect(show_or_create_CB_of_region)
		secondary_tab.requested_view_region_as_BM.connect(show_or_create_BM_of_region)

## Gets the secondary tab container (for brain monitor tabs in split view)
func get_secondary_tab_container() -> UITabContainer:
	if _mode != MODE.SPLIT or _secondary_container.get_child_count() == 0:
		return null
	return _secondary_container.get_child(0) as UITabContainer

## Searches from the root [UIView] for a CB of the given region. If one is found, brings it to the top. Otherwise, creates one in the given [UITabContainer]
func show_or_create_CB_of_region(region: BrainRegion, UI_tab_to_create_in: UITabContainer) -> void:
	var UI_tab: UITabContainer = get_root_UIView().return_UITabContainer_holding_CB_of_given_region(region)
	if UI_tab != null:
		UI_tab.bring_existing_region_CB_to_top(region)
		return
	## Region doesn't exist as a CB anywhere, create one
	UI_tab_to_create_in.spawn_CB_of_region(region)

## Searches from the root [UIView] for a BM of the given region. If one is found, brings it to the top. Otherwise, creates one in the given [UITabContainer]
func show_or_create_BM_of_region(region: BrainRegion, UI_tab_to_create_in: UITabContainer) -> void:
	var UI_tab: UITabContainer = get_root_UIView().return_UITabContainer_holding_BM_of_given_region(region)
	if UI_tab != null:
		UI_tab.bring_existing_region_BM_to_top(region)
		return
	## Region doesn't exist as a BM anywhere, create one
	UI_tab_to_create_in.spawn_BM_of_region(region)

## Closes all non-root [BrainRegion] views
func close_all_non_root_brain_region_views() -> void:
	var all_tab_containers: Array[UITabContainer] = get_recursive_UITabContainer_children()
	for tab_container in all_tab_containers:
		tab_container.close_all_nonroot_views()

func reset():
	for child in _primary_container.get_children():
		child.queue_free()
	for child in _secondary_container.get_children():
		child.queue_free()


#region Queries

## Searches recursively downwards all [UITabContainer]s for one that contains a CB of the given region and returns it. If none found returns null
func return_UITabContainer_holding_CB_of_given_region(region: BrainRegion) -> UITabContainer:
	var all_tab_containers: Array[UITabContainer] = get_recursive_UITabContainer_children()
	for tab_container in all_tab_containers:
		if tab_container.does_contain_CB_of_region(region):
			return tab_container
	return null

## Searches recursively downwards all [UITabContainer]s for one that contains a BM of the given region and returns it. If none found returns null
func return_UITabContainer_holding_BM_of_given_region(region: BrainRegion) -> UITabContainer:
	var all_tab_containers: Array[UITabContainer] = get_recursive_UITabContainer_children()
	for tab_container in all_tab_containers:
		if tab_container.does_contain_BM_of_region(region):
			return tab_container
	return null

## Gets the [UIView] holding this one, returns null if this is the root
func get_parent_UIView() -> UIView:
	if _is_root_view:
		return null # The root cannot have a parent by definition
	return (get_parent().get_parent().get_parent() as UIView) # self -> margin -> split -> UIView

## Searches upward and returns the root UIView
func get_root_UIView() -> UIView:
	if _is_root_view:
		return self
	return get_parent_UIView().get_root_UIView()

## Gets all the [UITabContainer]s from this UIView and the ones under it
func get_recursive_UITabContainer_children(appending_search: Array[UITabContainer] = []) -> Array[UITabContainer]:
	var output: Array[UITabContainer] = appending_search
	if _mode == MODE.TAB:
		var primary_child = _get_primary_child()
		if primary_child and primary_child is UITabContainer:
			output.append(primary_child as UITabContainer)
		return output
	# this is a split view, handle both primary and secondary containers
	var primary_child = _get_primary_child()
	if primary_child:
		if primary_child is UITabContainer:
			# Direct tab container, add it to output
			output.append(primary_child as UITabContainer)
		elif primary_child is UIView:
			# Nested UIView, recursively get its tab containers
			var nested_containers = (primary_child as UIView).get_recursive_UITabContainer_children()
			output.append_array(nested_containers)
	
	var secondary_child = _get_secondary_child()
	if secondary_child:
		var nested_containers = secondary_child.get_recursive_UITabContainer_children()
		output.append_array(nested_containers)
	
	return output

#endregion

func _get_primary_child() -> Control: # can be a [UITabContainer] or another [UIView]
	if _primary_container.get_child_count() == 0:
		return null
	return _primary_container.get_child(0)

func _get_secondary_child() -> UIView: # Can only ever be a [UIView]
	if _secondary_container.get_child_count() == 0:
		return null
	return _secondary_container.get_child(0) as UIView
