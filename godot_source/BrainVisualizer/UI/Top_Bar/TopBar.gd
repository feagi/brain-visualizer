extends HBoxContainer
class_name TopBar

@export var possible_zoom_levels: Array[float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
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


func _ready():
	# references
	_refresh_rate_field = $DetailsPanel/MarginContainer/Details/Place_child_nodes_here/RR_Float
	var state_indicator: StateIndicator = $DetailsPanel/MarginContainer/Details/Place_child_nodes_here/StateIndicator
	var details_section: MultiItemCollapsible = $DetailsPanel/MarginContainer/Details
	_index_scale = starting_size_index
	
	_increase_scale_button = $ChangeSize/MarginContainer/HBoxContainer/Bigger
	_decrease_scale_button = $ChangeSize/MarginContainer/HBoxContainer/Smaller
	
	_neuron_count = $DetailsPanel/MarginContainer/Details/Place_child_nodes_here/neuron
	_synapse_count = $DetailsPanel/MarginContainer/Details/Place_child_nodes_here/synapse
	
	# FEAGI data
	# Burst rate
	_refresh_rate_field.float_confirmed.connect(_user_on_burst_delay_change)
	FeagiCore.delay_between_bursts_updated.connect(_FEAGI_on_burst_delay_change)
	_FEAGI_on_burst_delay_change(FeagiCore.delay_between_bursts)
	
	## Count Limits
	FeagiCore.feagi_local_cache.neuron_count_max_changed.connect(_update_neuron_count_max)
	FeagiCore.feagi_local_cache.synapse_count_max_changed.connect(_update_synapse_count_max)
	FeagiCore.feagi_local_cache.neuron_count_current_changed.connect(_update_neuron_count_current)
	FeagiCore.feagi_local_cache.synapse_count_current_changed.connect(_update_synapse_count_current)

	#NOTE: State Indeicator handles updates from FEAGI independently, no need to do it here
	
	_theme_custom_scaler.setup(self, theme_scalar_nodes_to_not_include_or_search, BV.UI.loaded_theme) #TODO change way of getting current theme
	
	

func _set_scale(index_movement: int) -> void:
	_index_scale += index_movement
	_index_scale = mini(_index_scale, len(possible_zoom_levels) - 1)
	_index_scale = maxi(_index_scale, 0)
	_increase_scale_button.disabled =  _index_scale == len(possible_zoom_levels) - 1
	_decrease_scale_button.disabled =  _index_scale == 0
	

func _FEAGI_on_burst_delay_change(new_delay_between_bursts_seconds: float) -> void:
	_refresh_rate_field.editable = new_delay_between_bursts_seconds != 0.0
	if new_delay_between_bursts_seconds == 0.0:
		_refresh_rate_field.current_float = 0.0
		return
	_refresh_rate_field.current_float =  1.0 / new_delay_between_bursts_seconds

func _user_on_burst_delay_change(new_delay_between_bursts_seconds: float) -> void:
	if new_delay_between_bursts_seconds <= 0.0:
		_refresh_rate_field.current_float = 1.0 / FeagiCore.delay_between_bursts
		return
	FeagiCore.requests.update_burst_delay(1.0 / new_delay_between_bursts_seconds)


func _view_selected(new_state: TempSplit.STATES) -> void:
	request_UI_mode.emit(new_state)

func _open_cortical_areas() -> void:
	pass
	#VisConfig.UI_manager.window_manager.spawn_cortical_view()

func _open_create_cortical() -> void:
	pass
	#VisConfig.UI_manager.window_manager.spawn_create_cortical()

func _open_neuron_morphologies() -> void:
	pass
	#VisConfig.UI_manager.window_manager.spawn_manager_morphology()

func _open_create_morpology() -> void:
	pass
	#VisConfig.UI_manager.window_manager.spawn_create_morphology()

func _open_tutorials() -> void:
	pass
	#VisConfig.UI_manager.window_manager.spawn_tutorial()

func _open_options() -> void:
	pass
	#VisConfig.UI_manager.window_manager.spawn_user_options()

#func _FEAGI_retireved_latency(latency_ms: int) -> void:
#	_latency_field.current_int = latency_ms

func _smaller_scale() -> void:
	_set_scale(-1)
	
func _bigger_scale() -> void:
	_set_scale(1)

func _update_neuron_count_max(val: int) -> void:
	_neuron_count.text = _shorten_number(FeagiCore.feagi_local_cache.neuron_count_current) + "/" + _shorten_number(val)
	
func _update_neuron_count_current(val: int) -> void:
	_neuron_count.text = _shorten_number(val) + "/" + _shorten_number(FeagiCore.feagi_local_cache.neuron_count_current)

func _update_synapse_count_max(val: int) -> void:
	_synapse_count.text = _shorten_number(FeagiCore.feagi_local_cache.synapse_count_current) + "/" + _shorten_number(val)
	
func _update_synapse_count_current(val: int) -> void:
	_synapse_count.text = _shorten_number(val) + "/" + _shorten_number(FeagiCore.feagi_local_cache.synapse_count_max)

func _shorten_number(num: float) -> String:
	var a: int
	if num > 1000000:
		a = roundi(num / 1000000.0)
		return str(a) + "M"
	if num > 1000:
		a = roundi(num / 1000.0)
		return str(a) + "K"
	return str(a)

