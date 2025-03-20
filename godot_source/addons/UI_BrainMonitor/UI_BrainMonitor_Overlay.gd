extends BoxContainer
class_name UI_BrainMonitor_Overlay
## UI overlay for Brain Monitor

var _mouse_context_label: Label

func _ready() -> void:
	_mouse_context_label = $Bottom_Row/MouseContext

## Clear all text
func clear() -> void:
	_mouse_context_label.text = ""

func mouse_over_single_cortical_area(cortical_are: AbstractCorticalArea, neuron_coordinate: Vector3i) -> void:
	_mouse_context_label.text = cortical_are.friendly_name + "  " + str(neuron_coordinate)
