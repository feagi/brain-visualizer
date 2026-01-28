extends BaseDraggableWindow
class_name WindowIPUOPUConfig
## UI window for browsing and editing IPU/OPU device registrations across agents.

const WINDOW_NAME: StringName = "ipu_opu_config"
const SECTION_INPUT: StringName = "inputs"
const SECTION_OUTPUT: StringName = "outputs"

const _DEFAULT_INPUT_ICON: StringName = "res://BrainVisualizer/UI/GenericResources/ButtonIcons/input.png"
const _DEFAULT_OUTPUT_ICON: StringName = "res://BrainVisualizer/UI/GenericResources/ButtonIcons/output.png"
const _DEFAULT_GENERIC_ICON: StringName = "res://BrainVisualizer/UI/GenericResources/ButtonIcons/setting.png"

var _all_agents_toggle: CheckBox
var _agent_list_container: VBoxContainer
var _io_tabs: TabContainer
var _inputs_grid: GridContainer
var _outputs_grid: GridContainer
var _status_label: Label
var _config_content: VBoxContainer
var _refresh_button: Button
var _apply_button: Button

var _agent_capabilities_map: Dictionary = {}
var _selected_agents: Array[StringName] = []
var _selected_device_key: StringName = ""
var _selected_section: StringName = SECTION_OUTPUT
var _editor_by_agent: Dictionary = {}
var _device_buttons: Dictionary = { SECTION_INPUT: {}, SECTION_OUTPUT: {} }

## Initializes the window and optionally focuses on a device section.
func setup_with_focus(device_key: StringName = "", section: StringName = SECTION_OUTPUT) -> void:
	_setup_base_window(WINDOW_NAME)
	_titlebar.title = "IPU/OPU Configuration"
	_selected_device_key = device_key
	_selected_section = section
	_bind_controls()
	await _refresh_from_feagi()

## Initializes focus based on a selected cortical area.
func setup_for_area(area: AbstractCorticalArea) -> void:
	var focus_key: StringName = &""
	var focus_section: StringName = SECTION_OUTPUT
	if area is IPUCorticalArea or area is OPUCorticalArea:
		focus_key = area.controller_ID
		focus_section = SECTION_OUTPUT if area is OPUCorticalArea else SECTION_INPUT
	setup_with_focus(focus_key, focus_section)

## Initialize node bindings once the window enters the scene tree.
func _ready() -> void:
	super._ready()
	_bind_controls()
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_on_viewport_resized):
		get_viewport().size_changed.connect(_on_viewport_resized)
	_apply_fullscreen_layout()

## Keep the window stretched to the viewport on theme updates.
func _theme_updated(new_theme: Theme) -> void:
	super._theme_updated(new_theme)
	_apply_fullscreen_layout()

## Override shrink behavior from BaseDraggableWindow.
func _delay_shrink_window() -> void:
	_apply_fullscreen_layout()

## Ensure the window stays full-screen on viewport resize.
func _on_viewport_resized() -> void:
	_apply_fullscreen_layout()

## Apply full-screen anchors and size to match the viewport.
func _apply_fullscreen_layout() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var target_size := viewport_size * 0.95
	var target_position := (viewport_size - target_size) * 0.5
	anchors_preset = Control.PRESET_TOP_LEFT
	position = target_position
	size = target_size
	custom_minimum_size = target_size

## Bind node references and UI signals.
func _bind_controls() -> void:
	if _all_agents_toggle != null:
		return
	_all_agents_toggle = $WindowPanel/WindowMargin/WindowInternals/HeaderPanel/HeaderMargin/HeaderRow/AgentPanel/AgentAllToggle
	_agent_list_container = $WindowPanel/WindowMargin/WindowInternals/HeaderPanel/HeaderMargin/HeaderRow/AgentPanel/AgentScroll/AgentList
	_io_tabs = $WindowPanel/WindowMargin/WindowInternals/HeaderPanel/HeaderMargin/HeaderRow/IOSectionTabs
	_inputs_grid = $WindowPanel/WindowMargin/WindowInternals/HeaderPanel/HeaderMargin/HeaderRow/IOSectionTabs/Inputs/InputsGrid
	_outputs_grid = $WindowPanel/WindowMargin/WindowInternals/HeaderPanel/HeaderMargin/HeaderRow/IOSectionTabs/Outputs/OutputsGrid
	_status_label = $WindowPanel/WindowMargin/WindowInternals/BodyPanel/BodyMargin/BodyContent/StatusLabel
	_config_content = $WindowPanel/WindowMargin/WindowInternals/BodyPanel/BodyMargin/BodyContent/ConfigScroll/ConfigContent
	_refresh_button = $WindowPanel/WindowMargin/WindowInternals/BodyPanel/BodyMargin/BodyContent/ButtonRow/RefreshButton
	_apply_button = $WindowPanel/WindowMargin/WindowInternals/BodyPanel/BodyMargin/BodyContent/ButtonRow/ApplyButton
	_all_agents_toggle.toggled.connect(_on_all_agents_toggled)
	_io_tabs.tab_changed.connect(_on_tab_changed)
	_refresh_button.pressed.connect(_on_refresh_pressed)
	_apply_button.pressed.connect(_on_apply_pressed)

## Fetches latest agent capabilities and updates the UI.
func _refresh_from_feagi() -> void:
	if FeagiCore == null or FeagiCore.requests == null:
		_set_status("FEAGI is not available. Please connect and retry.")
		return
	if not FeagiCore.can_interact_with_feagi():
		_set_status("FEAGI is not ready yet. Please retry after genome load completes.")
		return
	_set_status("Refreshing agent capabilities...")
	await FeagiCore.requests.refresh_agent_capabilities_cache(true)
	_load_from_cache()

## Loads cached agent data and rebuilds UI elements.
func _load_from_cache() -> void:
	_agent_capabilities_map = FeagiCore.feagi_local_cache.agent_capabilities_map
	_build_agent_list()
	_rebuild_device_tabs()
	_focus_device_if_available()

## Build agent multi-selection list from cached capabilities.
func _build_agent_list() -> void:
	for child in _agent_list_container.get_children():
		child.queue_free()
	_selected_agents.clear()
	var agent_ids: Array[StringName] = []
	for agent_id in _agent_capabilities_map.keys():
		agent_ids.append(agent_id)
	agent_ids.sort()
	for agent_id in agent_ids:
		var checkbox := CheckBox.new()
		checkbox.text = String(agent_id)
		checkbox.toggled.connect(_on_agent_toggled.bind(agent_id))
		_agent_list_container.add_child(checkbox)
	_selected_agents = agent_ids.duplicate()
	_set_checkbox_state(_all_agents_toggle, agent_ids.size() > 0)
	_set_all_agent_checkboxes(true)

## Handle the "All agents" toggle.
func _on_all_agents_toggled(pressed: bool) -> void:
	_set_all_agent_checkboxes(pressed)
	_update_selected_agents_from_ui()
	_rebuild_device_tabs()

## Track individual agent selections.
func _on_agent_toggled(_pressed: bool, agent_id: StringName) -> void:
	_update_selected_agents_from_ui()
	var all_selected := _selected_agents.size() == _agent_capabilities_map.size()
	_set_checkbox_state(_all_agents_toggle, all_selected)
	_rebuild_device_tabs()
	_focus_device_if_available()

## Keeps the agent list checkbox states aligned.
func _set_all_agent_checkboxes(pressed: bool) -> void:
	for child in _agent_list_container.get_children():
		if child is CheckBox:
			_set_checkbox_state(child as CheckBox, pressed)

## Update selected agent list from UI state.
func _update_selected_agents_from_ui() -> void:
	_selected_agents.clear()
	for child in _agent_list_container.get_children():
		if child is CheckBox and (child as CheckBox).button_pressed:
			_selected_agents.append(StringName((child as CheckBox).text))

## Updates the device grid buttons for inputs and outputs.
func _rebuild_device_tabs() -> void:
	_clear_grid(_inputs_grid)
	_clear_grid(_outputs_grid)
	_device_buttons[SECTION_INPUT] = {}
	_device_buttons[SECTION_OUTPUT] = {}
	var input_devices := _collect_device_keys(false)
	var output_devices := _collect_device_keys(true)
	for device_key in input_devices:
		var button := _create_device_button(device_key, false)
		_inputs_grid.add_child(button)
		_device_buttons[SECTION_INPUT][device_key] = button
	for device_key in output_devices:
		var button := _create_device_button(device_key, true)
		_outputs_grid.add_child(button)
		_device_buttons[SECTION_OUTPUT][device_key] = button

## Collect device keys for a given IO direction from selected agents.
func _collect_device_keys(is_output: bool) -> Array[StringName]:
	var keys: Array[StringName] = []
	var section_key := "output_units_and_decoder_properties" if is_output else "input_units_and_encoder_properties"
	for agent_id in _selected_agents:
		if not _agent_capabilities_map.has(agent_id):
			continue
		var agent_entry = _agent_capabilities_map[agent_id]
		if agent_entry is Dictionary and agent_entry.has("device_registrations"):
			var registrations = agent_entry["device_registrations"]
			if registrations is Dictionary and registrations.has(section_key):
				var unit_dict = registrations[section_key]
				if unit_dict is Dictionary:
					for device_key in unit_dict.keys():
						if device_key not in keys:
							keys.append(device_key)
	keys.sort()
	return keys

## Creates a device button with a default icon and selection handler.
func _create_device_button(device_key: StringName, is_output: bool) -> Button:
	var button := Button.new()
	button.text = String(device_key)
	button.custom_minimum_size = Vector2(180, 40)
	button.icon = _get_device_icon(is_output)
	button.pressed.connect(_on_device_selected.bind(device_key, is_output))
	return button

## Resolve a default icon for device buttons.
func _get_device_icon(is_output: bool) -> Texture2D:
	var icon_path := _DEFAULT_OUTPUT_ICON if is_output else _DEFAULT_INPUT_ICON
	if ResourceLoader.exists(icon_path):
		return load(icon_path)
	if ResourceLoader.exists(_DEFAULT_GENERIC_ICON):
		return load(_DEFAULT_GENERIC_ICON)
	return null

## Handle device selection from the grid.
func _on_device_selected(device_key: StringName, is_output: bool) -> void:
	_selected_device_key = device_key
	_selected_section = SECTION_OUTPUT if is_output else SECTION_INPUT
	_render_device_config()

## Handle manual tab changes.
func _on_tab_changed(tab_index: int) -> void:
	_selected_section = SECTION_INPUT if tab_index == 0 else SECTION_OUTPUT
	_render_device_config()

## Focus the device and section if available, otherwise pick the first available.
func _focus_device_if_available() -> void:
	if _selected_device_key != "":
		var section_buttons: Dictionary = _device_buttons.get(_selected_section, {})
		if section_buttons.has(_selected_device_key):
			_io_tabs.current_tab = 0 if _selected_section == SECTION_INPUT else 1
			_render_device_config()
			return
	var fallback_keys: Array[StringName] = _collect_device_keys(false)
	if fallback_keys.is_empty():
		fallback_keys = _collect_device_keys(true)
		if fallback_keys.is_empty():
			_selected_device_key = ""
			_set_status("No device registrations available for selected agents.")
			_clear_config_content()
			return
		_selected_section = SECTION_OUTPUT
		_selected_device_key = fallback_keys[0]
	else:
		_selected_section = SECTION_INPUT
		_selected_device_key = fallback_keys[0]
	_io_tabs.current_tab = 0 if _selected_section == SECTION_INPUT else 1
	_render_device_config()

## Render configuration editors for the selected device across agents.
func _render_device_config() -> void:
	_clear_config_content()
	_editor_by_agent.clear()
	if _selected_device_key == "":
		_set_status("Select a device to configure.")
		return
	_set_status("Editing %s (%s)" % [_selected_device_key, _selected_section])
	var section_key := "output_units_and_decoder_properties" if _selected_section == SECTION_OUTPUT else "input_units_and_encoder_properties"
	for agent_id in _selected_agents:
		var header := Label.new()
		header.text = "Agent: %s" % agent_id
		_config_content.add_child(header)
		if not _agent_capabilities_map.has(agent_id):
			_add_info_label("No data available for this agent.")
			continue
		var agent_entry = _agent_capabilities_map[agent_id]
		if not (agent_entry is Dictionary) or not agent_entry.has("device_registrations"):
			_add_info_label("No device registrations available.")
			continue
		var registrations = agent_entry["device_registrations"]
		if not (registrations is Dictionary) or not registrations.has(section_key):
			_add_info_label("No device registrations available.")
			continue
		var device_dict = registrations[section_key]
		if not (device_dict is Dictionary) or not device_dict.has(_selected_device_key):
			_add_info_label("No %s registration available." % _selected_device_key)
			continue
		var editor := TextEdit.new()
		editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
		editor.custom_minimum_size = Vector2(0, 180)
		editor.text = JSON.stringify(device_dict[_selected_device_key], "\t", false)
		_config_content.add_child(editor)
		_editor_by_agent[agent_id] = editor

## Apply edited JSON to the cached agent capability map.
func _on_apply_pressed() -> void:
	if _selected_device_key == "":
		return
	var updated_map: Dictionary = _agent_capabilities_map.duplicate(true)
	var section_key := "output_units_and_decoder_properties" if _selected_section == SECTION_OUTPUT else "input_units_and_encoder_properties"
	for agent_id in _editor_by_agent.keys():
		var editor: TextEdit = _editor_by_agent[agent_id]
		var raw_text := editor.text.strip_edges()
		var parsed = JSON.parse_string(raw_text)
		if parsed == null and raw_text != "null":
			_show_error_popup("Invalid JSON", "Agent %s has invalid JSON." % agent_id)
			return
		if parsed is not Array:
			_show_error_popup("Invalid Data", "Agent %s must provide a JSON array." % agent_id)
			return
		if not updated_map.has(agent_id):
			continue
		var agent_entry = updated_map[agent_id]
		if not (agent_entry is Dictionary) or not agent_entry.has("device_registrations"):
			continue
		var registrations = agent_entry["device_registrations"]
		if not (registrations is Dictionary) or not registrations.has(section_key):
			continue
		var device_dict = registrations[section_key]
		if device_dict is Dictionary:
			device_dict[_selected_device_key] = parsed
	FeagiCore.feagi_local_cache.set_agent_capabilities_map(updated_map)
	_agent_capabilities_map = updated_map
	BV.NOTIF.add_notification("Device configuration updated in local cache.")

## Refresh from FEAGI and rebuild UI.
func _on_refresh_pressed() -> void:
	await _refresh_from_feagi()

## Helper to clear the configuration content container.
func _clear_config_content() -> void:
	for child in _config_content.get_children():
		child.queue_free()

## Helper to add inline info labels.
func _add_info_label(message: String) -> void:
	var label := Label.new()
	label.text = message
	_config_content.add_child(label)

## Update the status line text.
func _set_status(message: String) -> void:
	if _status_label != null:
		_status_label.text = message

## Helper to update checkbox state without triggering signals.
func _set_checkbox_state(checkbox: CheckBox, pressed: bool) -> void:
	if checkbox == null:
		return
	if checkbox.has_method("set_pressed_no_signal"):
		checkbox.set_pressed_no_signal(pressed)
	else:
		checkbox.button_pressed = pressed

## Helper to clear all children from a grid container.
func _clear_grid(grid: GridContainer) -> void:
	for child in grid.get_children():
		child.queue_free()

## Display a modal error popup for invalid edits.
func _show_error_popup(title: String, message: String) -> void:
	BV.WM.spawn_popup(ConfigurablePopupDefinition.create_single_button_close_popup(title, message))
