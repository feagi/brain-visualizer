extends Node
class_name GenericSinglePreviewHandler
## Responsible for handling single previews across various UI Elements
#TODO: CB integration?

var _BM_preview: BrainMonitorSinglePreview = null

func start_BM_preview(preview_dimensions: Vector3, preview_position: Vector3, color: Color = BrainMonitorSinglePreview.DEFAULT_COLOR, is_rendering: bool = true) -> void:
	_BM_preview = BV.BM.generate_single_preview(preview_dimensions, preview_position, color, is_rendering)

func connect_BM_preview(coordinates_3D_change_signals: Array[Signal], dimensions_change_signals: Array[Signal], close_signals: Array[Signal]) -> void:
	if _BM_preview == null:
		push_error("Unable to connect to BM preview when it has not been initialized")
		return
	
	for coord_change: Signal in coordinates_3D_change_signals:
		coord_change.connect(_BM_preview.update_position)
	for dim_change: Signal in dimensions_change_signals:
		dim_change.connect(_BM_preview.update_size)
	for close_signal in close_signals:
		close_signal.connect(delete_preview)

func delete_preview(_irrelevant: Variant = null) -> void:
	if _BM_preview != null:
		_BM_preview.delete_preview()
	queue_free()
