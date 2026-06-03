extends VBoxContainer
class_name PartSpawnCorticalAreaMemory

signal user_selected_back()
signal user_request_close_window()

## Fixed 1×1×1 for memory cortical areas (matches API usage).
const MEMORY_PREVIEW_DIMENSIONS: Vector3i = Vector3i(1, 1, 1)

var location: Vector3iSpinboxField
var cortical_name: TextInput
var _line_initial_neuron_lifespan: IntInput
var _line_lifespan_growth_rate: IntInput
var _line_longterm_memory_threshold: IntInput
var _line_temporal_depth: IntInput
var _check_mp_learning: ToggleButton
var _active_brain_monitor: UI_BrainMonitor_3DScene = null
var _preview: UI_BrainMonitor_InteractivePreview = null

func _ready() -> void:
	location = $location/location
	cortical_name = $name/name
	_line_initial_neuron_lifespan = $PanelContainer/MemoryParameters/initial_neuron_lifespan/initial_neuron_lifespan
	_line_lifespan_growth_rate = $PanelContainer/MemoryParameters/lifespan_growth_rate/lifespan_growth_rate
	_line_longterm_memory_threshold = $PanelContainer/MemoryParameters/longterm_memory_threshold/longterm_memory_threshold
	_line_temporal_depth = $PanelContainer/MemoryParameters/temporal_depth/temporal_depth
	_check_mp_learning = $PanelContainer/MemoryParameters/mp_learning_enabled/mp_learning_enabled


func cortical_type_selected(_cortical_type: AbstractCorticalArea.CORTICAL_AREA_TYPE, preview_close_signals: Array[Signal], host_bm = null) -> void:
	_stop_preview_relocation()
	var move_signals: Array[Signal] = [location.user_updated_vector]
	var resize_signals: Array[Signal] = []
	_active_brain_monitor = host_bm if host_bm != null else BV.UI.get_active_brain_monitor()
	if _active_brain_monitor == null:
		push_error("PartSpawnCorticalAreaMemory: No brain monitor available for preview creation!")
		return
	_preview = _active_brain_monitor.create_preview(
		location.current_vector,
		MEMORY_PREVIEW_DIMENSIONS,
		false,
		_cortical_type,
		null,
		false,
		false
	)
	_preview.connect_UI_signals(move_signals, resize_signals, preview_close_signals)
	if _active_brain_monitor.has_method("start_cortical_preview_relocation"):
		_active_brain_monitor.start_cortical_preview_relocation(
			_preview,
			location.current_vector,
			Callable(self, "_on_preview_moved_via_gizmo")
		)
	for preview_signal in preview_close_signals:
		var stop_callable := Callable(self, "_stop_preview_relocation")
		if not preview_signal.is_connected(stop_callable):
			preview_signal.connect(stop_callable)


func _on_preview_moved_via_gizmo(new_coords: Vector3i) -> void:
	location.current_vector = new_coords


func _stop_preview_relocation() -> void:
	if _preview == null:
		return
	if _active_brain_monitor != null and _active_brain_monitor.has_method("stop_cortical_preview_relocation"):
		_active_brain_monitor.stop_cortical_preview_relocation(_preview)
	_preview = null


## Same keys as [AdvancedCorticalProperties] memory section (FEAGI PUT / cortical area).
func get_memory_parameters_for_api() -> Dictionary:
	return {
		"neuron_init_lifespan": _line_initial_neuron_lifespan.current_int,
		"neuron_lifespan_growth_rate": _line_lifespan_growth_rate.current_int,
		"neuron_longterm_mem_threshold": _line_longterm_memory_threshold.current_int,
		"temporal_depth": _line_temporal_depth.current_int,
		"mp_learning_enabled": _check_mp_learning.button_pressed if _check_mp_learning != null else false,
	}
