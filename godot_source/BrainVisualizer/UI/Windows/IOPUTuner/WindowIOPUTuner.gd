extends BaseDraggableWindow
class_name WindowIOPUTuner

const WINDOW_NAME: StringName = "IOPU_tuner"

var _vision_button: Button
var _no_section: VBoxContainer
var _vision: WindowIOPUTuner_Vision

func _ready() -> void:
	super()
	_vision_button = _window_internals.get_node("HBoxContainer/IOPUs/Selection/Vision")
	_no_section = _window_internals.get_node("HBoxContainer/SpecificSettings/Nothing")
	_vision = _window_internals.get_node("HBoxContainer/SpecificSettings/Vision")

func setup() -> void:
	_setup_base_window(WINDOW_NAME)
	
	if not FeagiCore.feagi_local_cache.cortical_areas.try_to_get_cortical_area_by_ID("iv00_C"):
		_vision_button.disabled = true
		_vision_button.tooltip_text = "No Vision Cortical Areas Found!"


func _vision_pressed() -> void:
	
	pass
