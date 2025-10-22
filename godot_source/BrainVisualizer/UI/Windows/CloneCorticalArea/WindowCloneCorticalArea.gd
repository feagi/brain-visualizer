extends BaseDraggableWindow
class_name WindowCloneCorticalArea

const WINDOW_NAME: StringName = "clone_cortical"

signal null_dimensions_signal(vector: Vector3i) #not utilized but required as an empty input for a func

const NAME_APPEND: StringName = &"_copy"
const NAME_MAX_LENGTH: int = 32 # TODO this should go to a better spot
const OFFSET_3D: Vector3i = Vector3i(10,0,0)
const OFFSET_2D: Vector2i = Vector2i(10,10)

var _field_cortical_name: TextInput
var _field_3d_location: Vector3iSpinboxField
var _field_2d_location: Vector2iSpinboxField
var _field_wiring_toggle: CheckBox
var _cloning_cortical_area: AbstractCorticalArea
var _preview: UI_BrainMonitor_InteractivePreview

func _ready() -> void:
	super()
	_field_cortical_name = _window_internals.get_node('HBoxContainer/Cortical_Name')
	_field_3d_location = _window_internals.get_node('HBoxContainer2/Coordinates_3D')
	_field_2d_location = _window_internals.get_node('HBoxContainer3/Coordinates_2D')
	_field_wiring_toggle = _window_internals.get_node('HBoxContainer4/AutoWiring')
	# Connect to window close signal to ensure preview cleanup
	close_window_requested.connect(_cleanup_preview_on_close)

func setup(cloning_cortical_area: AbstractCorticalArea) -> void:
	_setup_base_window(WINDOW_NAME)
	_cloning_cortical_area = cloning_cortical_area
	var new_name: StringName = cloning_cortical_area.friendly_name + NAME_APPEND
	if new_name.length() > NAME_MAX_LENGTH:
		new_name = cloning_cortical_area.friendly_name.left(NAME_MAX_LENGTH - NAME_APPEND.length()) + NAME_APPEND
	_field_cortical_name.text = new_name
	
	_field_3d_location.current_vector = cloning_cortical_area.coordinates_3D + OFFSET_3D
	_field_2d_location.current_vector = cloning_cortical_area.coordinates_2D + OFFSET_2D
	
	var closing_signals: Array[Signal] = []  # No close signals needed - we handle cleanup explicitly
	var move_signals: Array[Signal] = [_field_3d_location.user_updated_vector]
	var resize_signals: Array[Signal] = [null_dimensions_signal]
	# Use the brain monitor that is currently visualizing the cortical area being cloned (important for tabs!)
	var active_bm = BV.UI.get_brain_monitor_for_cortical_area(_cloning_cortical_area)
	if active_bm == null:
		push_error("WindowCloneCorticalArea: No brain monitor available for preview creation!")
		return
	_preview = active_bm.create_preview(_field_3d_location.current_vector, _cloning_cortical_area.dimensions_3D, false, _cloning_cortical_area.cortical_type, _cloning_cortical_area)
	_preview.connect_UI_signals(move_signals, resize_signals, closing_signals)


func _clone_pressed():
	#TODO check for conflicting name and alert user
	await FeagiCore.requests.clone_cortical_area(_cloning_cortical_area, _field_cortical_name.text, _field_2d_location.current_vector, _field_3d_location.current_vector, FeagiCore.feagi_local_cache.brain_regions.get_root_region(), _field_wiring_toggle.button_pressed) #TODO remove root region
	# Explicitly clean up preview before closing window
	_cleanup_preview()
	close_window()

func _cleanup_preview() -> void:
	if _preview and is_instance_valid(_preview):
		_preview.queue_free()
		_preview = null

func _cleanup_preview_on_close(_window_name: StringName) -> void:
	_cleanup_preview()
