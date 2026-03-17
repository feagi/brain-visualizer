extends BaseDraggableWindow
class_name WindowIPUOPUConfig
## UI window for browsing and editing IPU/OPU device registrations across agents.

const WINDOW_NAME: StringName = "ipu_opu_config"
const SECTION_INPUT: StringName = "inputs"
const SECTION_OUTPUT: StringName = "outputs"
const ALL_AGENTS_OPTION: StringName = "__all_agents__"

const _DEFAULT_INPUT_ICON: StringName = "res://BrainVisualizer/UI/GenericResources/ButtonIcons/input.png"
const _DEFAULT_OUTPUT_ICON: StringName = "res://BrainVisualizer/UI/GenericResources/ButtonIcons/output.png"
const _DEFAULT_GENERIC_ICON: StringName = "res://BrainVisualizer/UI/GenericResources/ButtonIcons/setting.png"
const COLLAPSIBLE_SECTION: PackedScene = preload("res://BrainVisualizer/UI/GenericElements/Collapsable/VerticalCollapsibleHiding.tscn")

const INPUT_DEVICE_ICON_IDS: Dictionary = {
	"Infrared": "iinf",
	"Proximity": "ipro",
	"Shock": "ishk",
	"Battery": "ibat",
	"Servo": "isvp",
	"AnalogGPIO": "iagp",
	"AnalogGpio": "iagp",
	"DigitalGPIO": "idgp",
	"DigitalGpio": "idgp",
	"MiscData": "imis",
	"TextEnglishInput": "iten",
	"CountInput": "icnt",
	"Vision": "iimg",
	"SegmentedVision": "isvi",
	"Accelerometer": "iacc",
	"Gyroscope": "igyr",
}

const OUTPUT_DEVICE_ICON_IDS: Dictionary = {
	"RotaryMotor": "omot",
	"PositionalServo": "opse",
	"Gaze": "ogaz",
	"MiscData": "omis",
	"TextEnglishOutput": "oten",
	"CountOutput": "ocnt",
	"ObjectSegmentation": "oifs",
	"SimpleVisionOutput": "ovout",
}

var _agent_dropdown: OptionButton
var _inputs_grid: GridContainer
var _outputs_grid: GridContainer
var _status_label: Label
var _config_content: VBoxContainer
var _save_button: Button
var _ignore_button: Button

var _agent_capabilities_map: Dictionary = {}
var _selected_agent_id: StringName = ALL_AGENTS_OPTION
var _selected_device_key: StringName = ""
var _selected_section: StringName = SECTION_OUTPUT
var _editor_by_agent: Dictionary = {}
var _device_buttons: Dictionary = { SECTION_INPUT: {}, SECTION_OUTPUT: {} }
var _input_button_group: ButtonGroup = ButtonGroup.new()
var _output_button_group: ButtonGroup = ButtonGroup.new()
var _schema_map: Dictionary = {}
var _schema_errors: Dictionary = {}
var _field_editors_by_agent: Dictionary = {}

## Initializes the window and optionally focuses on a device section.
func setup_with_focus(device_key: StringName = "", section: StringName = SECTION_OUTPUT) -> void:
	_setup_base_window(WINDOW_NAME)
	_titlebar.title = "Sensorimotor Configuration"
	_ensure_window_overlay_order()
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
	_ensure_window_overlay_order()
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_on_viewport_resized):
		get_viewport().size_changed.connect(_on_viewport_resized)
	_apply_fullscreen_layout()

## Ensure this window renders above global UI bars.
func _ensure_window_overlay_order() -> void:
	z_as_relative = false
	z_index = 200

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
	if _agent_dropdown != null:
		return
	_agent_dropdown = $WindowPanel/WindowMargin/WindowInternals/HeaderPanel/HeaderMargin/HeaderRow/AgentPanel/AgentDropdown
	_inputs_grid = $WindowPanel/WindowMargin/WindowInternals/HeaderPanel/HeaderMargin/HeaderRow/InputsPanel/InputsMargin/InputsRow/InputsGrid
	_outputs_grid = $WindowPanel/WindowMargin/WindowInternals/HeaderPanel/HeaderMargin/HeaderRow/OutputsPanel/OutputsMargin/OutputsRow/OutputsGrid
	_status_label = $WindowPanel/WindowMargin/WindowInternals/BodyPanel/BodyMargin/BodyContent/StatusLabel
	_config_content = $WindowPanel/WindowMargin/WindowInternals/BodyPanel/BodyMargin/BodyContent/ConfigScroll/ConfigContent
	_ignore_button = $WindowPanel/WindowMargin/WindowInternals/BodyPanel/BodyMargin/BodyContent/ButtonRow/IgnoreChangesButton
	_save_button = $WindowPanel/WindowMargin/WindowInternals/BodyPanel/BodyMargin/BodyContent/ButtonRow/SaveButton
	_agent_dropdown.item_selected.connect(_on_agent_selected)
	_ignore_button.pressed.connect(_on_ignore_pressed)
	_save_button.pressed.connect(_on_save_pressed)

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
	_load_schema()
	_build_agent_dropdown()
	_rebuild_device_tabs()
	_focus_device_if_available()

## Load sensorimotor schema from Rust extension.
func _load_schema() -> void:
	_schema_map = {}
	_schema_errors = {}
	if not ClassDB.class_exists("FeagiSensorimotorSchema"):
		_set_status("Sensorimotor schema unavailable. Rebuild rust extension.")
		return
	var schema_provider := FeagiSensorimotorSchema.new()
	var schema = schema_provider.get_schema()
	if schema is Dictionary:
		_schema_map = schema
	_schema_errors = FeagiCore.feagi_local_cache.agent_capabilities_schema_errors

## Build agent dropdown from cached capabilities.
func _build_agent_dropdown() -> void:
	if _agent_dropdown == null:
		return
	var items: Array[StringName] = []
	for agent_id in _agent_capabilities_map.keys():
		items.append(agent_id)
	items.sort()
	_agent_dropdown.clear()
	_agent_dropdown.add_item("All agents")
	_agent_dropdown.set_item_metadata(0, ALL_AGENTS_OPTION)
	for agent_id in items:
		var display_name := _get_agent_display_name(agent_id)
		var index := _agent_dropdown.get_item_count()
		_agent_dropdown.add_item(String(display_name))
		_agent_dropdown.set_item_metadata(index, agent_id)
	_agent_dropdown.select(0)
	_selected_agent_id = ALL_AGENTS_OPTION

## Handle agent selection from dropdown.
func _on_agent_selected(index: int) -> void:
	var metadata = _agent_dropdown.get_item_metadata(index)
	if metadata is StringName:
		_selected_agent_id = metadata
	elif metadata is String:
		_selected_agent_id = StringName(metadata)
	elif index <= 0:
		_selected_agent_id = ALL_AGENTS_OPTION
	else:
		_selected_agent_id = StringName(_agent_dropdown.get_item_text(index))
	_rebuild_device_tabs()
	_focus_device_if_available()

## Updates the device grid buttons for inputs and outputs.
func _rebuild_device_tabs() -> void:
	_clear_grid(_inputs_grid)
	_clear_grid(_outputs_grid)
	_device_buttons[SECTION_INPUT] = {}
	_device_buttons[SECTION_OUTPUT] = {}
	_input_button_group = ButtonGroup.new()
	_output_button_group = ButtonGroup.new()
	var input_devices := _collect_device_keys(false)
	var output_devices := _collect_device_keys(true)
	for device_key in input_devices:
		var bundle := _create_device_button_bundle(device_key, false)
		_inputs_grid.add_child(bundle.container)
		_device_buttons[SECTION_INPUT][device_key] = bundle.button
	for device_key in output_devices:
		var bundle := _create_device_button_bundle(device_key, true)
		_outputs_grid.add_child(bundle.container)
		_device_buttons[SECTION_OUTPUT][device_key] = bundle.button

## Collect device keys for a given IO direction from selected agents.
func _collect_device_keys(is_output: bool) -> Array[StringName]:
	var keys: Array[StringName] = []
	var section_key := "output_units_and_decoder_properties" if is_output else "input_units_and_encoder_properties"
	for agent_id in _get_active_agent_ids():
		if not _agent_capabilities_map.has(agent_id):
			continue
		var agent_entry = _agent_capabilities_map[agent_id]
		if agent_entry is Dictionary and agent_entry.has("device_registrations"):
			var registrations = agent_entry["device_registrations"]
			if registrations is Dictionary and registrations.has(section_key):
				var unit_dict = registrations[section_key]
				if unit_dict is Dictionary:
					for device_key in unit_dict.keys():
						var key_name := StringName(String(device_key))
						if key_name not in keys:
							keys.append(key_name)
		_collect_device_keys_from_capabilities(agent_entry, is_output, keys)
	keys.sort()
	return keys

## Append device keys inferred from capability metadata (unit/source_units).
func _collect_device_keys_from_capabilities(agent_entry: Dictionary, is_output: bool, keys: Array[StringName]) -> void:
	if not agent_entry.has("capabilities"):
		return
	var caps = agent_entry["capabilities"]
	if caps is not Dictionary:
		return
	if is_output:
		if not caps.has("motor"):
			return
		var motor = caps["motor"]
		if motor is Dictionary:
			_append_capability_unit_key(motor, keys)
			if motor.has("source_units") and motor["source_units"] is Array:
				for spec in motor["source_units"]:
					if spec is Dictionary:
						_append_capability_unit_key(spec, keys)
	else:
		if not caps.has("vision"):
			return
		var vision = caps["vision"]
		if vision is Dictionary:
			_append_capability_unit_key(vision, keys)

## Extract unit name from a capability dictionary and append.
func _append_capability_unit_key(source: Dictionary, keys: Array[StringName]) -> void:
	if not source.has("unit"):
		return
	var unit_value = source["unit"]
	if unit_value is String or unit_value is StringName:
		var unit_key := _to_pascal_case(String(unit_value))
		if unit_key != "" and StringName(unit_key) not in keys:
			keys.append(StringName(unit_key))

## Creates a device button with a default icon and selection handler.
func _create_device_button_bundle(device_key: StringName, is_output: bool) -> Dictionary:
	var container := VBoxContainer.new()
	container.custom_minimum_size = Vector2(256, 256)
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	var button: TextureButton = TextureButton.new()
	button.custom_minimum_size = Vector2(128, 128)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.texture_normal = _get_device_icon(device_key, is_output)
	button.texture_hover = button.texture_normal
	button.texture_pressed = button.texture_normal
	button.toggle_mode = true
	button.button_group = _output_button_group if is_output else _input_button_group
	button.pressed.connect(_on_device_selected.bind(device_key, is_output))
	var label := Label.new()
	label.text = String(device_key)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.custom_minimum_size = Vector2(128, 0)
	label.max_lines_visible = 1
	container.add_child(button)
	container.add_child(label)
	return { "container": container, "button": button }

## Resolve a default icon for device buttons.
func _get_device_icon(device_key: StringName, is_output: bool) -> Texture2D:
	var icon_id := _get_device_icon_id_from_enum(device_key, is_output)
	if icon_id != "":
		var knowns_path := "res://BrainVisualizer/UI/GenericResources/CorticalAreaIcons/knowns/%s.png" % String(icon_id)
		print("Sensorimotor icon resolve: device=%s output=%s icon_id=%s path=%s exists=%s" % [
			String(device_key),
			str(is_output),
			String(icon_id),
			knowns_path,
			str(ResourceLoader.exists(knowns_path))
		])
		return UIManager.get_icon_texture_by_ID(icon_id, not is_output)
	var icon_path := _DEFAULT_OUTPUT_ICON if is_output else _DEFAULT_INPUT_ICON
	print("Sensorimotor icon fallback: device=%s output=%s icon_id=NONE path=%s exists=%s" % [
		String(device_key),
		str(is_output),
		icon_path,
		str(ResourceLoader.exists(icon_path))
	])
	if ResourceLoader.exists(icon_path):
		return load(icon_path)
	if ResourceLoader.exists(_DEFAULT_GENERIC_ICON):
		print("Sensorimotor icon fallback: device=%s output=%s using_generic=%s" % [
			String(device_key),
			str(is_output),
			_DEFAULT_GENERIC_ICON
		])
		return load(_DEFAULT_GENERIC_ICON)
	return null

## Resolve icon IDs from FEAGI enum strings.
func _get_device_icon_id_from_enum(device_key: StringName, is_output: bool) -> StringName:
	var icon_map := OUTPUT_DEVICE_ICON_IDS if is_output else INPUT_DEVICE_ICON_IDS
	var key_text := String(device_key)
	if icon_map.has(key_text):
		var icon_id = icon_map[key_text]
		if icon_id is StringName:
			return icon_id
		if icon_id is String:
			return StringName(icon_id)
	var normalized := _to_pascal_case(key_text)
	if normalized != "" and icon_map.has(normalized):
		var normalized_id = icon_map[normalized]
		if normalized_id is StringName:
			return normalized_id
		if normalized_id is String:
			return StringName(normalized_id)
	return ""

## Convert snake_case strings to PascalCase for enum matching.
func _to_pascal_case(text: String) -> String:
	if text.find("_") == -1:
		return text
	var parts := text.split("_", false)
	var result := ""
	for part in parts:
		if part.is_empty():
			continue
		result += part.substr(0, 1).to_upper() + part.substr(1)
	return result

## Handle device selection from the grid.
func _on_device_selected(device_key: StringName, is_output: bool) -> void:
	_selected_device_key = device_key
	_selected_section = SECTION_OUTPUT if is_output else SECTION_INPUT
	_render_device_config()

## Focus the device and section if available, otherwise pick the first available.
func _focus_device_if_available() -> void:
	if _selected_device_key != "":
		var section_buttons: Dictionary = _device_buttons.get(_selected_section, {})
		if section_buttons.has(_selected_device_key):
			var button: BaseButton = section_buttons[_selected_device_key]
			if button != null:
				button.button_pressed = true
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
	var section_buttons: Dictionary = _device_buttons.get(_selected_section, {})
	if section_buttons.has(_selected_device_key):
		var button: BaseButton = section_buttons[_selected_device_key]
		if button != null:
			button.button_pressed = true
	_render_device_config()

## Render configuration editors for the selected device across agents.
func _render_device_config() -> void:
	_clear_config_content()
	_editor_by_agent.clear()
	_field_editors_by_agent.clear()
	if _selected_device_key == "":
		_set_status("Select a device to configure.")
		return
	if _schema_map.is_empty():
		_set_status("Sensorimotor schema unavailable.")
		_add_info_label("Sensorimotor schema is required for typed editing.")
		return
	_set_status("Editing %s (%s)" % [_selected_device_key, _selected_section])
	var section_key := "output_units_and_decoder_properties" if _selected_section == SECTION_OUTPUT else "input_units_and_encoder_properties"
	var unit_schema := _get_schema_node(&"json_unit_definition")
	var props_schema := _get_schema_node(&"json_decoder_properties") if _selected_section == SECTION_OUTPUT else _get_schema_node(&"json_encoder_properties")
	for agent_id in _get_active_agent_ids():
		var header := Label.new()
		header.text = "Agent: %s" % _get_agent_display_name(agent_id)
		_config_content.add_child(header)
		var error_key: Variant = agent_id
		if not _schema_errors.has(error_key):
			error_key = String(agent_id)
		if _schema_errors.has(error_key):
			var errors = _schema_errors[error_key]
			if errors is Array:
				for error_message in errors:
					_add_info_label("Schema error: %s" % String(error_message))
		_editor_by_agent[agent_id] = []
		_field_editors_by_agent[agent_id] = {}
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
		var device_entries = device_dict[_selected_device_key]
		var entries: Array = []
		if device_entries is Array:
			for entry_index in range(device_entries.size()):
				entries.append({
					"entry_index": entry_index,
					"entry_key": entry_index,
					"value": device_entries[entry_index],
					"container_kind": "array"
				})
		elif device_entries is Dictionary:
			var entry_keys: Array = device_entries.keys()
			entry_keys.sort()
			for entry_key in entry_keys:
				entries.append({
					"entry_index": entries.size(),
					"entry_key": entry_key,
					"value": device_entries[entry_key],
					"container_kind": "dict"
				})
		else:
			_add_info_label("Unsupported registration format for %s." % _selected_device_key)
			continue
		for entry_data in entries:
			var entry = entry_data["value"]
			var entry_holder := _create_collapsible_section("Device %d" % int(entry_data["entry_index"]), false)
			if entry is Dictionary:
				_add_info_label("Unsupported registration format (missing schema).")
				_editor_by_agent[agent_id].append({
					"device_key": entry_data["entry_key"],
					"container_kind": entry_data["container_kind"],
					"entry_kind": "dict",
					"holder": entry_holder
				})
				continue
			if entry is Array and entry.size() == 2 and entry[0] is Dictionary and entry[1] is Dictionary:
				var unit_holder := _create_collapsible_section("Unit Definition", false, entry_holder)
				if unit_schema.is_empty():
					_add_info_label("Unit definition schema unavailable.")
				else:
					_build_parameter_editors_from_entry(
						entry[0],
						unit_holder,
						unit_schema,
						agent_id,
						[section_key, _selected_device_key, entry_data["entry_key"], 0]
					)
				var props_holder := _create_collapsible_section("Properties", false, entry_holder)
				if props_schema.is_empty():
					_add_info_label("Properties schema unavailable.")
				else:
					_build_parameter_editors_from_entry(
						entry[1],
						props_holder,
						props_schema,
						agent_id,
						[section_key, _selected_device_key, entry_data["entry_key"], 1]
					)
				_editor_by_agent[agent_id].append({
					"device_key": entry_data["entry_key"],
					"container_kind": entry_data["container_kind"],
					"entry_kind": "pair",
					"holder_unit": unit_holder,
					"holder_props": props_holder
				})
				continue
			_add_info_label("Unsupported device entry format for %s." % _selected_device_key)
		_apply_schema_error_highlights(agent_id)

## Ignore edits and close the window.
func _on_ignore_pressed() -> void:
	close_window()

## Save edits to FEAGI backend.
func _on_save_pressed() -> void:
	var updated_map := _apply_edits_to_cache()
	if updated_map.is_empty():
		return
	if FeagiCore == null or FeagiCore.requests == null:
		_show_error_popup("Save Failed", "FEAGI is not available.")
		return
	for agent_id in updated_map.keys():
		var agent_entry = updated_map[agent_id]
		if agent_entry is not Dictionary:
			continue
		if not agent_entry.has("device_registrations"):
			continue
		var registrations = agent_entry["device_registrations"]
		if registrations is not Dictionary:
			continue
		var response: FeagiRequestOutput = await FeagiCore.requests.import_device_registrations(
			agent_id,
			registrations
		)
		if response.has_errored or not response.success:
			_show_error_popup("Save Failed", "Failed to save device registrations for agent %s." % agent_id)
			return
	BV.NOTIF.add_notification("Device registrations saved to FEAGI.")

## Apply edits to the local cache and return updated map.
func _apply_edits_to_cache() -> Dictionary:
	if _selected_device_key == "":
		return {}
	var updated_map: Dictionary = _agent_capabilities_map.duplicate(true)
	var section_key := "output_units_and_decoder_properties" if _selected_section == SECTION_OUTPUT else "input_units_and_encoder_properties"
	for agent_id in _editor_by_agent.keys():
		if not updated_map.has(agent_id):
			continue
		var agent_entry = updated_map[agent_id]
		if not (agent_entry is Dictionary) or not agent_entry.has("device_registrations"):
			continue
		var registrations = agent_entry["device_registrations"]
		if not (registrations is Dictionary) or not registrations.has(section_key):
			continue
		var device_dict = registrations[section_key]
		if device_dict is Dictionary and device_dict.has(_selected_device_key):
			var device_entries = device_dict[_selected_device_key]
			for entry_data in _editor_by_agent[agent_id]:
				var entry_kind = entry_data.get("entry_kind", "")
				var container_kind = entry_data.get("container_kind", "")
				var device_key = entry_data.get("device_key", null)
				if entry_kind == "":
					continue
				if container_kind == "array" and device_entries is Array:
					var entry_index = int(device_key)
					if entry_index < 0 or entry_index >= device_entries.size():
						continue
					device_entries[entry_index] = _export_entry_for_kind(entry_kind, entry_data)
				elif container_kind == "dict" and device_entries is Dictionary:
					if device_key == null:
						continue
					device_entries[device_key] = _export_entry_for_kind(entry_kind, entry_data)
	FeagiCore.feagi_local_cache.set_agent_capabilities_map(updated_map)
	_agent_capabilities_map = updated_map
	return updated_map

## Build parameter editors for a device entry dictionary using schema.
func _build_parameter_editors_from_entry(
	entry: Dictionary,
	holder: VBoxContainer,
	schema: Dictionary,
	agent_id: StringName,
	path_prefix: Array
) -> void:
	if schema.is_empty():
		_add_info_label("Schema missing for entry.")
		return
	var kind := _get_schema_kind(schema)
	if kind != "object":
		_add_info_label("Unsupported schema kind for entry: %s" % kind)
		return
	var fields: Dictionary = schema.get("fields", {})
	var keys: Array = entry.keys()
	keys.sort()
	for key in keys:
		var field_schema: Dictionary = fields.get(key, {})
		_append_editors_for_value(
			StringName(String(key)),
			entry[key],
			holder,
			field_schema,
			agent_id,
			_build_path_parts(path_prefix, String(key))
		)

## Append parameter editors for a value using schema.
func _append_editors_for_value(
	label: StringName,
	value: Variant,
	holder: VBoxContainer,
	schema: Dictionary,
	agent_id: StringName,
	path_parts: Array[String],
	append_label: bool = true
) -> void:
	if schema.is_empty():
		_add_info_label("Unsupported field: %s" % label)
		return
	var current_path := path_parts.duplicate()
	if append_label:
		current_path.append(String(label))
	var kind := _get_schema_kind(schema)
	if kind == "object":
		if value is not Dictionary:
			_add_info_label("Expected object for %s." % label)
			return
		var section_holder := _create_collapsible_section(String(label), false, holder)
		var fields: Dictionary = schema.get("fields", {})
		var keys: Array = value.keys()
		keys.sort()
		for key in keys:
			var field_schema: Dictionary = fields.get(key, {})
			_append_editors_for_value(
				StringName(String(key)),
				value[key],
				section_holder,
				field_schema,
				agent_id,
				current_path.duplicate()
			)
		return
	if kind == "array":
		if value is not Array:
			_add_info_label("Expected array for %s." % label)
			return
		var section_holder := _create_collapsible_section(String(label), false, holder)
		var item_schema: Dictionary = schema.get("items", {})
		for index in range(value.size()):
			_append_editors_for_value(
				StringName(str(index)),
				value[index],
				section_holder,
				item_schema,
				agent_id,
				current_path.duplicate()
			)
		return
	if kind == "map":
		if value is not Dictionary:
			_add_info_label("Expected map for %s." % label)
			return
		var section_holder := _create_collapsible_section(String(label), false, holder)
		var value_schema: Dictionary = schema.get("value", {})
		var keys: Array = value.keys()
		keys.sort()
		for key in keys:
			_append_editors_for_value(
				StringName(String(key)),
				value[key],
				section_holder,
				value_schema,
				agent_id,
				current_path.duplicate()
			)
		return
	if kind == "tuple":
		if value is not Array:
			_add_info_label("Expected tuple for %s." % label)
			return
		var section_holder := _create_collapsible_section(String(label), false, holder)
		var items: Array = schema.get("items", []) as Array
		for index in range(min(value.size(), items.size())):
			var item_schema: Dictionary = items[index] as Dictionary
			_append_editors_for_value(
				StringName(str(index)),
				value[index],
				section_holder,
				item_schema,
				agent_id,
				current_path.duplicate()
			)
		return
	if kind == "externally_tagged_enum":
		var variants: Dictionary = schema.get("variants", {})
		var variant_key = ""
		var variant_value: Variant = null
		if value is Dictionary and value.size() == 1:
			variant_key = String(value.keys()[0])
			variant_value = value[variant_key]
		elif value is StringName or value is String:
			variant_key = String(value)
			variant_value = null
		else:
			_add_info_label("Expected enum object for %s." % label)
			return
		var variant_schema: Dictionary = variants.get(variant_key, {})
		var section_holder := _create_collapsible_section("%s: %s" % [label, variant_key], false, holder)
		if variant_schema.is_empty():
			_add_info_label("Unsupported enum variant: %s" % variant_key)
			return
		if variant_value == null:
			if _get_schema_kind(variant_schema) == "unit":
				_add_info_label("No configurable properties for %s." % variant_key)
			else:
				_add_info_label("Missing enum payload for %s." % variant_key)
			return
		var variant_path := current_path.duplicate()
		variant_path.append(String(variant_key))
		_append_editors_for_value(
			StringName("value"),
			variant_value,
			section_holder,
			variant_schema,
			agent_id,
			variant_path,
			false
		)
		return
	if kind == "unit":
		_add_info_label("No configurable properties for %s." % label)
		return
	if kind == "tagged_union":
		if value is not Dictionary:
			_add_info_label("Expected tagged union for %s." % label)
			return
		var tag_key: String = String(schema.get("tag", "type"))
		var value_key: String = String(schema.get("value", "value"))
		if not value.has(tag_key):
			_add_info_label("Missing tag for %s." % label)
			return
		var tag_value: String = String(value[tag_key])
		var variants: Dictionary = schema.get("variants", {})
		var variant_schema: Dictionary = variants.get(tag_value, {})
		var section_holder := _create_collapsible_section(String(label), false, holder)
		var tag_param := EnumParameter.new()
		tag_param.label = StringName(tag_key)
		tag_param.description = _schema_tag_description(schema)
		tag_param.options = _keys_to_stringname_array(variants.keys())
		tag_param.value = StringName(tag_value)
		var tag_editor := EditAbstractParameter.spawn_and_add_parameter_editor(tag_param, section_holder)
		if tag_editor != null:
			_register_field_editor(agent_id, _build_path_parts(current_path, tag_key), tag_editor)
		if variant_schema.is_empty():
			_add_info_label("Unsupported tagged value: %s" % tag_value)
			return
		if value.has(value_key):
			_append_editors_for_value(
				StringName(value_key),
				value[value_key],
				section_holder,
				variant_schema,
				agent_id,
				current_path.duplicate()
			)
		return
	var parameter := _build_parameter_from_schema(label, value, schema)
	if parameter == null:
		return
	var editor := EditAbstractParameter.spawn_and_add_parameter_editor(parameter, holder)
	if editor != null:
		_register_field_editor(agent_id, current_path, editor)

## Build a parameter object from schema and value.
func _build_parameter_from_schema(label: StringName, value: Variant, schema: Dictionary) -> AbstractParameter:
	var kind := _get_schema_kind(schema)
	var description := _schema_description(schema)
	if kind == "bool":
		var param := BooleanParameter.new()
		param.label = label
		param.description = description
		param.value = bool(value)
		return param
	if kind == "int":
		var param := IntegerParameter.new()
		param.label = label
		param.description = description
		param.value = int(value)
		param.minimum = int(schema.get("min", param.minimum))
		param.maximum = int(schema.get("max", param.maximum))
		return param
	if kind == "float":
		var param := FloatParameter.new()
		param.label = label
		param.description = description
		param.value = float(value)
		param.minimum = float(schema.get("min", param.minimum))
		param.maximum = float(schema.get("max", param.maximum))
		return param
	if kind == "string":
		var param := StringParameter.new()
		param.label = label
		param.description = description
		param.value = StringName(String(value))
		return param
	if kind == "enum":
		var param := EnumParameter.new()
		param.label = label
		param.description = description
		param.options = _to_stringname_array(schema.get("options", []))
		param.value = StringName(String(value))
		return param
	if kind == "optional":
		var param := OptionalParameter.new()
		param.label = label
		param.description = description
		param.enabled = value != null
		var item_schema: Dictionary = schema.get("item", {})
		var inner_value: Variant = value
		if inner_value == null:
			inner_value = _default_value_for_schema(item_schema)
		param.inner = _build_parameter_tree_from_schema(label, inner_value, item_schema)
		return param
	if kind == "json_value":
		return _build_parameter_from_value(label, value)
	return _build_parameter_from_value(label, value)

## Build a parameter tree for complex schema types.
func _build_parameter_tree_from_schema(label: StringName, value: Variant, schema: Dictionary) -> AbstractParameter:
	var kind := _get_schema_kind(schema)
	var description := _schema_description(schema)
	if kind in ["bool", "int", "float", "string", "enum", "optional", "json_value"]:
		return _build_parameter_from_schema(label, value, schema)
	if kind == "object":
		var param := ObjectParameter.new()
		param.label = label
		param.description = description
		var subparams: Array[AbstractParameter] = []
		var fields: Dictionary = schema.get("fields", {})
		for field_key in fields.keys():
			var field_schema: Dictionary = fields[field_key]
			var field_value: Variant = value[field_key] if value is Dictionary and value.has(field_key) else _default_value_for_schema(field_schema)
			var subparam := _build_parameter_tree_from_schema(StringName(String(field_key)), field_value, field_schema)
			if subparam != null:
				subparams.append(subparam)
		param.value = subparams
		return param
	if kind == "array":
		var param := ObjectParameter.new()
		param.label = label
		param.description = description
		var subparams: Array[AbstractParameter] = []
		var item_schema: Dictionary = schema.get("items", {})
		if value is Array:
			for index in range(value.size()):
				var subparam := _build_parameter_tree_from_schema(StringName(str(index)), value[index], item_schema)
				if subparam != null:
					subparams.append(subparam)
		param.value = subparams
		return param
	if kind == "map":
		var param := ObjectParameter.new()
		param.label = label
		param.description = description
		var subparams: Array[AbstractParameter] = []
		var value_schema: Dictionary = schema.get("value", {})
		if value is Dictionary:
			for map_key in value.keys():
				var subparam := _build_parameter_tree_from_schema(StringName(String(map_key)), value[map_key], value_schema)
				if subparam != null:
					subparams.append(subparam)
		param.value = subparams
		return param
	if kind == "tuple":
		var param := ObjectParameter.new()
		param.label = label
		param.description = description
		var subparams: Array[AbstractParameter] = []
		var items: Array = schema.get("items", []) as Array
		if value is Array:
			for index in range(min(value.size(), items.size())):
				var item_schema: Dictionary = items[index] as Dictionary
				var subparam := _build_parameter_tree_from_schema(StringName(str(index)), value[index], item_schema)
				if subparam != null:
					subparams.append(subparam)
		param.value = subparams
		return param
	if kind == "externally_tagged_enum":
		var param := ObjectParameter.new()
		param.label = label
		param.description = description
		var subparams: Array[AbstractParameter] = []
		var variants: Dictionary = schema.get("variants", {})
		var variant_key = ""
		var variant_value: Variant = null
		if value is Dictionary and value.size() == 1:
			variant_key = String(value.keys()[0])
			variant_value = value[variant_key]
		elif value is StringName or value is String:
			variant_key = String(value)
			variant_value = null
		if variant_key != "":
			var variant_schema: Dictionary = variants.get(variant_key, {})
			if variant_schema.is_empty():
				return param
			if _get_schema_kind(variant_schema) == "unit":
				param.value = []
				return param
			var subparam := _build_parameter_tree_from_schema(StringName(String(variant_key)), variant_value, variant_schema)
			if subparam != null:
				subparams.append(subparam)
		param.value = subparams
		return param
	if kind == "tagged_union":
		var param := ObjectParameter.new()
		param.label = label
		param.description = description
		var subparams: Array[AbstractParameter] = []
		var tag_key: String = String(schema.get("tag", "type"))
		var value_key: String = String(schema.get("value", "value"))
		var variants: Dictionary = schema.get("variants", {})
		var tag_value: String = String(value[tag_key]) if value is Dictionary and value.has(tag_key) else ""
		var tag_param := EnumParameter.new()
		tag_param.label = StringName(String(tag_key))
		tag_param.description = _schema_tag_description(schema)
		tag_param.options = _keys_to_stringname_array(variants.keys())
		tag_param.value = StringName(tag_value)
		subparams.append(tag_param)
		var variant_schema: Dictionary = variants.get(tag_value, {})
		if value is Dictionary and value.has(value_key):
			var value_param := _build_parameter_tree_from_schema(StringName(String(value_key)), value[value_key], variant_schema)
			if value_param != null:
				subparams.append(value_param)
		param.value = subparams
		return param
	return _build_parameter_from_value(label, value)

## Build a parameter object from a JSON value (schema-free JSONValue).
func _build_parameter_from_value(label: StringName, value: Variant) -> AbstractParameter:
	if value is bool:
		var param := BooleanParameter.new()
		param.label = label
		param.description = ""
		param.value = value
		return param
	if value is int:
		var param := IntegerParameter.new()
		param.label = label
		param.description = ""
		param.value = value
		if _requires_positive_int(label):
			param.minimum = 0
		return param
	if value is float:
		if _is_int_like_float(value):
			var int_param := IntegerParameter.new()
			int_param.label = label
			int_param.description = ""
			int_param.value = int(value)
			int_param.maximum = max(int_param.maximum, int_param.value)
			if _requires_positive_int(label):
				int_param.minimum = 0
			return int_param
		var float_param := FloatParameter.new()
		float_param.label = label
		float_param.description = ""
		float_param.value = value
		return float_param
	if value is StringName or value is String:
		var param := StringParameter.new()
		param.label = label
		param.description = ""
		param.value = StringName(String(value))
		return param
	if value is Array and _array_is_vector3(value):
		var param := Vector3Parameter.new()
		param.label = label
		param.description = ""
		param.value = Vector3(float(value[0]), float(value[1]), float(value[2]))
		return param
	return null

func _schema_description(schema: Dictionary) -> String:
	if schema.has("description"):
		return String(schema.get("description", ""))
	return ""

func _schema_tag_description(schema: Dictionary) -> String:
	if schema.has("tag_description"):
		return String(schema.get("tag_description", ""))
	return _schema_description(schema)

func _is_int_like_float(value: float) -> bool:
	return value == float(int(value))

func _requires_positive_int(label: StringName) -> bool:
	var text := String(label).to_lower()
	return text.find("index") != -1

## Export a device entry from parameter editor holder.
func _export_entry_from_holder(holder: VBoxContainer) -> Dictionary:
	var output: Dictionary = {}
	for child in holder.get_children():
		if child is not EditAbstractParameter:
			continue
		var parameter: AbstractParameter = (child as EditAbstractParameter).export()
		var param_dict = parameter.get_as_JSON_formatable_dict()
		for key in param_dict.keys():
			output[key] = _normalize_json_value(param_dict[key])
	return output

## Export device entry based on editor kind.
func _export_entry_for_kind(entry_kind: String, entry_data: Dictionary) -> Variant:
	if entry_kind == "dict":
		var holder: VBoxContainer = entry_data.get("holder", null)
		if holder == null:
			return {}
		return _export_entry_from_holder(holder)
	if entry_kind == "pair":
		var unit_holder: VBoxContainer = entry_data.get("holder_unit", null)
		var props_holder: VBoxContainer = entry_data.get("holder_props", null)
		if unit_holder == null or props_holder == null:
			return []
		var unit_dict = _export_entry_from_holder(unit_holder)
		var props_dict = _export_entry_from_holder(props_holder)
		return [unit_dict, props_dict]
	return {}

func _create_collapsible_section(title: String, start_open: bool, parent: Control = null) -> VBoxContainer:
	var collapsible: VerticalCollapsibleHiding = COLLAPSIBLE_SECTION.instantiate()
	collapsible.section_text = StringName(title)
	var title_label: Label = collapsible.get_node("VerticalCollapsible/HBoxContainer/Section_Title")
	title_label.text = title
	collapsible.start_open = start_open
	if parent == null:
		_config_content.add_child(collapsible)
	else:
		parent.add_child(collapsible)
	var content_root: Control = collapsible.get_control()
	var holder := VBoxContainer.new()
	holder.add_theme_constant_override("separation", 4)
	content_root.add_child(holder)
	return holder

## Build path parts by appending a string segment.
func _build_path_parts(prefix: Array, segment: String) -> Array[String]:
	var parts: Array[String] = []
	for item in prefix:
		parts.append(str(item))
	parts.append(segment)
	return parts

## Register field editor for schema error highlighting.
func _register_field_editor(agent_id: StringName, path_parts: Array[String], editor: EditAbstractParameter) -> void:
	if not _field_editors_by_agent.has(agent_id):
		_field_editors_by_agent[agent_id] = {}
	var registry: Dictionary = _field_editors_by_agent[agent_id]
	var full_path := "device_registrations." + ".".join(path_parts)
	registry[full_path] = editor

## Apply schema error highlights to editors for a specific agent.
func _apply_schema_error_highlights(agent_id: StringName) -> void:
	var error_key: Variant = agent_id
	if not _schema_errors.has(error_key):
		error_key = String(agent_id)
	if not _schema_errors.has(error_key):
		return
	var errors = _schema_errors[error_key]
	if errors is not Array:
		return
	var registry: Dictionary = _field_editors_by_agent.get(agent_id, {})
	for error_message in errors:
		var message_text := str(error_message)
		var path_end := message_text.find(":")
		var path_text := message_text if path_end == -1 else message_text.substr(0, path_end)
		if registry.has(path_text):
			var editor = registry[path_text]
			if editor is EditAbstractParameter:
				(editor as EditAbstractParameter).set_schema_error(message_text)

## Fetch a schema node by key from the schema map.
func _get_schema_node(key: StringName) -> Dictionary:
	if _schema_map.has(key):
		var node = _schema_map[key]
		if node is Dictionary:
			return node
	return {}

## Return the kind string for a schema node.
func _get_schema_kind(schema: Dictionary) -> String:
	if schema.has("kind"):
		return String(schema["kind"])
	return ""

## Convert an array of keys into sorted StringName options.
func _keys_to_stringname_array(keys: Array) -> Array[StringName]:
	var output: Array[StringName] = []
	for key in keys:
		output.append(StringName(String(key)))
	output.sort()
	return output

## Convert generic array to StringName array.
func _to_stringname_array(values: Array) -> Array[StringName]:
	var output: Array[StringName] = []
	for value in values:
		output.append(StringName(str(value)))
	return output

## Build a default value for a schema node.
func _default_value_for_schema(schema: Dictionary) -> Variant:
	if schema.is_empty():
		return null
	var kind := _get_schema_kind(schema)
	if kind == "bool":
		return false
	if kind == "int":
		return int(schema.get("min", 0))
	if kind == "float":
		return float(schema.get("min", 0.0))
	if kind == "string":
		return ""
	if kind == "enum":
		var options: Array = schema.get("options", [])
		return options[0] if options.size() > 0 else ""
	if kind == "unit":
		return null
	if kind == "optional":
		return null
	if kind == "object":
		var fields: Dictionary = schema.get("fields", {})
		var output: Dictionary = {}
		for field_key in fields.keys():
			output[field_key] = _default_value_for_schema(fields[field_key])
		return output
	if kind == "array":
		return []
	if kind == "tuple":
		var items: Array = schema.get("items", [])
		var output: Array = []
		for item_schema in items:
			output.append(_default_value_for_schema(item_schema))
		return output
	if kind == "map":
		return {}
	if kind == "externally_tagged_enum":
		var variants: Dictionary = schema.get("variants", {})
		var keys: Array = variants.keys()
		keys.sort()
		if keys.is_empty():
			return {}
		var variant_key = keys[0]
		var default_value = _default_value_for_schema(variants[variant_key])
		return { variant_key: default_value }
	if kind == "tagged_union":
		var variants: Dictionary = schema.get("variants", {})
		var keys: Array = variants.keys()
		keys.sort()
		if keys.is_empty():
			return {}
		var variant_key = keys[0]
		var tag_key: String = String(schema.get("tag", "type"))
		var value_key: String = String(schema.get("value", "value"))
		var default_value = _default_value_for_schema(variants[variant_key])
		return { tag_key: variant_key, value_key: default_value }
	return null

## Normalize exported JSON values (convert numeric-key dictionaries to arrays).
func _normalize_json_value(value: Variant) -> Variant:
	if value is Dictionary:
		var dict_value: Dictionary = value
		if _is_array_dictionary(dict_value):
			var array_out: Array = []
			array_out.resize(dict_value.size())
			for key in dict_value.keys():
				var idx = int(String(key))
				array_out[idx] = _normalize_json_value(dict_value[key])
			return array_out
		var normalized: Dictionary = {}
		for key in dict_value.keys():
			normalized[key] = _normalize_json_value(dict_value[key])
		return normalized
	if value is Array:
		var out_array: Array = []
		for item in value:
			out_array.append(_normalize_json_value(item))
		return out_array
	return value

func _is_array_dictionary(value: Dictionary) -> bool:
	if value.is_empty():
		return false
	var indices: Array[int] = []
	for key in value.keys():
		var key_text := String(key)
		if not key_text.is_valid_int():
			return false
		indices.append(int(key_text))
	indices.sort()
	for idx in range(indices.size()):
		if indices[idx] != idx:
			return false
	return true

func _array_is_vector3(value: Array) -> bool:
	if value.size() != 3:
		return false
	for item in value:
		if item is not int and item is not float:
			return false
	return true

## Determine which agent IDs are active based on selection.
func _get_active_agent_ids() -> Array[StringName]:
	var agent_ids: Array[StringName] = []
	if _selected_agent_id == ALL_AGENTS_OPTION:
		for agent_id in _agent_capabilities_map.keys():
			agent_ids.append(agent_id)
		agent_ids.sort()
	else:
		agent_ids = [_selected_agent_id]
	return agent_ids

## Resolve a human-friendly agent name for display.
func _get_agent_display_name(agent_id: StringName) -> StringName:
	var entry = _resolve_agent_entry(agent_id)
	if not (entry is Dictionary):
		return agent_id
	var name := _extract_agent_display_name(entry)
	if name != "" and not _is_unusable_agent_label(name, agent_id):
		return name
	var inferred_name := _infer_agent_display_name(entry)
	if inferred_name != "":
		return inferred_name
	return agent_id

## Resolve agent entry for StringName/String key variants.
func _resolve_agent_entry(agent_id: StringName) -> Variant:
	if _agent_capabilities_map.has(agent_id):
		return _agent_capabilities_map[agent_id]
	var agent_id_text := String(agent_id)
	if _agent_capabilities_map.has(agent_id_text):
		return _agent_capabilities_map[agent_id_text]
	return null

## Extract a human-readable name from known FEAGI payload variants.
func _extract_agent_display_name(entry: Dictionary) -> StringName:
	var direct_keys: Array[StringName] = [&"agent_name", &"friendly_name", &"display_name", &"name", &"agent_type"]
	for key in direct_keys:
		var direct_name := _read_string_field(entry, key)
		if direct_name != "":
			return direct_name

	var nested_sections: Array[StringName] = [&"capabilities", &"metadata", &"properties", &"agent"]
	for section in nested_sections:
		if not entry.has(section):
			continue
		var section_value = entry[section]
		if section_value is not Dictionary:
			continue
		var nested_dict: Dictionary = section_value
		for key in direct_keys:
			var nested_name := _read_string_field(nested_dict, key)
			if nested_name != "":
				return nested_name
	return ""

## Returns true when a label is effectively the opaque ID and unsuitable for UI display.
func _is_unusable_agent_label(label: StringName, agent_id: StringName) -> bool:
	var text := String(label).strip_edges()
	if text == "":
		return true
	if text == String(agent_id):
		return true
	return _looks_like_encoded_agent_id(text)

## Detect opaque base64-like IDs so UI can show inferred readable names instead.
func _looks_like_encoded_agent_id(value: String) -> bool:
	if value.length() < 24:
		return false
	for i in value.length():
		var ch := value.unicode_at(i)
		var is_upper := ch >= 65 and ch <= 90
		var is_lower := ch >= 97 and ch <= 122
		var is_digit := ch >= 48 and ch <= 57
		var is_base64_symbol := ch == 43 or ch == 47 or ch == 61
		if not (is_upper or is_lower or is_digit or is_base64_symbol):
			return false
	return true

## Infer human-friendly agent label from capability signature.
func _infer_agent_display_name(entry: Dictionary) -> StringName:
	if not entry.has("capabilities"):
		return ""
	var caps = entry["capabilities"]
	if caps is not Dictionary:
		return ""
	var has_visualization: bool = caps.has("visualization") or caps.has("receive_neuron_visualizations")
	var has_motor: bool = caps.has("motor") or caps.has("receive_motor_data")
	var has_vision: bool = caps.has("vision") or caps.has("input")
	if has_visualization and not has_motor and not has_vision:
		return "Brain Visualizer"
	if has_motor and not has_vision:
		return "Motor Agent"
	if has_vision and not has_motor:
		return "Vision Agent"
	if has_vision and has_motor:
		return "Sensorimotor Agent"
	return ""

## Read a string field from a dictionary.
func _read_string_field(source: Dictionary, key: StringName) -> StringName:
	if not source.has(key):
		return ""
	var value = source[key]
	if value is StringName:
		return value
	if value is String:
		return StringName(value)
	return ""

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

## Helper to clear all children from a grid container.
func _clear_grid(grid: GridContainer) -> void:
	for child in grid.get_children():
		child.queue_free()

## Display a modal error popup for invalid edits.
func _show_error_popup(title: String, message: String) -> void:
	BV.WM.spawn_popup(ConfigurablePopupDefinition.create_single_button_close_popup(title, message))
