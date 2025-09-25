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
var _core_bar: ScrollContainer
var _core_icons: HBoxContainer

var _current_state: POSSIBLE_STATES = POSSIBLE_STATES.IDLE
var _finished_selecting: bool = false

var _source: AbstractCorticalArea = null
var _destination: AbstractCorticalArea = null
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
	_core_bar = _window_internals.get_node("CoreMorphologiesBar")
	_core_icons = _window_internals.get_node("CoreMorphologiesBar/Icons")
	
	_step3_scroll.morphology_selected.connect(_set_morphology)
	# Update icon bar reactively when morphologies change (e.g., when 'class' becomes 'core')
	FeagiCore.feagi_local_cache.morphologies.morphology_updated.connect(_on_morphology_cache_changed)
	FeagiCore.feagi_local_cache.morphologies.morphology_added.connect(_on_morphology_cache_changed)
	
	BV.UI.selection_system.add_override_usecase(SelectionSystem.OVERRIDE_USECASE.QUICK_CONNECT)
	BV.UI.selection_system.objects_selection_event_called.connect(_on_user_selection)
	
	
	_step1_panel.theme_type_variation = "PanelContainer_QC_incomplete"
	_step2_panel.theme_type_variation = "PanelContainer_QC_incomplete"
	_step3_panel.theme_type_variation = "PanelContainer_QC_incomplete"
	current_state = POSSIBLE_STATES.SOURCE

func setup(cortical_source_if_picked: AbstractCorticalArea) -> void:
	_setup_base_window(WINDOW_NAME)
	if cortical_source_if_picked != null:
		_set_source(cortical_source_if_picked)

func _on_user_selection(objects: Array[GenomeObject], context: SelectionSystem.SOURCE_CONTEXT, _override_usecases: Array[SelectionSystem.OVERRIDE_USECASE]) -> void:
	if len(objects) != 1:
		return
	if objects[0] is BrainRegion:
		return
	var cortical_area: AbstractCorticalArea = objects[0] as AbstractCorticalArea
	
	match _current_state:
		POSSIBLE_STATES.SOURCE:
			_set_source(cortical_area)
		POSSIBLE_STATES.DESTINATION:
			_set_destination(cortical_area)
		_:
			return

func establish_connection_button():
	print("UI: WINDOW: QUICKCONNECT: User Requesting quick connection...")

	# Make sure the cache has the current mapping state of the cortical to source area to append to
	FeagiCore.requests.append_default_mapping_between_corticals(_source, _destination, _selected_morphology)
	## TODO: This is technically a race condition, if a user clicks through the quick connect fast enough
	close_window()

# State Machine
func _update_current_state(new_state: POSSIBLE_STATES) -> void:
	match new_state:
		POSSIBLE_STATES.SOURCE:
			_toggle_add_buttons(false)
			_step4_button.disabled = true
			_core_bar.visible = false
			_setting_source()

		POSSIBLE_STATES.DESTINATION:
			_toggle_add_buttons(false)
			_step4_button.disabled = true
			_core_bar.visible = false
			_setting_destination()

		POSSIBLE_STATES.MORPHOLOGY:
			_toggle_add_buttons(false)
			_step4_button.disabled = true
			_core_bar.visible = true
			_setting_morphology()
		POSSIBLE_STATES.EDIT_MORPHOLOGY:
			_step3_morphology_container.visible = !_step3_morphology_container.visible
			shrink_window()
		POSSIBLE_STATES.IDLE:
			_toggle_add_buttons(true)
			_step4_button.disabled = false
			_core_bar.visible = false
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
	_destination = null
	_step2_label.text = " Please Select A Destination Area..."
	_step2_panel.theme_type_variation = "PanelContainer_QC_waiting"

func _setting_morphology() -> void:
	print("UI: WINDOW: QUICKCONNECT: User Picking Connectivity Rule...")
	var mapping_defaults: MappingRestrictionDefault = MappingRestrictionsAPI.get_defaults_between_cortical_areas(_source, _destination)
	_selected_morphology = null
	_step3_label.text = " Please Select A Morphology..."
	_step3_panel.theme_type_variation = "PanelContainer_QC_waiting"
	
	# ✅ CRITICAL FIX: Make the morphology container visible so the list appears
	_step3_morphology_container.visible = true
	# Show and (re)populate the Core Morphologies icon bar
	_core_bar.visible = true
	
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
	if mapping_defaults != null and mapping_defaults.try_get_default_morphology() != null:
		_step3_scroll.select_morphology(mapping_defaults.try_get_default_morphology())

## Repopulate icons when cache updates, only if we're in morphology selection view
func _on_morphology_cache_changed(_m: BaseMorphology) -> void:
	if _current_state != POSSIBLE_STATES.MORPHOLOGY:
		return
	var restrictions = MappingRestrictionsAPI.get_restrictions_between_cortical_areas(_source, _destination)
	_populate_core_morphology_icons(restrictions)

## Populates the horizontal icon bar with only CORE (system) morphologies.
## If restrictions are provided, the set is intersected with allowed names and excludes disallowed ones.
func _populate_core_morphology_icons(restrictions: MappingRestrictionCorticalMorphology = null) -> void:
	# Clear previous icons
	for child in _core_icons.get_children():
		child.queue_free()

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

	# Iterate available morphologies by ID (cache key) and add CORE ones with valid icons
	var total_core_seen: int = 0
	var total_core_after_filter: int = 0
	var total_icons_added: int = 0
	for morphology_name in FeagiCore.feagi_local_cache.morphologies.available_morphologies.keys():
		var morphology: BaseMorphology = FeagiCore.feagi_local_cache.morphologies.available_morphologies[morphology_name]
		if morphology.internal_class != BaseMorphology.MORPHOLOGY_INTERNAL_CLASS.CORE:
			continue
		total_core_seen += 1
		print("  - CORE candidate:", morphology_name)
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
		var t: Texture2D = load(candidate_path)
		if t != null:
			print("    > using icon for:", morphology_id, " matched by '", c, "'")
			texture = t
			break
	if texture == null:
		var default_icon_path: StringName = base_path + &"placeholder.png"
		var fallback: Texture2D = load(default_icon_path)
		if fallback != null:
			print("    > using default icon for:", morphology_id)
			texture = fallback
		else:
			push_warning("QC: CORE ICON BAR → default icon missing at '" + String(default_icon_path) + "'")
			return null
	var button := TextureButton.new()
	button.texture_normal = texture
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.custom_minimum_size = Vector2(160, 160) # leave room for label inside 100px row
	button.tooltip_text = str(morphology_id)
	button.pressed.connect(Callable(self, "_on_core_icon_pressed").bind(morphology))
	var name_label := Label.new()
	name_label.text = str(morphology.name)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var slot := VBoxContainer.new()
	slot.custom_minimum_size = Vector2(90, 100)
	slot.size_flags_vertical = 0
	slot.alignment = BoxContainer.ALIGNMENT_CENTER
	slot.add_child(button)
	slot.add_child(name_label)
	return slot

## When a core-icon shortcut is pressed, select it in the list to drive existing flows.
func _on_core_icon_pressed(morphology: BaseMorphology) -> void:
	if morphology == null:
		return
	_step3_scroll.select_morphology(morphology)

func _set_source(cortical_area: AbstractCorticalArea) -> void:
	_source = cortical_area
	_step1_label.text = " Selected Source Area: [" + cortical_area.friendly_name + "]"
	_step1_panel.theme_type_variation = "PanelContainer_QC_Complete"
	if !_finished_selecting:
		_step2_panel.visible = true
		current_state = POSSIBLE_STATES.DESTINATION
	else:
		current_state = POSSIBLE_STATES.IDLE


func _set_destination(cortical_area: AbstractCorticalArea) -> void:
	_destination = cortical_area
	_step2_label.text = " Selected Destination Area: [" + cortical_area.friendly_name + "]"
	_step2_panel.theme_type_variation = "PanelContainer_QC_Complete"
	FeagiCore.requests.get_mappings_between_2_cortical_areas(_source.cortical_ID, _destination.cortical_ID)
	if !_finished_selecting:
		_step3_panel.visible = true
		current_state = POSSIBLE_STATES.MORPHOLOGY
		pass
	else:
		current_state = POSSIBLE_STATES.IDLE


func _set_morphology(morphology: BaseMorphology) -> void:
	_selected_morphology = morphology
	_step3_label.text = " Selected Connectivity Rule: " + morphology.name
	_step3_panel.theme_type_variation = "PanelContainer_QC_Complete"
	_step3_morphology_view.load_morphology(morphology)
	_step3_morphology_details.load_morphology(morphology)
	_finished_selecting = true
	current_state = POSSIBLE_STATES.IDLE


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
	if _destination == null:
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
	super()
	BV.UI.selection_system.remove_override_usecase(SelectionSystem.OVERRIDE_USECASE.QUICK_CONNECT)
