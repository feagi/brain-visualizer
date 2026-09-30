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
var _dropdown_mp_encoding: DropDown
var _row_mp_delta_quantization: Control
var _line_mp_delta_quantization: FloatInput
var _row_mp_ratio_quantization: Control
var _line_mp_ratio_quantization: FloatInput
var _active_brain_monitor: UI_BrainMonitor_3DScene = null
var _preview: UI_BrainMonitor_InteractivePreview = null

func _ready() -> void:
	location = $location/location
	cortical_name = $name/name
	_line_initial_neuron_lifespan = $PanelContainer/MemoryParameters/initial_neuron_lifespan/initial_neuron_lifespan
	_line_lifespan_growth_rate = $PanelContainer/MemoryParameters/lifespan_growth_rate/lifespan_growth_rate
	_line_longterm_memory_threshold = $PanelContainer/MemoryParameters/longterm_memory_threshold/longterm_memory_threshold
	_line_temporal_depth = $PanelContainer/MemoryParameters/temporal_depth/temporal_depth
	_dropdown_mp_encoding = $PanelContainer/MemoryParameters/mp_encoding/mp_encoding
	_row_mp_delta_quantization = $PanelContainer/MemoryParameters/mp_delta_quantization
	_line_mp_delta_quantization = $PanelContainer/MemoryParameters/mp_delta_quantization/mp_delta_quantization
	_row_mp_ratio_quantization = $PanelContainer/MemoryParameters/mp_ratio_quantization
	_line_mp_ratio_quantization = $PanelContainer/MemoryParameters/mp_ratio_quantization/mp_ratio_quantization
	_dropdown_mp_encoding.options = CorticalPropertyMemoryParameters.MP_ENCODING_OPTIONS
	_line_mp_delta_quantization.set_float(CorticalPropertyMemoryParameters.DEFAULT_MP_DELTA_QUANTIZATION)
	_line_mp_ratio_quantization.set_float(CorticalPropertyMemoryParameters.DEFAULT_MP_RATIO_QUANTIZATION)
	_dropdown_mp_encoding.option_changed.connect(_on_mp_encoding_changed)


func _on_mp_encoding_changed(_index: int, encoding: StringName) -> void:
	_row_mp_delta_quantization.visible = encoding == CorticalPropertyMemoryParameters.MP_ENCODING_DIFFERENTIAL
	_row_mp_ratio_quantization.visible = encoding == CorticalPropertyMemoryParameters.MP_ENCODING_RATIO


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
## Quantization is only sent for the selected change mode; FEAGI defaults the other.
func get_memory_parameters_for_api() -> Dictionary:
	var params: Dictionary = {
		"neuron_init_lifespan": _line_initial_neuron_lifespan.current_int,
		"neuron_lifespan_growth_rate": _line_lifespan_growth_rate.current_int,
		"neuron_longterm_mem_threshold": _line_longterm_memory_threshold.current_int,
		"temporal_depth": _line_temporal_depth.current_int,
	}
	var encoding: StringName = _dropdown_mp_encoding.selected_item
	params.merge(CorticalPropertyMemoryParameters.mp_encoding_to_keys(encoding))
	if encoding == CorticalPropertyMemoryParameters.MP_ENCODING_DIFFERENTIAL:
		params["mp_delta_quantization"] = _line_mp_delta_quantization.current_float
	elif encoding == CorticalPropertyMemoryParameters.MP_ENCODING_RATIO:
		params["mp_ratio_quantization"] = _line_mp_ratio_quantization.current_float
	return params
