extends PanelContainer
class_name TopBar

var _refresh_rate_field: FloatInput
var _window_manager: WindowManager

func _ready():
	_refresh_rate_field = $HBoxContainer/Details/Place_child_nodes_here/RR_Float
	var state_indicator: StateIndicator = $HBoxContainer/Details/Place_child_nodes_here/StateIndicator
	var details_section: MultiItemCollapsible = $HBoxContainer/Details
	_window_manager = VisConfig.UI_manager.window_manager

	# from FEAGI
	FeagiCacheEvents.delay_between_bursts_updated.connect(_FEAGI_on_burst_delay_change)
	FeagiEvents.retrieved_latest_FEAGI_health.connect(state_indicator.set_health_states)
	# from user
	_refresh_rate_field.float_confirmed.connect(_user_on_burst_delay_change)
	details_section.toggled.connect(_details_section_toggle)
	
	size = Vector2(0,0) #force to smallest possible size


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

func _open_neuron_morphologies() -> void:
	VisConfig.UI_manager.window_manager.spawn_manager_morphology()

func _open_tutorials() -> void:
	VisConfig.UI_manager.window_manager.spawn_tutorial()
