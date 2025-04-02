extends Node
class_name UI_BrainMonitor_InteractivePreview
## Allows the user to see / edit a 3D volume in BM. Useful for seeing where something will be moved / added

# NOTE: You are allowed to call queue_free on this object, it will be cleaned up automatically by its native BM. However, note BM may free this as well, so be sure to check validity before doing anything!
var _renderer: UI_BrainMonitor_InteractivePreviewRenderer

signal user_moved_preview(new_FEAGI_space_position: Vector3i)
signal user_resized_preview(new_dimensions: Vector3i)

func setup(initial_FEAGI_position: Vector3i, initial_dimensions: Vector3i, show_voxels: bool) -> void:
	_renderer = UI_BrainMonitor_InteractivePreviewRenderer.new()
	add_child(_renderer)
	_renderer.setup(initial_FEAGI_position, initial_dimensions, show_voxels)

## If you wish to externally connect signals to this, you can pass them in as arrays
func connect_UI_signals(move_signals: Array[Signal], resize_signals: Array[Signal], close_signals: Array[Signal]) -> void:
	for move_signal in move_signals:
		move_signal.connect(set_new_position)
	for resize_signal in resize_signals:
		resize_signal.connect(set_new_dimensions)
	for close_signal in close_signals:
		close_signal.connect(queue_free)

func set_new_position(new_position_FEAGI_space: Vector3i) -> void:
	_renderer.update_position_with_new_FEAGI_coordinate(new_position_FEAGI_space)

func set_new_dimensions(new_dimensions: Vector3i) -> void:
	_renderer.update_dimensions(new_dimensions)
