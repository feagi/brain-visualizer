extends HBoxContainer
class_name TopBar

@export var starting_size_index: int = 2
@export var theme_scalar_nodes_to_not_include_or_search: Array[Node] = []

signal request_UI_mode(mode: TempSplit.STATES)

var _theme_custom_scaler: ScaleThemeApplier = ScaleThemeApplier.new()
var _refresh_rate_field: FloatInput # bburst engine
var _index_scale: int

var _neuron_count: TextInput
var _synapse_count: TextInput

var _increase_scale_button: TextureButton
var _decrease_scale_button: TextureButton
var _activity_rendering_toggle: TextureButton


func _ready():
	# references
	_refresh_rate_field = $DetailsPanel/MarginContainer/Details/Place_child_nodes_here/HBoxContainer/RR_Float
	var state_indicator: StateIndicator = $DetailsPanel/MarginContainer/Details/Place_child_nodes_here/StateIndicator
	var details_section: MultiItemCollapsible = $DetailsPanel/MarginContainer/Details
	_index_scale = starting_size_index
	
	_increase_scale_button = $ChangeSize/MarginContainer/HBoxContainer/Bigger
	_decrease_scale_button = $ChangeSize/MarginContainer/HBoxContainer/Smaller
	
	_activity_rendering_toggle = $ActivityRenderingPanel/MarginContainer/ActivityRenderingToggle
	print("🔍 DEBUG: Activity rendering toggle found: ", _activity_rendering_toggle != null)
	if _activity_rendering_toggle:
		print("🔍 DEBUG: Toggle visible: ", _activity_rendering_toggle.visible)
		print("🔍 DEBUG: Toggle size: ", _activity_rendering_toggle.size)
		print("🔍 DEBUG: Toggle position: ", _activity_rendering_toggle.position)
	
	_neuron_count = $DetailsPanel/MarginContainer/Details/Place_child_nodes_here/HBoxContainer2/neuron
	_synapse_count = $DetailsPanel/MarginContainer/Details/Place_child_nodes_here/HBoxContainer3/synapse
	
	# FEAGI data
	# Burst rate
	_refresh_rate_field.float_confirmed.connect(_user_on_burst_delay_change)
	FeagiCore.delay_between_bursts_updated.connect(_FEAGI_on_burst_delay_change)
	_FEAGI_on_burst_delay_change(FeagiCore.delay_between_bursts)
	
	## Count Limits
	FeagiCore.feagi_local_cache.neuron_count_current_changed.connect(_update_neuron_count_current)
	FeagiCore.feagi_local_cache.synapse_count_current_changed.connect(_update_synapse_count_current)

	#NOTE: State Indeicator handles updates from FEAGI independently, no need to do it here
	
	_theme_custom_scaler.setup(self, theme_scalar_nodes_to_not_include_or_search, BV.UI.loaded_theme)
	BV.UI.theme_changed.connect(_theme_updated)
	_theme_updated(BV.UI.loaded_theme)
	FeagiCore.about_to_reload_genome.connect(_on_genome_about_to_reload)
	toggle_buttons_interactability(false)


## Toggle button interactability of top bar (ignoring those that are not relevant to FEAGI directly)
func toggle_buttons_interactability(pressable: bool) -> void:
	if _refresh_rate_field == null:
		push_error("Too early to call for toggle_buttons_interactability! Skipping!")
		return
	print("TOPBAR: Setting pressability to %s" % pressable)
	_refresh_rate_field.editable = pressable
	$Buttons/MarginContainer/HBoxContainer/HBoxContainer/BrainRegionsList.disabled = !pressable
	$Buttons/MarginContainer/HBoxContainer/HBoxContainer/TextureButton_BrainRegions.disabled = !pressable
	$Buttons/MarginContainer/HBoxContainer/HBoxContainer/BrainAreasList.disabled = !pressable
	$Buttons/MarginContainer/HBoxContainer/HBoxContainer/TextureButton.disabled = !pressable
	$Buttons/MarginContainer/HBoxContainer/HBoxContainer3/BrainAreasList.disabled = !pressable
	$Buttons/MarginContainer/HBoxContainer/HBoxContainer3/TextureButton.disabled = !pressable
	
	

func _set_scale(index_movement: int) -> void:
	_index_scale += index_movement
	_index_scale = mini(_index_scale, len(BV.UI.possible_UI_scales) - 1)
	_index_scale = maxi(_index_scale, 0)
	_increase_scale_button.disabled =  _index_scale == len(BV.UI.possible_UI_scales) - 1
	_decrease_scale_button.disabled =  _index_scale == 0
	print("Topbar requesting scale change to " + str(BV.UI.possible_UI_scales[_index_scale]))
	BV.UI.request_switch_to_theme(BV.UI.possible_UI_scales[_index_scale], UIManager.THEME_COLORS.DARK)



func _FEAGI_on_burst_delay_change(new_delay_between_bursts_seconds: float) -> void:
	print("🔥 TOPBAR: FEAGI updated delay to %s seconds" % new_delay_between_bursts_seconds)
	
	# Don't disable the field based on FEAGI data - let the genome state control editability
	# _refresh_rate_field.editable = new_delay_between_bursts_seconds != 0.0
	
	if new_delay_between_bursts_seconds == 0.0:
		print("🔥 TOPBAR: FEAGI sent 0.0 delay - setting display to 0.0 Hz")
		_refresh_rate_field.current_float = 0.0
		return
	
	var frequency_hz = 1.0 / new_delay_between_bursts_seconds
	print("🔥 TOPBAR: Converting %s seconds delay to %s Hz display" % [new_delay_between_bursts_seconds, frequency_hz])
	_refresh_rate_field.current_float = frequency_hz

func _user_on_burst_delay_change(new_refresh_rate_hz: float) -> void:
	print("🔥 TOPBAR: User changed refresh rate to %s Hz" % new_refresh_rate_hz)
	
	if new_refresh_rate_hz <= 0.0:
		print("🔥 TOPBAR: Invalid refresh rate (<= 0), resetting to current value")
		_refresh_rate_field.current_float = 1.0 / FeagiCore.delay_between_bursts
		return
	
	# Convert frequency (Hz) to delay (seconds) and send to FEAGI
	var delay_seconds = 1.0 / new_refresh_rate_hz
	print("🔥 TOPBAR: Converting %s Hz to %s seconds delay, calling API..." % [new_refresh_rate_hz, delay_seconds])
	
	# Check if FeagiCore.requests is available
	if not FeagiCore or not FeagiCore.requests:
		print("🔥 TOPBAR: ERROR - FeagiCore.requests not available!")
		return
		
	FeagiCore.requests.update_burst_delay(delay_seconds)


func _view_selected(new_state: TempSplit.STATES) -> void:
	request_UI_mode.emit(new_state)

func _open_cortical_areas() -> void:
	BV.WM.spawn_cortical_view()
	#VisConfig.UI_manager.window_manager.spawn_cortical_view()

func _open_create_cortical() -> void:
	BV.WM.spawn_create_cortical()
func _open_brain_regions() -> void:
	# Placeholder: open regions manager/view when implemented
	BV.WM.spawn_brain_regions_view()

func _open_create_brain_region() -> void:
	# Open create brain region window using root region as parent and no preselected objects
	var parent_region: BrainRegion = FeagiCore.feagi_local_cache.brain_regions.get_root_region()
	BV.WM.spawn_create_region(parent_region, [])

	#VisConfig.UI_manager.window_manager.spawn_create_cortical()

func _open_neuron_morphologies() -> void:
	BV.WM.spawn_manager_morphology()

func _open_create_morpology() -> void:
	BV.WM.spawn_create_morphology()

func _open_options() -> void:
	BV.WM.spawn_options()

#func _FEAGI_retireved_latency(latency_ms: int) -> void:
#	_latency_field.current_int = latency_ms

func _smaller_scale() -> void:
	_set_scale(-1)
	
func _bigger_scale() -> void:
	_set_scale(1)

func _preview_button_pressed() -> void:
	BV.WM.spawn_view_previews()

func _placeholder_toggle_changed(button_pressed: bool) -> void:
	print("🔗 Global Neural Connections toggle changed to: ", button_pressed)
	_toggle_cortical_activity_rendering(button_pressed)

func _toggle_cortical_activity_rendering(enabled: bool) -> void:
	print("🔗 Setting global neural connections visibility to: ", enabled)
	_toggle_global_neural_connections(enabled)

func _toggle_global_neural_connections(enabled: bool) -> void:
	print("🔗 Toggling global neural connections: ", enabled)
	
	# Find the brain monitor scene
	var brain_monitor = _find_brain_monitor_scene()
	if not brain_monitor:
		print("🔗 ❌ Could not find brain monitor scene")
		return
	
	# Get all cortical area objects in the 3D scene
	var cortical_area_objects = _find_all_cortical_area_objects(brain_monitor)
	if cortical_area_objects.is_empty():
		print("🔗 ❌ No cortical area objects found in brain monitor")
		return
	
	print("🔗 Found ", cortical_area_objects.size(), " cortical area objects")
	
	# Toggle connections for all cortical areas
	for cortical_area_obj in cortical_area_objects:
		if enabled:
			# Show connections (simulate hover) with global mode
			cortical_area_obj.set_hover_over_volume_state(true, true)  # true for hover, true for global mode
		else:
			# Hide connections (simulate unhover)
			cortical_area_obj.set_hover_over_volume_state(false, false)  # false for hover, false for global mode
	
	if enabled:
		print("🔗 ✅ Global neural connections ENABLED for ", cortical_area_objects.size(), " areas")
	else:
		print("🔗 ❌ Global neural connections DISABLED for ", cortical_area_objects.size(), " areas")

func _find_brain_monitor_scene() -> Node:
	# Try to find the brain monitor scene in the scene tree
	# Look for UI_BrainMonitor_3DScene or similar
	var root = get_tree().root
	return _recursive_find_node_by_class(root, "UI_BrainMonitor_3DScene")

func _recursive_find_node_by_class(node: Node, target_class_name: String) -> Node:
	# Check if current node matches
	if node.get_script() and node.get_script().get_global_name() == target_class_name:
		return node
	
	# Check children recursively
	for child in node.get_children():
		var result = _recursive_find_node_by_class(child, target_class_name)
		if result:
			return result
	
	return null

func _find_all_cortical_area_objects(brain_monitor: Node) -> Array:
	# Find all UI_BrainMonitor_CorticalArea objects in the brain monitor
	var cortical_areas = []
	_recursive_find_cortical_areas(brain_monitor, cortical_areas)
	return cortical_areas

func _recursive_find_cortical_areas(node: Node, cortical_areas: Array) -> void:
	# Check if current node is a cortical area
	if node.get_script() and node.get_script().get_global_name() == "UI_BrainMonitor_CorticalArea":
		cortical_areas.append(node)
		# Debug: Check if this is a memory area
		if node._representing_cortial_area and node._representing_cortial_area.cortical_type == 1:  # MEMORY type
			print("🔗 Found MEMORY cortical area in global toggle: ", node._representing_cortial_area.cortical_ID)
	
	# Check children recursively
	for child in node.get_children():
		_recursive_find_cortical_areas(child, cortical_areas)

func _theme_updated(new_theme: Theme) -> void:
	theme = new_theme

	
func _update_neuron_count_current(val: int) -> void:
	_neuron_count.text = _format_int(val) 
	
func _update_synapse_count_current(val: int) -> void:
	_synapse_count.text = _format_int(val)

func _on_genome_about_to_reload() -> void:
	#_neuron_count.text = ""
	#_synapse_count.text = ""
	pass

#TODO remove this?
func _shorten_number(num: float) -> String:
	var a: int
	if num > 1000000:
		a = roundi(num / 1000000.0)
		return str(a) + "M"
	if num > 1000:
		a = roundi(num / 1000.0)
		return str(a) + "K"
	return str(a)

func _format_int(number: int) -> String:
	var number_str: String = str(number)
	var formatted_str: String = "" 
	var digit_count: int = 0

	for i in range(number_str.length() - 1, -1, -1):
		formatted_str = number_str[i] + formatted_str
		digit_count += 1
		if digit_count % 3 == 0 and i != 0:
			formatted_str = "," + formatted_str
	return formatted_str
