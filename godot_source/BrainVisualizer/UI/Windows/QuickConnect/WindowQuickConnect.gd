extends BaseDraggableWindow
class_name WindowQuickConnect

const WINDOW_NAME: StringName = "quick_connect"

enum POSSIBLE_STATES {
	SOURCE,
	DESTINATION,
	MORPHOLOGY,
	EDIT_MORPHOLOGY,
	IDLE
}


#@export var style_incomplete: StyleBoxFlat
#@export var style_waiting: StyleBoxFlat
#@export var style_complete: StyleBoxFlat

var current_state: POSSIBLE_STATES:
	get: return _current_state
	set(v):
		_update_current_state(v)

var _step1_panel: PanelContainer
var _step2_panel: PanelContainer
var _step3_panel: PanelContainer
var _step1_button: TextureButton
var _step2_button: TextureButton
var _step3_button: TextureButton
var _step1_label: Label
var _step2_label: Label
var _step3_label: Label
var _step3_scroll: MorphologyScroll
var _step3_morphology_container: PanelContainer
var _step3_morphology_view: UIMorphologyDefinition
var _step3_morphology_details: MorphologyGenericDetails
var _step4_button: Button

# Horizontal icon shortcut bar for Core (system) morphologies
var _core_bar_label: Label
var _core_bar: ScrollContainer
var _core_icons: HBoxContainer
var _core_icon_buttons: Array[TextureButton] = []
var _selected_core_icon_button: TextureButton = null

var _current_state: POSSIBLE_STATES = POSSIBLE_STATES.IDLE
var _finished_selecting: bool = false

var _source: AbstractCorticalArea = null
var _destination: AbstractCorticalArea = null
var _destinations: Array[AbstractCorticalArea] = []
var _selected_morphology: BaseMorphology = null

func _ready() -> void:
	super()
	_step1_panel = _window_internals.get_node("step1")
	_step2_panel = _window_internals.get_node("step2")
	_step3_panel = _window_internals.get_node("step3")
	_step1_button = _window_internals.get_node("step1/step1/TextureButton")
	_step2_button = _window_internals.get_node("step2/step2/TextureButton")
	_step3_button = _window_internals.get_node("step3/step3/TextureButton")
	_step1_label = _window_internals.get_node("step1/step1/Label")
	_step2_label = _window_internals.get_node("step2/step2/Label")
	_step3_label = _window_internals.get_node("step3/step3/Label")
	_step3_morphology_container = _window_internals.get_node("MorphologyInfoContainer")
	_step3_scroll = _window_internals.get_node("MorphologyInfoContainer/MorphologyInfo/MorphologyScroll")
	_step3_morphology_view = _window_internals.get_node("MorphologyInfoContainer/MorphologyInfo/SmartMorphologyView")
	_step3_morphology_details = _window_internals.get_node("MorphologyInfoContainer/MorphologyInfo/MorphologyGenericDetails")
	_step4_button = _window_internals.get_node("Establish")
	_core_bar_label = _window_internals.get_node_or_null("CoreConnectivityRulesLabel")
	_core_bar = _window_internals.get_node("CoreMorphologiesBar")
	_core_icons = _window_internals.get_node("CoreMorphologiesBar/Icons")
	
	# Guard against duplicate connections if this window is re-instantiated or _ready runs more than once.
	if not _step3_scroll.morphology_selected.is_connected(_set_morphology):
		_step3_scroll.morphology_selected.connect(_set_morphology)
	# Update icon bar reactively when morphologies change (e.g., when 'class' becomes 'core')
	if not FeagiCore.feagi_local_cache.morphologies.morphology_updated.is_connected(_on_morphology_cache_changed):
		FeagiCore.feagi_local_cache.morphologies.morphology_updated.connect(_on_morphology_cache_changed)
	if not FeagiCore.feagi_local_cache.morphologies.morphology_added.is_connected(_on_morphology_cache_changed):
		FeagiCore.feagi_local_cache.morphologies.morphology_added.connect(_on_morphology_cache_changed)
	if not FeagiCore.feagi_local_cache.morphologies.morphology_renamed.is_connected(_on_morphology_renamed_for_cache):
		FeagiCore.feagi_local_cache.morphologies.morphology_renamed.connect(_on_morphology_renamed_for_cache)
	
	BV.UI.selection_system.add_override_usecase(SelectionSystem.OVERRIDE_USECASE.QUICK_CONNECT)
	if not BV.UI.selection_system.objects_selection_event_called.is_connected(_on_user_selection):
		BV.UI.selection_system.objects_selection_event_called.connect(_on_user_selection)
	
	
	_step1_panel.theme_type_variation = "PanelContainer_QC_incomplete"
	_step2_panel.theme_type_variation = "PanelContainer_QC_incomplete"
	_step3_panel.theme_type_variation = "PanelContainer_QC_incomplete"
	current_state = POSSIBLE_STATES.SOURCE
	# Handle ESC to cancel
	set_process_unhandled_key_input(true)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.echo:
			return
		if key.pressed:
			if key.keycode == KEY_ESCAPE:
				close_window()
			elif (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER):
				# Enter acts as clicking Establish when enabled
				if _step4_button != null and !_step4_button.disabled:
					establish_connection_button()
			return
		# On Ctrl release, finalize multi-destination picking and move to rule selection.
		if _is_ctrl_key(key.keycode) and _current_state == POSSIBLE_STATES.DESTINATION and not _destinations.is_empty():
			_step3_panel.visible = true
			_setting_morphology()

func setup(cortical_source_if_picked: AbstractCorticalArea) -> void:
	_setup_base_window(WINDOW_NAME)
	if cortical_source_if_picked != null:
		_set_source(cortical_source_if_picked)

func _on_user_selection(objects: Array[GenomeObject], context: SelectionSystem.SOURCE_CONTEXT, _override_usecases: Array[SelectionSystem.OVERRIDE_USECASE]) -> void:
	match _current_state:
		POSSIBLE_STATES.SOURCE:
			if len(objects) != 1:
				return
			if objects[0] is BrainRegion:
				return
			var cortical_area: AbstractCorticalArea = objects[0] as AbstractCorticalArea
			_set_source(cortical_area)
		POSSIBLE_STATES.DESTINATION:
			if _is_ctrl_modifier_held() or len(objects) != 1:
				_sync_destinations_from_selected_objects(objects)
				return
			if len(objects) != 1:
				return
			if objects[0] is BrainRegion:
				return
			var cortical_area: AbstractCorticalArea = objects[0] as AbstractCorticalArea
			_toggle_destination(cortical_area)
		_:
			return

func establish_connection_button():
	print("UI: WINDOW: QUICKCONNECT: User Requesting quick connection...")
	if _source == null:
		return
	if _selected_morphology == null:
		return
	if _destinations.is_empty():
		return
	# Make sure the cache has the current mapping state of the cortical to source area to append to.
	# This supports one-to-many quick connect in a single Establish action.
	for destination_area in _destinations:
		if destination_area == null:
			continue
		FeagiCore.requests.append_default_mapping_between_corticals(_source, destination_area, _selected_morphology)
	## TODO: This is technically a race condition, if a user clicks through the quick connect fast enough
	close_window()

# State Machine
func _update_current_state(new_state: POSSIBLE_STATES) -> void:
	match new_state:
		POSSIBLE_STATES.SOURCE:
			_toggle_add_buttons(false)
			_step4_button.disabled = true
			_set_core_bar_visibility(false)
			_setting_source()

		POSSIBLE_STATES.DESTINATION:
			_toggle_add_buttons(true)
			_step4_button.disabled = true
			_set_core_bar_visibility(false)
			_setting_destination()

		POSSIBLE_STATES.MORPHOLOGY:
			_toggle_add_buttons(false)
			_step4_button.disabled = true
			_set_core_bar_visibility(true)
			_setting_morphology()
		POSSIBLE_STATES.EDIT_MORPHOLOGY:
			_step3_morphology_container.visible = !_step3_morphology_container.visible
			shrink_window()
		POSSIBLE_STATES.IDLE:
			_toggle_add_buttons(true)
			_step4_button.disabled = false
			# Keep the core morphology icon bar visible so user can reselect
			var destination_is_memory: bool = (_destination != null and _destination.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY)
			var source_is_memory: bool = (_source != null and _source.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY)
			var allow_memory_choice: bool = destination_is_memory and source_is_memory
			_set_core_bar_visibility((not destination_is_memory) or allow_memory_choice)
		_:
			push_error("UI: WINDOWS: WindowQuickConnect in unknown state!")
	
	_current_state = new_state



func _setting_source() -> void:
	print("UI: WINDOW: QUICKCONNECT: User Picking Source Area...")
	_source = null
	_step1_label.text = " Please Select A Source Area..."
	_step1_panel.theme_type_variation = "PanelContainer_QC_waiting"

func _setting_destination() -> void:
	print("UI: WINDOW: QUICKCONNECT: User Picking Destination Area...")
	_clear_destination_highlights()
	_destination = null
	_destinations.clear()
	_step2_label.text = " Click destination target(s) to add/remove."
	_step2_panel.theme_type_variation = "PanelContainer_QC_waiting"
	_step4_button.disabled = true
	# Begin live 3D guide from source center to mouse tip while picking destination
	if _source != null:
		var bm = BV.UI.get_brain_monitor_for_cortical_area(_source)
		if bm != null and bm.has_method("start_quick_connect_guide"):
			bm.start_quick_connect_guide(_source)
			# Remember which BM started the guide; used to draw split-screen bridges later
			BV.UI.qc_guide_source_bm = bm

func _setting_morphology() -> void:
	print("UI: WINDOW: QUICKCONNECT: User Picking Connectivity Rule...")
	_stop_quick_connect_guide()
	var mapping_defaults: MappingRestrictionDefault = MappingRestrictionsAPI.get_defaults_between_cortical_areas(_source, _destination)
	var destination_is_memory: bool = (_destination != null and _destination.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY)
	var source_is_memory: bool = (_source != null and _source.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY)
	var allow_memory_choice: bool = destination_is_memory and source_is_memory
	_selected_morphology = null
	_step3_label.text = " Please Select a Connectivity Rule..."
	_step3_panel.theme_type_variation = "PanelContainer_QC_waiting"
	
	# ✅ CRITICAL FIX: Make the morphology container visible so the list appears
	_step3_morphology_container.visible = (not destination_is_memory) or allow_memory_choice
	# Show and (re)populate the Core Morphologies icon bar
	_set_core_bar_visibility((not destination_is_memory) or allow_memory_choice)
	
	# Get restrictions with proper null checking
	var restrictions = MappingRestrictionsAPI.get_restrictions_between_cortical_areas(_source, _destination)
	if restrictions != null and restrictions.has_restricted_morphologies():
		# Use restricted morphologies
		_step3_scroll.set_morphologies(restrictions.get_morphologies_restricted_to())
	else:
		# No restrictions - populate with all available morphologies from cache
		_step3_scroll.repopulate_from_cache()
	# Populate core morph icon shortcuts (respecting restrictions if any)
	_populate_core_morphology_icons(restrictions)
	
	# Auto-select default morphology if available
	var default_morphology: BaseMorphology = mapping_defaults.try_get_default_morphology() if mapping_defaults != null else null
	if default_morphology != null:
		_step3_scroll.select_morphology(default_morphology)
		if destination_is_memory and not allow_memory_choice:
			_set_morphology(default_morphology)

## Repopulate icons when cache updates, only if we're in morphology selection view
func _on_morphology_renamed_for_cache(_old_name: StringName, m: BaseMorphology) -> void:
	_on_morphology_cache_changed(m)

func _on_morphology_cache_changed(_m: BaseMorphology) -> void:
	if _current_state != POSSIBLE_STATES.MORPHOLOGY:
		return
	var restrictions = MappingRestrictionsAPI.get_restrictions_between_cortical_areas(_source, _destination)
	_populate_core_morphology_icons(restrictions)

func _set_core_bar_visibility(visible: bool) -> void:
	_core_bar.visible = visible
	if _core_bar_label != null:
		_core_bar_label.visible = visible

## Priority order for core morphologies (user-defined)
const CORE_MORPHOLOGY_PRIORITY = [
	"projector",
	"block_to_block",
	"lateral_+x",
	"lateral_-x",
	"lateral_+y",
	"lateral_-y",
	"lateral_+z",
	"lateral_-z",
	"last_to_first",
	"projector_xy",
	"projector_yz",
	"projector_xz",
	# Rest will be sorted alphabetically
]

const CORE_ICON_NORMAL_MODULATE := Color(1, 1, 1, 1)
const CORE_ICON_HOVER_MODULATE := Color(1.12, 1.12, 1.12, 1)
const CORE_ICON_SELECTED_MODULATE := Color(1.2, 1.2, 1.2, 1)

## Populates the horizontal icon bar with only CORE (system) morphologies.
## If restrictions are provided, the set is intersected with allowed names and excludes disallowed ones.
func _populate_core_morphology_icons(restrictions: MappingRestrictionCorticalMorphology = null) -> void:
	# Clear previous icons
	for child in _core_icons.get_children():
		child.queue_free()
	_core_icon_buttons.clear()
	_selected_core_icon_button = null

	# Determine allowed names if restricted
	var allowed_names: Array[StringName] = []
	var disallowed_names: Array[StringName] = []
	if restrictions != null:
		if restrictions.has_restricted_morphologies():
			allowed_names = restrictions.restricted_to_morphology_of_names.duplicate()
		if restrictions.has_disallowed_morphologies():
			disallowed_names = restrictions.disallowed_morphology_names.duplicate()

	# Debug logging
	print("QC: CORE ICON BAR → populating...")
	print("  - cache size:", FeagiCore.feagi_local_cache.morphologies.available_morphologies.size())
	print("  - restrictions: allowed=", allowed_names, " disallowed=", disallowed_names)
	var destination_is_memory: bool = (_destination != null and _destination.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY)

	# Get and sort core morphologies by priority
	var morphology_names = FeagiCore.feagi_local_cache.morphologies.available_morphologies.keys()
	var sorted_names = _sort_morphologies_by_priority(morphology_names)
	
	# Iterate sorted morphologies and add CORE ones with valid icons
	var total_core_seen: int = 0
	var total_core_after_filter: int = 0
	var total_icons_added: int = 0
	for morphology_name in sorted_names:
		var morphology: BaseMorphology = FeagiCore.feagi_local_cache.morphologies.available_morphologies[morphology_name]
		if morphology.internal_class != BaseMorphology.MORPHOLOGY_INTERNAL_CLASS.CORE:
			continue
		total_core_seen += 1
		print("  - CORE candidate:", morphology_name)
		# Exclude episodic_memory morphology if destination is not a memory area
		if not destination_is_memory and String(morphology_name).to_lower() == "episodic_memory":
			print("    > excluded 'episodic_memory' for non-memory destination")
			continue
		if len(allowed_names) > 0 and morphology_name not in allowed_names:
			print("    > excluded by allowed list (not in allowed)")
			continue
		if len(disallowed_names) > 0 and morphology_name in disallowed_names:
			print("    > excluded by disallowed list")
			continue
		total_core_after_filter += 1
		var icon_widget: Control = _create_icon_widget_for_morphology(morphology_name, morphology)
		if icon_widget != null:
			_core_icons.add_child(icon_widget)
			total_icons_added += 1
			print("    > icon added for:", morphology_name)

	print("QC: CORE ICON BAR → summary: core_seen=", total_core_seen, ", after_filter=", total_core_after_filter, ", icons_added=", total_icons_added)

## Creates an icon+label widget (VBoxContainer) for a morphology.
## Uses morphology ID (cache key / name string) to match icon filenames.
## Falls back to a default icon if specific icon is missing.
func _create_icon_widget_for_morphology(morphology_id: StringName, morphology: BaseMorphology) -> Control:
	var base_path: StringName = &"res://BrainVisualizer/UI/GenericResources/MorphologyIcons/"
	var texture: Texture2D = null
	# Try by ID, then by display name, then progressively shortened ID prefixes
	var candidates: Array[StringName] = []
	candidates.append(morphology_id)
	if morphology.name != morphology_id:
		candidates.append(morphology.name)
	var tmp: String = String(morphology_id)
	while tmp.find("_") != -1:
		tmp = tmp.left(tmp.rfind("_"))
		if tmp.length() == 0:
			break
		candidates.append(tmp)
	for c in candidates:
		var candidate_path: StringName = base_path + c + &".png"
		if not ResourceLoader.exists(candidate_path):
			continue
		var t: Texture2D = load(candidate_path)
		if t != null:
			print("    > using icon for:", morphology_id, " matched by '", c, "'")
			texture = t
			break
	if texture == null:
		var default_icon_path: StringName = base_path + &"placeholder.png"
		if ResourceLoader.exists(default_icon_path):
			var fallback: Texture2D = load(default_icon_path)
			if fallback != null:
				print("    > using default icon for:", morphology_id)
				texture = fallback
		else:
			push_warning("QC: CORE ICON BAR → default icon missing at '" + String(default_icon_path) + "'")
			return null
		if texture == null:
			push_warning("QC: CORE ICON BAR → failed to load default icon at '" + String(default_icon_path) + "'")
			return null
	var button := TextureButton.new()
	button.texture_normal = texture
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.custom_minimum_size = Vector2(0, 0)
	button.tooltip_text = str(morphology_id)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.toggle_mode = true
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.modulate = CORE_ICON_NORMAL_MODULATE
	var border_style := StyleBoxFlat.new()
	border_style.border_width_left = 1
	border_style.border_width_right = 1
	border_style.border_width_top = 1
	border_style.border_width_bottom = 1
	border_style.border_color = Color(0.7, 0.7, 0.7, 1)
	border_style.bg_color = Color(0, 0, 0, 0)
	var selected_border_style := StyleBoxFlat.new()
	selected_border_style.border_width_left = 1
	selected_border_style.border_width_right = 1
	selected_border_style.border_width_top = 1
	selected_border_style.border_width_bottom = 1
	selected_border_style.border_color = Color(0.2, 0.8, 0.45, 1)
	selected_border_style.bg_color = Color(0, 0, 0, 0)
	var border_panel := PanelContainer.new()
	border_panel.custom_minimum_size = Vector2(320, 240) # tighter vertical footprint so label sits closer
	border_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border_panel.add_theme_stylebox_override("panel", border_style)
	border_panel.set_meta("border_normal", border_style)
	border_panel.set_meta("border_selected", selected_border_style)
	border_panel.add_child(button)
	button.set_meta("border_panel", border_panel)
	button.pressed.connect(Callable(self, "_on_core_icon_pressed").bind(morphology, button))
	var name_label := Label.new()
	name_label.text = str(morphology.name)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var slot := VBoxContainer.new()
	slot.custom_minimum_size = Vector2(180, 0)
	slot.size_flags_vertical = 0
	slot.alignment = BoxContainer.ALIGNMENT_CENTER
	slot.add_theme_constant_override("separation", 0)
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slot.gui_input.connect(Callable(self, "_on_core_icon_slot_input").bind(morphology, button))
	slot.mouse_entered.connect(Callable(self, "_set_core_icon_hover").bind(button, true))
	slot.mouse_exited.connect(Callable(self, "_set_core_icon_hover").bind(button, false))
	button.mouse_entered.connect(Callable(self, "_set_core_icon_hover").bind(button, true))
	button.mouse_exited.connect(Callable(self, "_set_core_icon_hover").bind(button, false))
	slot.add_child(border_panel)
	slot.add_child(name_label)
	_core_icon_buttons.append(button)
	return slot

## Sort morphology names by priority order
func _sort_morphologies_by_priority(names: Array) -> Array:
	var sorted = names.duplicate()
	sorted.sort_custom(func(a, b):
		var a_priority = CORE_MORPHOLOGY_PRIORITY.find(String(a))
		var b_priority = CORE_MORPHOLOGY_PRIORITY.find(String(b))
		
		# Both in priority list - sort by priority index
		if a_priority != -1 and b_priority != -1:
			return a_priority < b_priority
		
		# Only A in priority list - A comes first
		if a_priority != -1:
			return true
		
		# Only B in priority list - B comes first
		if b_priority != -1:
			return false
		
		# Neither in priority list - sort alphabetically
		return String(a) < String(b)
	)
	return sorted

## When a core-icon shortcut is pressed, select it in the list to drive existing flows.
func _on_core_icon_pressed(morphology: BaseMorphology, button: TextureButton) -> void:
	if morphology == null:
		return
	_set_core_icon_selected(button)
	_step3_scroll.select_morphology(morphology)
	_set_morphology(morphology)

## Ensures the entire icon tile (image + label) is clickable.
func _on_core_icon_slot_input(event: InputEvent, morphology: BaseMorphology, button: TextureButton) -> void:
	if morphology == null:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_on_core_icon_pressed(morphology, button)

## Visual hover feedback so the icon tiles feel clickable.
func _set_core_icon_hover(button: TextureButton, is_hovered: bool) -> void:
	if button == null:
		return
	if button == _selected_core_icon_button:
		button.modulate = CORE_ICON_SELECTED_MODULATE
		return
	button.modulate = CORE_ICON_HOVER_MODULATE if is_hovered else CORE_ICON_NORMAL_MODULATE

## Keep a visible selected state for the last chosen icon.
func _set_core_icon_selected(button: TextureButton) -> void:
	if button == null:
		return
	for icon_button in _core_icon_buttons:
		if icon_button == null:
			continue
		var icon_panel: PanelContainer = icon_button.get_meta("border_panel", null) as PanelContainer
		if icon_panel:
			var normal_style: StyleBoxFlat = icon_panel.get_meta("border_normal", null) as StyleBoxFlat
			if normal_style:
				icon_panel.add_theme_stylebox_override("panel", normal_style as StyleBox)
		icon_button.button_pressed = false
		icon_button.modulate = CORE_ICON_NORMAL_MODULATE
	button.button_pressed = true
	button.modulate = CORE_ICON_SELECTED_MODULATE
	var selected_panel: PanelContainer = button.get_meta("border_panel", null) as PanelContainer
	if selected_panel:
		var selected_style: StyleBoxFlat = selected_panel.get_meta("border_selected", null) as StyleBoxFlat
		if selected_style:
			selected_panel.add_theme_stylebox_override("panel", selected_style as StyleBox)
	_selected_core_icon_button = button

func _set_source(cortical_area: AbstractCorticalArea) -> void:
	_source = cortical_area
	_step1_label.text = " Selected Source Area: [" + cortical_area.friendly_name + "]"
	_step1_panel.theme_type_variation = "PanelContainer_QC_Complete"
	if !_finished_selecting:
		_step2_panel.visible = true
		current_state = POSSIBLE_STATES.DESTINATION
	else:
		current_state = POSSIBLE_STATES.IDLE


func _toggle_destination(cortical_area: AbstractCorticalArea) -> void:
	if cortical_area == null:
		return
	var previous_primary: AbstractCorticalArea = _destination
	if cortical_area in _destinations:
		_destinations.erase(cortical_area)
		_set_destination_highlight_state(cortical_area, false)
	else:
		_destinations.append(cortical_area)
		_set_destination_highlight_state(cortical_area, true)
	_destination = _destinations[0] if not _destinations.is_empty() else null
	if _destinations.is_empty():
		_step2_panel.theme_type_variation = "PanelContainer_QC_waiting"
		_step2_label.text = " Click destination target(s) to add/remove."
		_step3_panel.visible = false
		_step3_morphology_container.visible = false
		_set_core_bar_visibility(false)
		_step4_button.disabled = true
	else:
		_step2_panel.theme_type_variation = "PanelContainer_QC_Complete"
		_update_destination_label()
		# Keep destination mode active while Ctrl is held so multi-select can continue
		# with the live guide still visible. Transition to morphology when Ctrl is released.
		if _is_ctrl_modifier_held():
			_step3_panel.visible = false
			_step3_morphology_container.visible = false
			_set_core_bar_visibility(false)
		else:
			_step3_panel.visible = true
			_setting_morphology()
		_step4_button.disabled = true
	# Refresh mapping preview/default context when primary destination changes.
	if _source != null and _destination != null and _destination != previous_primary:
		FeagiCore.requests.get_mappings_between_2_cortical_areas(_source.cortical_ID, _destination.cortical_ID)

func _sync_destinations_from_selected_objects(objects: Array[GenomeObject]) -> void:
	var previous_primary: AbstractCorticalArea = _destination
	_destinations.clear()
	for obj in objects:
		if obj is AbstractCorticalArea:
			_destinations.append(obj as AbstractCorticalArea)
	_destination = _destinations[0] if not _destinations.is_empty() else null
	if _destinations.is_empty():
		_step2_panel.theme_type_variation = "PanelContainer_QC_waiting"
		_step2_label.text = " Click destination target(s) to add/remove."
		_step3_panel.visible = false
		_step3_morphology_container.visible = false
		_set_core_bar_visibility(false)
		_step4_button.disabled = true
	else:
		_step2_panel.theme_type_variation = "PanelContainer_QC_Complete"
		_update_destination_label()
		# Keep destination mode active while Ctrl is held so multi-select can continue
		# with the live guide still visible. Transition to morphology when Ctrl is released.
		if _is_ctrl_modifier_held():
			_step3_panel.visible = false
			_step3_morphology_container.visible = false
			_set_core_bar_visibility(false)
		else:
			_step3_panel.visible = true
			_setting_morphology()
		_step4_button.disabled = true
	if _source != null and _destination != null and _destination != previous_primary:
		FeagiCore.requests.get_mappings_between_2_cortical_areas(_source.cortical_ID, _destination.cortical_ID)

func _update_destination_label() -> void:
	if _destinations.is_empty():
		_step2_label.text = " Click destination target(s) to add/remove."
		return
	var target_names: PackedStringArray = []
	for area in _destinations:
		if area != null:
			target_names.append(area.friendly_name)
	_step2_label.text = " Selected Destination Targets (%d):\n - %s" % [_destinations.size(), "\n - ".join(target_names)]

func _set_destination_highlight_state(cortical_area: AbstractCorticalArea, is_selected: bool) -> void:
	if cortical_area == null:
		return
	if BV == null or BV.UI == null or BV.UI.selection_system == null:
		return
	if is_selected:
		BV.UI.selection_system.add_to_highlighted(cortical_area)
	else:
		BV.UI.selection_system.remove_from_highlighted(cortical_area)

func _clear_destination_highlights() -> void:
	if BV == null or BV.UI == null or BV.UI.selection_system == null:
		return
	for cortical_area in _destinations:
		if cortical_area != null:
			BV.UI.selection_system.remove_from_highlighted(cortical_area)


func _set_morphology(morphology: BaseMorphology) -> void:
	_selected_morphology = morphology
	_step3_label.text = " Selected Connectivity Rule: " + morphology.name
	_step3_panel.theme_type_variation = "PanelContainer_QC_Complete"
	_step3_morphology_view.load_morphology(morphology)
	_step3_morphology_details.load_morphology(morphology)
	_finished_selecting = true
	# Return to IDLE so edit buttons reappear and Establish is enabled.
	# IDLE keeps the core icon bar visible (we adjusted this earlier).
	current_state = POSSIBLE_STATES.IDLE

func _stop_quick_connect_guide() -> void:
	if _source == null:
		BV.UI.qc_guide_source_bm = null
		return
	var source_bm = BV.UI.get_brain_monitor_for_cortical_area(_source)
	if source_bm != null and source_bm.has_method("stop_quick_connect_guide"):
		source_bm.stop_quick_connect_guide()
	BV.UI.qc_guide_source_bm = null

func _is_ctrl_modifier_held() -> bool:
	return Input.is_physical_key_pressed(KEY_CTRL)

func _is_ctrl_key(keycode: int) -> bool:
	return keycode == KEY_CTRL


func _toggle_add_buttons(is_enabled: bool):
	_step1_button.visible = is_enabled
	_step2_button.visible = is_enabled
	_step3_button.visible = is_enabled

#TODO Delete?
func _set_completion_state():
	if _source == null:
		_finished_selecting = false
		_step4_button.visible = false
		return
	if _destinations.is_empty():
		_finished_selecting = false
		_step4_button.visible = false
		return
	if _selected_morphology == null:
		_finished_selecting = false
		_step4_button.visible = false
		return	
	_finished_selecting = true
	_step4_button.visible = true
		
func close_window():
	_stop_quick_connect_guide()
	super()
	BV.UI.selection_system.remove_override_usecase(SelectionSystem.OVERRIDE_USECASE.QUICK_CONNECT)
	_clear_destination_highlights()
