extends VBoxContainer
class_name PartSpawnCorticalAreaCustom

signal user_selected_back()
signal user_request_close_window()

var dimensions: Vector3iSpinboxField
var location: Vector3iSpinboxField
var cortical_name: TextInput
var _active_brain_monitor: UI_BrainMonitor_3DScene = null
var _preview: UI_BrainMonitor_InteractivePreview = null

func _ready() -> void:
	location = $location/location
	cortical_name = $name/name
	dimensions = $dimensions/dimensions

func cortical_type_selected(_cortical_type: AbstractCorticalArea.CORTICAL_AREA_TYPE, preview_close_signals: Array[Signal], host_bm = null) -> void:
	_stop_preview_relocation()
	var move_signals: Array[Signal] = [location.user_updated_vector]
	var resize_signals: Array[Signal] = [dimensions.user_updated_vector]
	_active_brain_monitor = host_bm if host_bm != null else BV.UI.get_active_brain_monitor()
	if _active_brain_monitor == null:
		push_error("PartSpawnCorticalAreaCustom: No brain monitor available for preview creation!")
		return
	_preview = _active_brain_monitor.create_preview(location.current_vector, dimensions.current_vector, false, _cortical_type, null, false, false)
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
