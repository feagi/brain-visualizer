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

## True while the inspector [ToggleImageDropDown] menu is open (used by [CustomTooltipTrigger] on this bar).
func is_inspector_dropdown_menu_open() -> bool:
	return _dropdown != null and _dropdown.is_menu_open()


func _ready() -> void:
	# Trigger uses inspectors_*.jpg from scene; submenu row 0 keeps connection_inspector_*.
	if _global_button != null:
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


## Syncs the Connection inspector latch and eye button visuals without emitting [signal activity_mode_changed].
## Used when turning the mode off from the floating "Stop Inspector" control so UI matches scene state.
func set_connection_inspector_enabled(enabled: bool) -> void:
	_global_connections_enabled = enabled
	_refresh_global_button_visual_state()
