extends Object
class_name GenericSinglePreviewHandler
## Responsible for handling single previews across various UI Elements

var _BM_preview: BrainMonitorSinglePreview = null


func start_BM_preview(preview_dimensions: Vector3, preview_position: Vector3, color: Color = BrainMonitorSinglePreview.DEFAULT_COLOR, is_rendering: bool = true) -> void:
	_BM_preview = VisConfig.UI_manager.spawn_BV_single_preview(preview_dimensions, preview_position, color, is_rendering)

func connect_BM_preview(coordinates_3D_changed: Signal, dimensions_changed: Signal, close_signals: Array[Signal]) -> void:
	if _BM_preview == null:
		push_error("Unable to connect to BM preview when it has not been initialized")
		return
	coordinates_3D_changed.connect(_BM_preview.update_position)
	dimensions_changed.connect(_BM_preview.update_size)
	for close_signal in close_signals: #TODO this isnt bm specific!
		close_signal.connect(_BM_preview.delete_preview)

func delete_preview() -> void:
	if _BM_preview != null:
		_BM_preview.delete_preview()
	free()
