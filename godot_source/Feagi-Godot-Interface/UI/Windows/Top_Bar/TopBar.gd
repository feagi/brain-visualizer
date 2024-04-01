extends HBoxContainer
class_name TopBar

@export var universal_padding: int = 15
@export var possible_zoom_levels: Array[float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
@export var starting_size_index: int = 2

var _refresh_rate_field: FloatInput
var _latency_field: IntInput
var _index_scale: int

var _neuron_count: TextInput
var _synapse_count: TextInput

var _increase_scale_button: TextureButton
var _decrease_scale_button: TextureButton
var _default_seperation: float # Save as float to avoid rounding errors when multiplying

func _ready():
	# references
	_refresh_rate_field = $DetailsPanel/MarginContainer/Details/Place_child_nodes_here/RR_Float
	_latency_field = $DetailsPanel/MarginContainer/Details/Place_child_nodes_here/ping
	var state_indicator: StateIndicator = $DetailsPanel/MarginContainer/Details/Place_child_nodes_here/StateIndicator
	var details_section: MultiItemCollapsible = $DetailsPanel/MarginContainer/Details
	_index_scale = starting_size_index
	
	_increase_scale_button = $ChangeSize/MarginContainer/HBoxContainer/Bigger
	_decrease_scale_button = $ChangeSize/MarginContainer/HBoxContainer/Smaller
	
	_neuron_count = $DetailsPanel/MarginContainer/Details/Place_child_nodes_here/neuron
	_synapse_count = $DetailsPanel/MarginContainer/Details/Place_child_nodes_here/synapse
	
	# apply padding
	$Buttons/MarginContainer.add_theme_constant_override("margin_top", universal_padding)
	$Buttons/MarginContainer.add_theme_constant_override("margin_left", universal_padding)
	$Buttons/MarginContainer.add_theme_constant_override("margin_bottom", universal_padding)
	$Buttons/MarginContainer.add_theme_constant_override("margin_right", universal_padding)
	$Buttons/MarginContainer/HBoxContainer.add_theme_constant_override("seperation", universal_padding)
	$DropDownPanel/MarginContainer.add_theme_constant_override("margin_top", universal_padding)
	$DropDownPanel/MarginContainer.add_theme_constant_override("margin_left", universal_padding)
	$DropDownPanel/MarginContainer.add_theme_constant_override("margin_bottom", universal_padding)
	$DropDownPanel/MarginContainer.add_theme_constant_override("margin_right", universal_padding)
	$DetailsPanel/MarginContainer.add_theme_constant_override("margin_top", universal_padding)
	$DetailsPanel/MarginContainer.add_theme_constant_override("margin_left", universal_padding)
	$DetailsPanel/MarginContainer.add_theme_constant_override("margin_bottom", universal_padding)
	$DetailsPanel/MarginContainer.add_theme_constant_override("margin_right", universal_padding)
	
	# from FEAGI
	FeagiCacheEvents.delay_between_bursts_updated.connect(_FEAGI_on_burst_delay_change)
	FeagiEvents.retrieved_latest_FEAGI_health.connect(state_indicator.set_feagi_states)
	var interface: FEAGIInterface =  get_tree().current_scene.get_node(NodePath("FEAGIInterface"))
	interface.FEAGI_websocket.socket_state_changed.connect(state_indicator.set_websocket_state)
	FeagiEvents.retrieved_latest_latency.connect(_FEAGI_retireved_latency)
	# from user
	_refresh_rate_field.float_confirmed.connect(_user_on_burst_delay_change)
	details_section.toggled.connect(_details_section_toggle)
	
	_default_seperation = get_theme_constant(&"separation")
	_update_size(VisConfig.UI_manager.UI_scale)
	VisConfig.UI_manager.UI_scale_changed.connect(_update_size)
	
	FeagiEvents.retrieved_latest_FEAGI_health.connect(_update_counts)
	
	

func _set_scale(index_movement: int) -> void:
	_index_scale += index_movement
	_index_scale = mini(_index_scale, len(possible_zoom_levels) - 1)
	_index_scale = maxi(_index_scale, 0)
	VisConfig.UI_manager.UI_scale = possible_zoom_levels[_index_scale]
	_increase_scale_button.disabled =  _index_scale == len(possible_zoom_levels) - 1
	_decrease_scale_button.disabled =  _index_scale == 0
	

func _FEAGI_on_burst_delay_change(new_delay_between_bursts_seconds: float) -> void:
	_refresh_rate_field.current_float =  1.0 / new_delay_between_bursts_seconds

func _user_on_burst_delay_change(new_delay_between_bursts_seconds: float) -> void:
	FeagiRequests.set_delay_between_bursts(1.0 / new_delay_between_bursts_seconds)

func _view_selected(new_state: TempSplit.STATES) -> void:
	VisConfig.UI_manager.temp_get_temp_split().set_view(new_state)

func _details_section_toggle(_irrelevant: bool) -> void:
	size = Vector2(0,0) #force to smallest possible size

func _open_cortical_areas() -> void:
	VisConfig.UI_manager.window_manager.spawn_cortical_view()

func _open_create_cortical() -> void:
	VisConfig.UI_manager.window_manager.spawn_create_cortical()

func _open_neuron_morphologies() -> void:
	VisConfig.UI_manager.window_manager.spawn_manager_morphology()

func _open_create_morpology() -> void:
	VisConfig.UI_manager.window_manager.spawn_create_morphology()

func _open_tutorials() -> void:
	VisConfig.UI_manager.window_manager.spawn_tutorial()

func _open_options() -> void:
	VisConfig.UI_manager.window_manager.spawn_user_options()

func _FEAGI_retireved_latency(latency_ms: int) -> void:
	_latency_field.current_int = latency_ms

func _smaller_scale() -> void:
	_set_scale(-1)
	
func _bigger_scale() -> void:
	_set_scale(1)

func _update_counts(stats: Dictionary) -> void:
	_neuron_count.text = _shorten_number(stats["neuron_count"]) + "/" + _shorten_number(stats["neuron_count_max"])
	_synapse_count.text = _shorten_number(stats["synapse_count"]) + "/" + _shorten_number(stats["synapse_count_max"])

func _shorten_number(num: float) -> String:
	var a: int
	if num > 1000000:
		a = roundi(num / 1000000.0)
		return str(a) + "M"
	if num > 1000:
		a = roundi(num / 1000.0)
		return str(a) + "K"
	return str(a)


func _update_size(multiplier: float) -> void:
	var new_seperation: int = int(_default_seperation * multiplier)
	add_theme_constant_override(&"seperation", new_seperation)
	size = Vector2(0,0) #force to smallest possible size
