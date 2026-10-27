extends BaseDraggableWindow
class_name WindowCreateModulator

const WINDOW_NAME: StringName = "create_modulator"

const _Effect = preload("res://BrainVisualizer/UI/Windows/CreateModulator/ModulatorEffect.gd")

const _LABEL_WIDTH: float = 130.0

## Emitted with the new instance id after FEAGI accepted the create request.
signal modulator_created(instance_id: String)
## Emitted with the instance id (the new one after a rename) after FEAGI accepted the update request.
signal modulator_updated(instance_id: String)

const _TILE_SCENE: PackedScene = preload("res://BrainVisualizer/UI/GenericElements/Buttons/PanelContainerButton/PanelContainerButton.tscn")
const _ICON_MAPPING: Texture2D = preload("res://BrainVisualizer/UI/GenericResources/ButtonIcons/neuron.png")
const _ICON_AREA: Texture2D = preload("res://BrainVisualizer/UI/GenericResources/ButtonIcons/top_bar_connectivity_rules.png")
const _TILE_WIDTH: float = 240.0
const _TILE_PADDING: int = 14
const _TILE_GAP: int = 16
const _ICON_SLOT: float = 96.0
## Card text sizes relative to the theme's Label size, so they follow the UI scale.
const _TITLE_SCALE: float = 1.3
const _EXAMPLES_SHRINK: int = 2

const HEADER_CHOOSE_KIND: String = "What should it act on?"
const HEADER_CHOOSE_MAPPING_TYPE: String = "Pick a synaptic modulator"
const HEADER_CHOOSE_AREA_TYPE: String = "Pick a neuromodulator"
const HEADER_DONE: String = "Modulator added"
## [scope, title, subtitle, description, examples, tooltip] per kind of modulator.
const _KINDS: Array = [
	["mapping", "Mappings", "Synaptic modulators", "Change how connections pass signal or learn.", "Reward \u00b7 Gain \u00b7 Gate \u00b7 Learning rate", "Synaptic modulators act on the mappings between areas."],
	["area", "Areas", "Neuromodulators", "Change how neurons in an area fire.", "Threshold \u00b7 Leak \u00b7 Firing probability", "Neuromodulators act on the neurons of an area."],
]

enum Step { PICK_KIND, PICK_TYPE, FORM, DONE }

var _step: Step = Step.PICK_KIND
var _header: Label
var _kind_box: VBoxContainer
var _step1_box: VBoxContainer
var _step2_box: VBoxContainer
var _step3_box: VBoxContainer
var _bottom_box: VBoxContainer
var _back_button: Button
var _cancel_button: Button
var _type_tile_holder: VBoxContainer
var _done_summary: RichTextLabel
var _next_steps_box: VBoxContainer
var _allowed_infos: Array[Dictionary] = []
## True when the allowed types leave one kind (scope) only, so the kind step is skipped.
var _skip_kind_step: bool = false
## True when exactly one type is allowed, so the type step is skipped too.
var _skip_type_step: bool = false
## Scope ("mapping" / "area") picked in the kind step.
var _scope: String = ""
var _type: String = ""
var _summary: RichTextLabel
var _instance_id: LineEdit
var _strength_row: HBoxContainer
var _strength_direction: OptionButton
var _strength_amount: SpinBox
var _strength_slider: HSlider
var _strength_multiplier: SpinBox
var _duration: LineEdit
var _rest: LineEdit
var _advanced_toggle: Button
var _advanced_box: VBoxContainer
var _graded: CheckBox
var _full_scale_row: HBoxContainer
var _full_scale: LineEdit
var _status: Label
var _create_button: Button
var _trigger_box: VBoxContainer
var _usage_box: VBoxContainer
var _edit_mode: bool = false
## Id the modulator has on FEAGI right now (edit mode); a different Name triggers a rename on Save.
var _original_id: String = ""
## Set once the user types a Name, so type changes stop overwriting the suggestion.
var _name_typed: bool = false
## Set once the user changes the Strength control, so type changes stop applying the type's default.
var _strength_edited: bool = false
## Create mode: starting magnitude_percent instead of the type default. NAN uses the type default.
var _preset_magnitude: float = NAN
## Edit mode: magnitude_percent as stored, kept exact until the user touches Strength (the spin boxes round to their step).
var _loaded_magnitude: float = NAN
var _existing_ids: Array = []


## [allowed_types] limits the type tiles (empty = all kinds); [default_type] is used when only that kind remains.
## [preset_magnitude] starts Strength at that magnitude_percent instead of the type default.
func setup(allowed_types: Array[String] = [], default_type: String = "", preset_magnitude: float = NAN) -> void:
	_preset_magnitude = preset_magnitude
	_setup_base_window(WINDOW_NAME)
	_titlebar.title = "Add modulator"
	_build_form()
	_allowed_infos.clear()
	for info in _Effect.TYPES:
		if allowed_types.is_empty() or str(info["type"]) in allowed_types:
			_allowed_infos.append(info)
	if _allowed_infos.is_empty():
		_allowed_infos.assign(_Effect.TYPES)
	_add_note(_trigger_box, "FEAGI creates the trigger area automatically.")
	_load_existing_ids()
	var scopes: Array[String] = []
	for info in _allowed_infos:
		if not str(info["scope"]) in scopes:
			scopes.append(str(info["scope"]))
	_skip_type_step = _allowed_infos.size() == 1
	_skip_kind_step = scopes.size() == 1
	if _skip_type_step:
		_scope = scopes[0]
		_on_type_picked(str(_allowed_infos[0]["type"]))
	elif _skip_kind_step:
		_on_kind_picked(scopes[0])
	else:
		_step_0_pick_kind()


## Edit mode: prefills every field from [param definition]; Type is read-only, Name can be renamed.
func setup_edit(instance_id: String, definition: Dictionary) -> void:
	_setup_base_window(WINDOW_NAME)
	_titlebar.title = "Edit modulator"
	_build_form()
	_edit_mode = true
	_original_id = instance_id
	var raw_type := str(definition.get("type", ""))
	_type = raw_type
	_type_tile_holder.add_child(_make_tile(_Effect.type_info(raw_type), false))
	_configure_strength_controls()
	_instance_id.text = instance_id
	_loaded_magnitude = float(definition.get("magnitude_percent", 0))
	_set_strength_from_magnitude(_loaded_magnitude)
	_duration.text = str(definition.get("effect_duration_bursts", 1))
	_rest.text = str(definition.get("rest_bursts", 0))
	var graded := bool(definition.get("graded", false))
	_graded.set_pressed_no_signal(graded)
	_full_scale.text = str(definition.get("full_scale_potential", 1))
	_full_scale_row.visible = graded
	_set_advanced_open(graded)
	_create_button.text = "Save"
	_back_button.visible = false
	_build_trigger_section(str(definition.get("driver_cortical_id", "")))
	_build_usage_section(instance_id)
	_refresh_summary()
	_show_step(Step.FORM)
	_header.text = "Editing %s" % instance_id


func _show_step(step: Step) -> void:
	_step = step
	_kind_box.visible = step == Step.PICK_KIND
	_step1_box.visible = step == Step.PICK_TYPE
	_step2_box.visible = step == Step.FORM
	_step3_box.visible = step == Step.DONE
	_bottom_box.visible = step == Step.PICK_TYPE or step == Step.FORM
	_create_button.visible = step != Step.PICK_TYPE
	shrink_window()
	_shrink_after_layout.call_deferred()


## Shrinks once the new step has been laid out, so the window never keeps the height of a taller step.
func _shrink_after_layout() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(self):
		shrink_window()


## Gives every card of a step the same slot height per text row (the tallest text in that row), so the rows align.
func _equalize_card_slots(cards: Array) -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	for row_name in ["Title", "Subtitle", "Description", "Examples"]:
		var tallest := 0.0
		for card in cards:
			var label: Control = card.find_child(row_name, true, false)
			if label != null:
				tallest = maxf(tallest, label.get_combined_minimum_size().y)
		for card in cards:
			var label: Control = card.find_child(row_name, true, false)
			if label != null:
				label.custom_minimum_size.y = tallest
	_shrink_after_layout()


func _step_0_pick_kind() -> void:
	_header.text = HEADER_CHOOSE_KIND
	_show_step(Step.PICK_KIND)


func _step_1_pick_type() -> void:
	_header.text = HEADER_CHOOSE_MAPPING_TYPE if _scope == "mapping" else HEADER_CHOOSE_AREA_TYPE
	_back_button.visible = not _skip_kind_step
	_show_step(Step.PICK_TYPE)


func _step_2_form() -> void:
	_header.text = "Editing %s" % _original_id if _edit_mode else "Adding %s modulator" % str(_Effect.type_info(_type)["label"])
	_back_button.visible = not _edit_mode and not _skip_type_step
	_show_step(Step.FORM)


func _on_back_pressed() -> void:
	if _step == Step.FORM:
		_step_1_pick_type()
	elif _step == Step.PICK_TYPE:
		_step_0_pick_kind()


func _on_kind_picked(scope: String) -> void:
	_scope = scope
	_populate_type_tiles()
	_step_1_pick_type()


func _on_type_picked(raw_type: String) -> void:
	_on_type_selected(raw_type)
	_step_2_form()


## Fills the type step: a two-column grid of tiles for the picked scope.
func _populate_type_tiles() -> void:
	for child in _step1_box.get_children():
		_step1_box.remove_child(child)
		child.queue_free()
	var grid := GridContainer.new()
	grid.name = "Grid_" + _scope
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", _TILE_GAP)
	grid.add_theme_constant_override("v_separation", _TILE_GAP)
	var cards: Array = []
	for info in _allowed_infos:
		if str(info["scope"]) == _scope:
			var tile := _make_tile(info, true)
			cards.append(tile)
			grid.add_child(tile)
	_step1_box.add_child(grid)
	_equalize_card_slots(cards)


## Kind step: two big tiles side by side, like the connectivity rule picker.
func _populate_kind_tiles() -> void:
	var cards: Array = []
	var row := HBoxContainer.new()
	row.name = "KindTiles"
	row.add_theme_constant_override("separation", _TILE_GAP)
	for kind in _KINDS:
		var tile := _make_card("Kind_" + str(kind[0]), str(kind[0]), str(kind[1]), str(kind[2]), str(kind[3]), str(kind[4]), str(kind[5]))
		tile.pressed.connect(_on_kind_picked.bind(str(kind[0])))
		row.add_child(tile)
		cards.append(tile)
	_kind_box.add_child(row)
	_equalize_card_slots(cards)


## Tile for one modulator type.
func _make_tile(info: Dictionary, clickable: bool) -> PanelContainerButton:
	var tile := _make_card("Type_" + str(info["type"]).replace(".", "_"), "", str(info["label"]), "", str(info["desc"]), "", str(info["hint"]))
	if clickable:
		tile.pressed.connect(_on_type_picked.bind(str(info["type"])))
	return tile


## Kind cards are vertical and centered (icon slot, title, subtitle, description, examples); type cards ([param scope]
## empty) are compact and left-aligned (title, description). Equal text rows are aligned by [method _equalize_card_slots].
func _make_card(node_name: String, scope: String, title_text: String, subtitle_text: String, description_text: String, examples_text: String, hint: String) -> PanelContainerButton:
	var with_icon := not scope.is_empty()
	var align := HORIZONTAL_ALIGNMENT_CENTER if with_icon else HORIZONTAL_ALIGNMENT_LEFT
	var tile: PanelContainerButton = _TILE_SCENE.instantiate()
	tile.name = node_name
	tile.custom_minimum_size = Vector2(_TILE_WIDTH, 0)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.size_flags_vertical = Control.SIZE_FILL
	tile.tooltip_text = hint
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, _TILE_PADDING)
	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	if with_icon:
		var slot := Control.new()
		slot.name = "IconSlot"
		slot.custom_minimum_size = Vector2(0, _ICON_SLOT)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.texture = _ICON_AREA if scope == "area" else _ICON_MAPPING
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		column.add_child(slot)
	column.add_child(_card_label("Title", title_text, &"", align, 1.0, roundi(_body_size() * _TITLE_SCALE)))
	if not subtitle_text.is_empty():
		column.add_child(_card_label("Subtitle", subtitle_text, &"", align, 0.6, 0))
	column.add_child(_card_label("Description", description_text, &"", align, 0.9, 0))
	if not examples_text.is_empty():
		column.add_child(_card_label("Examples", examples_text, &"", align, 0.55, _body_size() - _EXAMPLES_SHRINK))
	tile.add_child(margin)
	return tile


func _body_size() -> int:
	return get_theme_font_size("font_size", "Label")


## Wrapping label inside a card; [param font_size] 0 keeps the theme size.
func _card_label(node_name: String, text: String, variation: StringName, align: HorizontalAlignment, alpha: float, font_size: int) -> Label:
	var label := Label.new()
	label.name = node_name
	if variation != &"":
		label.theme_type_variation = variation
	if font_size > 0:
		label.add_theme_font_size_override("font_size", font_size)
	label.text = text
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(_TILE_WIDTH - 2 * _TILE_PADDING, 0)
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	label.modulate = Color(1, 1, 1, alpha)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _on_type_selected(raw_type: String) -> void:
	_type = raw_type
	_configure_strength_controls()
	if not _edit_mode and not _strength_edited:
		var magnitude: float = _Effect.default_magnitude(raw_type) if is_nan(_preset_magnitude) else _preset_magnitude
		_set_strength_from_magnitude(magnitude)
	_suggest_name_if_untyped()
	_refresh_summary()


func _suggest_name_if_untyped() -> void:
	if not _edit_mode and not _name_typed:
		_instance_id.text = _suggest_name(str(_Effect.type_info(_type)["prefix"]))


## First "prefix_N" (N from 1) that no existing modulator uses.
func _suggest_name(prefix: String) -> String:
	var number := 1
	while ("%s_%d" % [prefix, number]) in _existing_ids:
		number += 1
	return "%s_%d" % [prefix, number]


func _load_existing_ids() -> void:
	if not FeagiCore.can_interact_with_feagi():
		return
	var response: FeagiRequestOutput = await FeagiCore.requests.list_modulators()
	if response == null or response.has_errored or not is_instance_valid(self):
		return
	_existing_ids = response.decode_response_as_dict().keys()
	_suggest_name_if_untyped()
	_refresh_summary()


func _on_name_typed(_text: String) -> void:
	_name_typed = true
	_refresh_summary()


func _build_form() -> void:
	if _window_internals.get_node_or_null("Header") != null:
		return
	_window_internals.add_theme_constant_override("separation", 12)
	_header = Label.new()
	_header.name = "Header"
	_header.theme_type_variation = &"Label_Header"
	_window_internals.add_child(_header)
	_window_internals.add_child(HSeparator.new())
	_kind_box = VBoxContainer.new()
	_kind_box.name = "StepKind"
	_window_internals.add_child(_kind_box)
	_populate_kind_tiles()
	_step1_box = VBoxContainer.new()
	_step1_box.name = "Step1"
	_step1_box.add_theme_constant_override("separation", 12)
	_window_internals.add_child(_step1_box)
	_step2_box = VBoxContainer.new()
	_step2_box.name = "Step2"
	_step2_box.add_theme_constant_override("separation", 12)
	_step2_box.custom_minimum_size.x = 420
	_window_internals.add_child(_step2_box)
	_step3_box = VBoxContainer.new()
	_step3_box.name = "Step3"
	_step3_box.add_theme_constant_override("separation", 12)
	_step3_box.custom_minimum_size.x = 420
	_window_internals.add_child(_step3_box)
	_build_step2()
	_build_step3()
	_bottom_box = VBoxContainer.new()
	_bottom_box.name = "BottomBar"
	_bottom_box.add_theme_constant_override("separation", 12)
	_bottom_box.add_child(HSeparator.new())
	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 8)
	_back_button = _big_button("Back", _on_back_pressed)
	_back_button.name = "Back"
	buttons.add_child(_back_button)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(gap)
	_cancel_button = _big_button("Cancel", close_window)
	_cancel_button.name = "Cancel"
	buttons.add_child(_cancel_button)
	_create_button = _big_button("Add", _on_create)
	_create_button.name = "Add"
	buttons.add_child(_create_button)
	_bottom_box.add_child(buttons)
	_window_internals.add_child(_bottom_box)
	_show_step(Step.PICK_KIND)


func _big_button(text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(96, 32)
	button.pressed.connect(handler)
	return button


func _build_step2() -> void:
	_summary = RichTextLabel.new()
	_summary.name = "EffectSummary"
	_summary.bbcode_enabled = true
	_summary.fit_content = true
	_summary.scroll_active = false
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.custom_minimum_size = Vector2(400, 0)
	_step2_box.add_child(_summary_panel(_summary))
	_type_tile_holder = VBoxContainer.new()
	_type_tile_holder.name = "TypeTile"
	_step2_box.add_child(_type_tile_holder)
	_instance_id = _line("InstanceName", "")
	_instance_id.text_changed.connect(_on_name_typed)
	var name_row := _labeled_row("Name", _instance_id, "Used to subscribe mappings and areas to this modulator")
	name_row.name = "Name"
	_step2_box.add_child(name_row)
	_build_strength_row()
	var timing := HBoxContainer.new()
	timing.name = "Timing"
	timing.add_theme_constant_override("separation", 12)
	_duration = _line("Duration", "1")
	_duration.text_changed.connect(func(_text: String) -> void: _refresh_summary())
	timing.add_child(_stacked_field("Lasts (bursts)", _duration, "How many bursts the effect stays on after the trigger fires."))
	_rest = _line("Rest", "0")
	_rest.text_changed.connect(func(_text: String) -> void: _refresh_summary())
	timing.add_child(_stacked_field("Cooldown (bursts)", _rest, "Bursts the modulator waits before it can be triggered again."))
	_step2_box.add_child(timing)
	_build_advanced_section()
	_trigger_box = VBoxContainer.new()
	_trigger_box.name = "TriggeredBy"
	_step2_box.add_child(_trigger_box)
	_usage_box = VBoxContainer.new()
	_usage_box.name = "UsedBy"
	_usage_box.visible = false
	_step2_box.add_child(_usage_box)
	_status = Label.new()
	_status.name = "Status"
	_status.visible = false
	_step2_box.add_child(_status)


## Wraps [param content] in a subtle, slightly lighter padded panel.
func _summary_panel(content: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.06)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(content)
	return panel


func _set_status(text: String) -> void:
	_status.text = text
	_status.visible = not text.is_empty()


func _build_step3() -> void:
	_done_summary = RichTextLabel.new()
	_done_summary.name = "DoneSummary"
	_done_summary.bbcode_enabled = true
	_done_summary.fit_content = true
	_done_summary.scroll_active = false
	_done_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_done_summary.custom_minimum_size = Vector2(400, 0)
	_step3_box.add_child(_summary_panel(_done_summary))
	var next_title := Label.new()
	next_title.theme_type_variation = &"Label_Header"
	next_title.text = "Next steps"
	_step3_box.add_child(next_title)
	_next_steps_box = VBoxContainer.new()
	_next_steps_box.name = "NextSteps"
	_next_steps_box.add_theme_constant_override("separation", 8)
	_step3_box.add_child(_next_steps_box)
	_step3_box.add_child(HSeparator.new())
	var done_row := HBoxContainer.new()
	done_row.alignment = BoxContainer.ALIGNMENT_END
	var done := _big_button("Done", close_window)
	done.name = "Done"
	done_row.add_child(done)
	_step3_box.add_child(done_row)


## Strength row: direction toggle + percent box, or multiplier slider + box; which parts show depends on the type.
func _build_strength_row() -> void:
	_strength_direction = OptionButton.new()
	_strength_direction.name = "StrengthDirection"
	_strength_direction.item_selected.connect(func(_index: int) -> void: _on_strength_edited())
	_strength_amount = SpinBox.new()
	_strength_amount.name = "StrengthAmount"
	_strength_amount.step = 0.01
	_strength_amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_strength_amount.value_changed.connect(func(_value: float) -> void: _on_strength_edited())
	_strength_slider = HSlider.new()
	_strength_slider.name = "StrengthSlider"
	_strength_slider.min_value = 0.0
	_strength_slider.max_value = 3.0
	_strength_slider.step = 0.05
	_strength_slider.allow_greater = true
	_strength_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_strength_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_strength_slider.value_changed.connect(_on_strength_slider_changed)
	_strength_multiplier = SpinBox.new()
	_strength_multiplier.name = "StrengthMultiplier"
	_strength_multiplier.min_value = 0.0
	_strength_multiplier.max_value = 3.0
	_strength_multiplier.step = 0.01
	_strength_multiplier.allow_greater = true
	_strength_multiplier.suffix = "\u00d7"
	_strength_multiplier.value_changed.connect(_on_strength_multiplier_changed)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	for control in [_strength_direction, _strength_amount, _strength_slider, _strength_multiplier]:
		controls.add_child(control)
	_strength_row = _labeled_row("Strength", controls, "How strongly the effect applies while the trigger is firing.")
	_strength_row.name = "Strength"
	_step2_box.add_child(_strength_row)


## Shows and fills the Strength parts that fit the current type.
func _configure_strength_controls() -> void:
	var kind := _Effect.control_kind(_type)
	var is_multiplier := kind == _Effect.CONTROL_MULTIPLIER
	_strength_slider.visible = is_multiplier
	_strength_multiplier.visible = is_multiplier
	_strength_amount.visible = not is_multiplier
	_strength_direction.visible = kind == _Effect.CONTROL_REWARD or kind == _Effect.CONTROL_ADJUST
	_strength_direction.clear()
	if kind == _Effect.CONTROL_REWARD:
		_add_direction("Reward", true)
		_add_direction("Punishment", false)
	elif kind == _Effect.CONTROL_ADJUST:
		_add_direction("Lower", false)
		_add_direction("Raise", true)
	_strength_amount.min_value = 0.0
	_strength_amount.max_value = 100.0
	_strength_amount.allow_greater = kind != _Effect.CONTROL_REWARD
	_strength_amount.suffix = "% of signal when open" if kind == _Effect.CONTROL_GATE else "%"


func _add_direction(title: String, raising: bool) -> void:
	_strength_direction.add_item(title)
	_strength_direction.set_item_metadata(_strength_direction.item_count - 1, raising)


## Writes [param magnitude_percent] into the Strength controls without marking them as user-edited.
func _set_strength_from_magnitude(magnitude_percent: float) -> void:
	var control := _Effect.magnitude_to_control(_type, magnitude_percent)
	var amount := float(control["amount"])
	if _strength_direction.visible:
		for index in _strength_direction.item_count:
			if bool(_strength_direction.get_item_metadata(index)) == bool(control["raising"]):
				_strength_direction.select(index)
	_strength_amount.set_value_no_signal(amount)
	_strength_multiplier.set_value_no_signal(amount)
	_strength_slider.set_value_no_signal(amount)


## magnitude_percent the Strength controls currently describe.
func _current_magnitude() -> float:
	if _edit_mode and not _strength_edited and not is_nan(_loaded_magnitude):
		return _loaded_magnitude
	var raising := true
	if _strength_direction.visible and _strength_direction.selected >= 0:
		raising = bool(_strength_direction.get_item_metadata(_strength_direction.selected))
	var amount := _strength_multiplier.value if _strength_multiplier.visible else _strength_amount.value
	return _Effect.control_to_magnitude(_type, raising, amount)


func _on_strength_edited() -> void:
	_strength_edited = true
	_refresh_summary()


func _on_strength_slider_changed(value: float) -> void:
	_strength_multiplier.set_value_no_signal(value)
	_on_strength_edited()


func _on_strength_multiplier_changed(value: float) -> void:
	_strength_slider.set_value_no_signal(value)
	_on_strength_edited()


## Collapsible "Advanced" section holding Graded and Full-scale charge.
func _build_advanced_section() -> void:
	_advanced_toggle = Button.new()
	_advanced_toggle.name = "AdvancedToggle"
	_advanced_toggle.flat = true
	_advanced_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_advanced_toggle.pressed.connect(func() -> void: _set_advanced_open(not _advanced_box.visible))
	_step2_box.add_child(_advanced_toggle)
	_advanced_box = VBoxContainer.new()
	_advanced_box.name = "Advanced"
	_graded = CheckBox.new()
	_graded.text = "Graded"
	_graded.tooltip_text = "Strength scales with how hard the trigger fires."
	_graded.toggled.connect(_on_graded_toggled)
	_advanced_box.add_child(_graded)
	_advanced_box.add_child(_note_label("Graded: the effect scales with how strongly the trigger fires, reaching full strength at the full-scale charge."))
	_full_scale = _line("FullScale", "1")
	_full_scale.text_changed.connect(func(_text: String) -> void: _refresh_summary())
	_full_scale_row = _labeled_row("Full-scale charge", _full_scale, "Trigger charge that counts as full strength.")
	_full_scale_row.visible = false
	_advanced_box.add_child(_full_scale_row)
	_step2_box.add_child(_advanced_box)
	_set_advanced_open(false)


func _set_advanced_open(open: bool) -> void:
	_advanced_box.visible = open
	_advanced_toggle.text = ("\u25be " if open else "\u25b8 ") + "Advanced"


func _labeled_row(title: String, control: Control, tooltip: String = "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(_LABEL_WIDTH, 0)
	if not tooltip.is_empty():
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		label.tooltip_text = tooltip
		control.tooltip_text = tooltip
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


## Caption above a field, for rows that hold two fields side by side.
func _stacked_field(title: String, control: Control, tooltip: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label := Label.new()
	label.text = title
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	label.tooltip_text = tooltip
	control.tooltip_text = tooltip
	column.add_child(label)
	column.add_child(control)
	return column


func _line(node_name: String, text: String) -> LineEdit:
	var field := LineEdit.new()
	field.name = node_name
	field.text = text
	field.custom_minimum_size = Vector2(80, 0)
	return field


## Small wrapped explanation label.
func _note_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(400, 0)
	label.modulate = Color(1, 1, 1, 0.7)
	return label


func _add_note(box: VBoxContainer, text: String) -> void:
	box.add_child(_note_label(text))


## Friendly name of a cortical area from its API id (base64, the same key the local cache uses).
func _area_name(cortical_id: String) -> String:
	var area := FeagiCore.feagi_local_cache.cortical_areas.try_to_get_cortical_area_by_ID(StringName(cortical_id))
	if area == null:
		return "(area not loaded)"
	return str(area.friendly_name)


func _build_trigger_section(driver_id: String) -> void:
	var title := Label.new()
	title.text = "Triggered by"
	_trigger_box.add_child(title)
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = _area_name(driver_id) if not driver_id.is_empty() else "(none)"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var area := FeagiCore.feagi_local_cache.cortical_areas.try_to_get_cortical_area_by_ID(StringName(driver_id))
	var show_button := Button.new()
	show_button.text = "Show"
	show_button.disabled = area == null
	show_button.pressed.connect(func() -> void: BV.UI.focus_searched_cortical_area(area))
	row.add_child(show_button)
	_trigger_box.add_child(row)
	_add_note(_trigger_box, "This modulator takes effect when this area fires. Wire your trigger into it.")


func _build_usage_section(instance_id: String) -> void:
	_usage_box.visible = true
	var title := Label.new()
	title.text = "Used by"
	_usage_box.add_child(title)
	_load_usage(instance_id)


func _load_usage(instance_id: String) -> void:
	var response: FeagiRequestOutput = await FeagiCore.requests.get_modulator_usage(instance_id)
	if not is_instance_valid(self):
		return
	if response == null or response.has_errored:
		_add_note(_usage_box, "Could not load usage.")
		return
	var usage := response.decode_response_as_dict()
	var lines: Array[String] = []
	for mapping in usage.get("mappings", []):
		lines.append("Mapping: %s > %s" % [_area_name(str(mapping.get("src", ""))), _area_name(str(mapping.get("dst", "")))])
	for area_id in usage.get("areas", []):
		lines.append("Area: %s" % _area_name(str(area_id)))
	if lines.is_empty():
		_add_note(_usage_box, "Not used yet \u2014 subscribe it from a mapping's Modulators field or an area's Modulations section.")
		return
	for line in lines:
		_usage_box.add_child(_note_label(line))


func _on_graded_toggled(enabled: bool) -> void:
	_full_scale_row.visible = enabled
	_refresh_summary()


## First reason the Strength / Lasts / Full-scale fields cannot be sent, or "" when they are fine.
func _field_error() -> String:
	if _current_magnitude() < -100.0:
		return "Strength must be >= -100%"
	if int(_duration.text) < 1:
		return "Lasts must be at least 1 burst"
	if _graded.button_pressed and float(_full_scale.text) <= 0.0:
		return "Graded modulators require full-scale charge > 0"
	return ""


## Updates the effect sentence, or shows what is missing.
func _refresh_summary() -> void:
	if _summary == null or _type.is_empty():
		return
	var problem := "Name is required" if _instance_id.text.strip_edges().is_empty() else _field_error()
	if not problem.is_empty():
		_summary.text = "[i]Fix first: %s.[/i]" % problem
		return
	_summary.text = _Effect.effect_sentence(_type, _current_magnitude(), int(_duration.text), maxi(0, int(_rest.text)), _graded.button_pressed, float(_full_scale.text))


## Validates the form. Returns the request body, or an empty Dictionary after writing the reason to the status label.
func _build_body() -> Dictionary:
	var problem := _field_error()
	if not problem.is_empty():
		_set_status(problem)
		return {}
	var body := {
		"type": _type,
		"magnitude_percent": _current_magnitude(),
		"effect_duration_bursts": int(_duration.text),
		"rest_bursts": maxi(0, int(_rest.text)),
		"graded": _graded.button_pressed,
	}
	if _graded.button_pressed:
		body["full_scale_potential"] = float(_full_scale.text)
	return body


func _on_create() -> void:
	var new_id := _instance_id.text.strip_edges()
	if new_id.is_empty():
		_set_status("Name is required")
		return
	var body := _build_body()
	if body.is_empty():
		return
	_create_button.disabled = true
	_set_status("Saving..." if _edit_mode else "Adding...")
	var result: FeagiRequestOutput
	if _edit_mode:
		if new_id != _original_id:
			result = await FeagiCore.requests.rename_modulator(_original_id, new_id)
			if result == null or result.has_errored:
				_report_failure(result, "Rename failed")
				return
			_original_id = new_id
		result = await FeagiCore.requests.update_modulator(_original_id, body)
	else:
		result = await FeagiCore.requests.create_modulator(new_id, body)
	if result == null or result.has_errored:
		_report_failure(result, "Save failed" if _edit_mode else "Create failed")
		return
	_create_button.disabled = false
	await FeagiCore.feagi_local_cache.refresh_cortical_areas_from_feagi()
	if not is_instance_valid(self):
		return
	if _edit_mode:
		modulator_updated.emit(new_id)
		close_window()
		return
	var driver_id := await _fetch_driver_id(new_id)
	if not is_instance_valid(self):
		return
	modulator_created.emit(new_id)
	_show_done_step(driver_id, body)


## Driver (trigger) area id FEAGI made for [param instance_id], or "" when it cannot be read.
func _fetch_driver_id(instance_id: String) -> String:
	var response: FeagiRequestOutput = await FeagiCore.requests.list_modulators()
	if response == null or response.has_errored:
		return ""
	var all := response.decode_response_as_dict()
	var definition = all.get(instance_id, {})
	if definition is Dictionary:
		return str((definition as Dictionary).get("driver_cortical_id", ""))
	return ""


func _show_done_step(driver_id: String, body: Dictionary) -> void:
	_done_summary.text = _Effect.effect_sentence(_type, float(body["magnitude_percent"]), int(body["effect_duration_bursts"]), int(body["rest_bursts"]), bool(body["graded"]), float(body.get("full_scale_potential", 1.0)))
	for child in _next_steps_box.get_children():
		_next_steps_box.remove_child(child)
		child.queue_free()
	var area = null
	if not driver_id.is_empty():
		area = FeagiCore.feagi_local_cache.cortical_areas.try_to_get_cortical_area_by_ID(StringName(driver_id))
	if area != null:
		var row := HBoxContainer.new()
		row.name = "WireRow"
		row.add_theme_constant_override("separation", 12)
		var line := _note_label("1. Wire your trigger into %s \u2014 the modulator acts when that area fires." % str(area.friendly_name))
		line.modulate = Color(1, 1, 1, 1)
		line.custom_minimum_size = Vector2(300, 0)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(line)
		var show_button := Button.new()
		show_button.name = "Show"
		show_button.text = "Show"
		show_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		show_button.pressed.connect(func() -> void: BV.UI.focus_searched_cortical_area(area))
		row.add_child(show_button)
		_next_steps_box.add_child(row)
	else:
		var line := _note_label("1. FEAGI created a trigger area for it. Wire your trigger into it \u2014 the modulator acts when that area fires.")
		line.modulate = Color(1, 1, 1, 1)
		_next_steps_box.add_child(line)
	var subscribe := _note_label("2. Subscribe it: open a mapping's Modulators field (mappings) / an area's Modulations section (areas).")
	subscribe.modulate = Color(1, 1, 1, 1)
	_next_steps_box.add_child(subscribe)
	_header.text = HEADER_DONE
	_show_step(Step.DONE)


## Re-enables Save and shows FEAGI's error text, or [param fallback] when it sent none.
func _report_failure(result: FeagiRequestOutput, fallback: String) -> void:
	_create_button.disabled = false
	_set_status(fallback)
	if result != null:
		var detail := result.decode_response_as_string()
		if not detail.is_empty():
			_set_status(detail)
