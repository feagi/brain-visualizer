extends BoxContainer
class_name ActivityVisualizationDropDown

## Emits action-style changes for activity controls.
## - action = "global_neural_connections", enabled toggles on/off (latched push behavior)
## - action = "voxel_inspector", enabled is always true (open/focus inspector window)
signal activity_mode_changed(action: StringName, enabled: bool)

const ACTION_GLOBAL_NEURAL_CONNECTIONS: StringName = &"global_neural_connections"
const ACTION_VOXEL_INSPECTOR: StringName = &"voxel_inspector"
const ACTION_MEMORY_INSPECTOR: StringName = &"memory_inspector"

@onready var _dropdown: ToggleImageDropDown = $ToggleImageDropDown
@onready var _global_button: TextureButton = $ToggleImageDropDown/PanelContainer/BoxContainer/GlobalNeuralConnections

var _global_connections_enabled: bool = false

func _ready() -> void:
	# Fixed trigger icon: keep global-neural-connections icon on the dropdown button.
	if _global_button != null and _dropdown != null:
		_dropdown.texture_normal = _global_button.texture_normal
		_dropdown.texture_pressed = _global_button.texture_pressed
		_dropdown.texture_hover = _global_button.texture_hover
		_dropdown.texture_disabled = _global_button.texture_disabled
		# Make this entry a true push button in the menu (latched visual state).
		_global_button.toggle_mode = true
	_refresh_global_button_visual_state()

func _user_request_activity(_view_name: StringName, index: int) -> void:
	if index == 0:
		_global_connections_enabled = not _global_connections_enabled
		_refresh_global_button_visual_state()
		activity_mode_changed.emit(ACTION_GLOBAL_NEURAL_CONNECTIONS, _global_connections_enabled)
		return
	if index == 1:
		activity_mode_changed.emit(ACTION_VOXEL_INSPECTOR, true)
		return
	if index == 2:
		activity_mode_changed.emit(ACTION_MEMORY_INSPECTOR, true)


func _refresh_global_button_visual_state() -> void:
	if _global_button != null:
		_global_button.button_pressed = _global_connections_enabled
