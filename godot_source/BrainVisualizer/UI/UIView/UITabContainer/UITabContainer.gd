extends TabContainer
class_name UITabContainer

var PREFAB_CIRCUITBUILDER: PackedScene = preload("res://BrainVisualizer/UI/CircuitBuilder/CircuitBuilder.tscn") #TODO using non const instead of const due to cyclid dependency issue currently
const SCENE_BRAIN_MONITOR_PATH: StringName = "res://addons/UI_BrainMonitor/BrainMonitor.tscn"
const ICON_CB: Texture2D = preload("res://BrainVisualizer/UI/GenericResources/ButtonIcons/Circuit_Builder_S.png")
const ICON_BM: Texture2D = preload("res://BrainVisualizer/UI/GenericResources/ButtonIcons/Brain_Visualizer_S.png")

signal all_tabs_removed() ## Emitted when all tabs are removed, this container should be destroyed
signal requested_view_region_as_CB(region: BrainRegion, request_origin: UITabContainer)
signal requested_view_region_as_BM(region: BrainRegion, request_origin: UITabContainer)

var parent_UI_view: UIView:
	get: return _parent_UI_view

var _tab_bar: TabBar
var _parent_UI_view: UIView

func _ready():
	_tab_bar = get_tab_bar()
	_tab_bar.select_with_rmb = true
	_tab_bar.tab_close_pressed.connect(_on_user_close_tab)
	PREFAB_CIRCUITBUILDER = load("res://BrainVisualizer/UI/CircuitBuilder/CircuitBuilder.tscn") #TODO using non const instead of const due to cyclid dependency issue currently
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
	#CURSED
	_add_control_view_as_tab(new_cb)

## If BM of given region exists, brings it to the top. Otherwise, instantiates it and brings it to the top
func show_BM_of_region(region: BrainRegion) -> void:
	if does_contain_BM_of_region(region):
		bring_existing_region_BM_to_top(region)
		return
	spawn_BM_of_region(region)

## SPECIFICALLY creates a BM of a region, and then adds it to this UITabContainer
func spawn_BM_of_region(region: BrainRegion) -> void:
	if does_contain_BM_of_region(region):
		push_error("UI UITabContainer: This tab container already contains BM for region ID %s!" % region.region_ID)
		return
	
	print("🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥")
	print("🔥 CALL STACK TRACE: spawn_BM_of_region() called! 🔥")
	print("🔥 Region: %s 🔥" % region.friendly_name)
	print("🔥 Call Stack: 🔥")
	get_stack().reverse()
	for i in range(min(5, get_stack().size())):
		var frame = get_stack()[i]
		print("🔥   %d. %s:%s in %s() 🔥" % [i, frame.source, frame.line, frame.function])
	print("🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥")
	
	print("🧠 UITabContainer: Creating new 3D brain monitor for region: %s" % region.friendly_name)
	var new_bm: UI_BrainMonitor_3DScene = UI_BrainMonitor_3DScene.create_uninitialized_brain_monitor()
	_add_control_view_as_tab_with_region_info(new_bm, region)
	# Use call_deferred to ensure _ready() has been called before setup
	print("🧠 UITabContainer: Deferring setup for brain monitor: %s" % region.friendly_name)
	new_bm.call_deferred("setup", region)
	
	# CRITICAL: Connect neuron firing signal to FEAGI handler (same as main brain monitor)
	new_bm.requesting_to_fire_selected_neurons.connect(BV.UI._send_activations_to_FEAGI)
	print("🔥 UITabContainer: Connected neuron firing signal for brain region tab: %s" % region.friendly_name)
	
	# Set tab title after setup is complete
	new_bm.call_deferred("_update_tab_title_after_setup")
	
	# Double check tab visibility after a brief delay
	var timer = get_tree().create_timer(0.1)
	timer.timeout.connect(_check_tab_visibility.bind(region, new_bm))

## Brings an existing CB of given region in this tab container to the top
func bring_existing_region_CB_to_top(region: BrainRegion) -> void:
	var cb: CircuitBuilder = return_CB_of_region(region)
	if cb == null:
		push_warning("UI: Unable to find CB for region %s to bring to the top!" % region.region_ID)
		return
	var tab_idx: int = get_tab_idx_from_control(cb)
	current_tab = tab_idx

## Brings an existing BM of given region in this tab container to the top
func bring_existing_region_BM_to_top(region: BrainRegion) -> void:
	var bm: UI_BrainMonitor_3DScene = return_BM_of_region(region)
	if bm == null:
		push_warning("UI: Unable to find BM for region %s to bring to the top!" % region.region_ID)
		return
	var tab_idx: int = get_tab_idx_from_control(bm)
	current_tab = tab_idx

## Closes all nonroot CB and BM views. If this results in all tabs being removed, it will emit all_tabs_removed
func close_all_nonroot_views() -> void:
	for child in get_children():
		if child is CircuitBuilder:
			if !(child as CircuitBuilder).representing_region.is_root_region():
				child.queue_free()
			continue
		elif child is UI_BrainMonitor_3DScene:
			if !(child as UI_BrainMonitor_3DScene).representing_region.is_root_region():
				child.queue_free()
			continue
	
	if len(get_children()) == 0:
		all_tabs_removed.emit()

## Closes all views, will emit all_tabs_removed
func close_all_views() -> void:
	for child in get_children():
		child.queue_free()
	all_tabs_removed.emit()


#region Queries

## Returns an array of all CB tabs
func get_CB_tabs() -> Array[CircuitBuilder]:
	var output: Array[CircuitBuilder] = []
	for child in get_children():
		if child is CircuitBuilder:
			output.append(child as CircuitBuilder)
	return output

## Returns true if the open tab is representing the Main circuit
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

## Returns true if there is a CB of the Main circuit as a tab here
func does_contain_root_region_CB() -> bool:
	return does_contain_CB_of_region(FeagiCore.feagi_local_cache.brain_regions.get_root_region())

## Returns the CB of the given region. Returns null if it doesn't exist
func return_CB_of_region(searching_region: BrainRegion) -> CircuitBuilder:
	for child in get_children():
		if child is CircuitBuilder:
			if (child as CircuitBuilder).representing_region.region_ID == searching_region.region_ID:
				return (child as CircuitBuilder)
	return null

## Returns true if we have a BM of the specified region
func does_contain_BM_of_region(searching_region: BrainRegion) -> bool:
	for child in get_children():
		if child is UI_BrainMonitor_3DScene:
			if (child as UI_BrainMonitor_3DScene).representing_region.region_ID == searching_region.region_ID:
				return true
	return false

## Returns the BM of the given region. Returns null if it doesn't exist
func return_BM_of_region(searching_region: BrainRegion) -> UI_BrainMonitor_3DScene:
	for child in get_children():
		if child is UI_BrainMonitor_3DScene:
			if (child as UI_BrainMonitor_3DScene).representing_region.region_ID == searching_region.region_ID:
				return (child as UI_BrainMonitor_3DScene)
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
	# HACK CB
	var cb: CircuitBuilder = get_tab_IDX_as_control(_tab_index) as CircuitBuilder
	#BV.UI.selection_system.clear_all_highlighted()

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
	elif region_view is UI_BrainMonitor_3DScene:
		var bm: UI_BrainMonitor_3DScene = region_view as UI_BrainMonitor_3DScene
		add_child(bm) # Add to tab container
		var tab_idx: int = get_tab_idx_from_control(bm)
		set_tab_icon(tab_idx , ICON_BM)
		_tab_bar.set_tab_icon_max_width(tab_idx, 20) #TODO
		current_tab = tab_idx
		print("🧠 UITabContainer: Added 3D brain monitor tab (tab index: %d)" % tab_idx)
		return
	push_error("UI: Unknown control type added to UITabContainer! Ignoring!")

func _add_control_view_as_tab_with_region_info(region_view: Control, region: BrainRegion) -> void:
	if region_view is UI_BrainMonitor_3DScene:
		var bm: UI_BrainMonitor_3DScene = region_view as UI_BrainMonitor_3DScene
		print("🧠 UITabContainer: Adding brain monitor to tab container...")
		print("🧠 UITabContainer: Brain monitor type: %s" % bm.get_class())
		print("🧠 UITabContainer: Tab container children before add: %d" % get_child_count())
		
		add_child(bm) # Add to tab container
		print("🧠 UITabContainer: Tab container children after add: %d" % get_child_count())
		
		var tab_idx: int = get_tab_idx_from_control(bm)
		print("🧠 UITabContainer: Got tab index: %d" % tab_idx)
		
		set_tab_icon(tab_idx , ICON_BM)
		_tab_bar.set_tab_icon_max_width(tab_idx, 20) #TODO
		print("🧠 UITabContainer: Set tab icon and width")
		
		current_tab = tab_idx
		print("🧠 UITabContainer: Set current tab to: %d" % current_tab)
		print("🧠 UITabContainer: TabContainer current_tab property: %d" % current_tab)
		
		# Check if tab is visible
		print("🧠 UITabContainer: Tab container visible: %s" % visible)
		print("🧠 UITabContainer: Brain monitor visible: %s" % bm.visible)
		print("🧠 UITabContainer: Tab title: '%s'" % get_tab_title(tab_idx))
		
		print("🧠 UITabContainer: Added 3D brain monitor tab for region: %s (tab index: %d)" % [region.friendly_name, tab_idx])
		return
	else:
		# Fallback to regular method for non-BM controls
		_add_control_view_as_tab(region_view)

func _remove_control_view_as_tab(region_view: Control) -> void:
	if region_view is CircuitBuilder:
		var cb: CircuitBuilder = region_view as CircuitBuilder
		cb.user_request_viewing_subregion.disconnect(_internal_CB_requesting_CB_view_of_region)
		remove_child(cb)
		cb.queue_free()
	elif region_view is UI_BrainMonitor_3DScene:
		var bm: UI_BrainMonitor_3DScene = region_view as UI_BrainMonitor_3DScene
		print("🧠 UITabContainer: Removing 3D brain monitor tab for region: %s" % bm.representing_region.friendly_name)
		# Clean up any open previews before removing
		bm.clear_all_open_previews()
		remove_child(bm)
		bm.queue_free()
	if len(get_children()) == 0:
		all_tabs_removed.emit()

func _internal_CB_requesting_CB_view_of_region(region: BrainRegion) -> void:
	requested_view_region_as_CB.emit(region, self)

func _internal_BM_requesting_BM_view_of_region(region: BrainRegion) -> void:
	requested_view_region_as_BM.emit(region, self)

func _check_tab_visibility(region: BrainRegion, bm: UI_BrainMonitor_3DScene) -> void:
	print("🧠 UITabContainer: Checking tab visibility after delay...")
	print("🧠 UITabContainer: Current tab: %d" % current_tab)
	print("🧠 UITabContainer: Total children: %d" % get_child_count())
	print("🧠 UITabContainer: Brain monitor parent: %s" % bm.get_parent())
	print("🧠 UITabContainer: Brain monitor visible: %s" % bm.visible)
	
	var tab_idx = get_tab_idx_from_control(bm)
	if tab_idx >= 0:
		print("🧠 UITabContainer: Tab found at index %d" % tab_idx)
		print("🧠 UITabContainer: Tab title: '%s'" % get_tab_title(tab_idx))
		print("🧠 UITabContainer: Tab disabled: %s" % is_tab_disabled(tab_idx))
		# Force tab to be current
		current_tab = tab_idx
		print("🧠 UITabContainer: Forced current tab to %d" % current_tab)
	else:
		push_error("🧠 UITabContainer: Could not find tab for brain monitor!")
	
	# Check if region has been set up
	if bm.representing_region != null:
		print("🧠 UITabContainer: Brain monitor representing region: %s" % bm.representing_region.friendly_name)
	else:
		print("🧠 UITabContainer: Brain monitor representing region is still null")
