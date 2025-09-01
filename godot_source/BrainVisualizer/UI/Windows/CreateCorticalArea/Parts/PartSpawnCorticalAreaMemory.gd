extends VBoxContainer
class_name PartSpawnCorticalAreaMemory

signal user_selected_back()
signal user_request_close_window()

var location: Vector3iSpinboxField
var dimensions: Vector3iSpinboxField
var cortical_name: TextInput

func _ready() -> void:
	location = $location/location
	dimensions = $PanelContainer/dimensions/dimensions
	cortical_name = $name/name

func cortical_type_selected(_cortical_type: AbstractCorticalArea.CORTICAL_AREA_TYPE, preview_close_signals: Array[Signal]) -> void:
	var move_signals: Array[Signal] = [location.user_updated_vector]
	var resize_signals: Array[Signal] = [dimensions.user_updated_vector]
	var active_bm = BV.UI.get_active_brain_monitor()
	if active_bm == null:
		push_error("PartSpawnCorticalAreaMemory: No brain monitor available for preview creation!")
		return
	var preview: UI_BrainMonitor_InteractivePreview = active_bm.create_preview(location.current_vector, dimensions.current_vector, false, _cortical_type) # Pass cortical area type for correct shape!
	preview.connect_UI_signals(move_signals, resize_signals, preview_close_signals)
