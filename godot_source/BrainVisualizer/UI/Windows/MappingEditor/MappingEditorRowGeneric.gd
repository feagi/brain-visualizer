extends VBoxContainer
class_name MappingEditorRowGeneric
## Single editable row of an inter-cortical mapping rule. Owns the Plasticity Mode dropdown
## (Off / STDP / R-STDP) and the Modulators cell on a fixed single-line [code]MainRow[/code]. While a
## learning mode is active, a [code]SubRow[/code] beneath it holds window, constant, LTP, LTD,
## eligibility decay (R-STDP) and the reward-modulator warning. Source-driven effects (gate, reward, punishment, gain,
## learning rate) are modulator subscriptions, not per-rule source areas. R-STDP needs at least
## one synaptic.reward modulator; [method get_validation_error] reports when it is missing.

## Emitted when the learning sub-row is shown or hidden so the list can refit its height.
signal sub_row_visibility_changed()

# Indices match the OptionButton items in MappingEditorRowGeneric.tscn.
const _MODE_OFF: int = 0
const _MODE_STDP: int = 1
const _MODE_RSTDP: int = 2

# Mapping between dropdown indices and the FEAGI string enum used by the genome.
const _MODE_INDEX_TO_STRING: Array[String] = ["off", "stdp", "rstdp"]

var _restrictions: MappingRestrictionCorticalMorphology
var _defaults: MappingRestrictionDefault

var _morphologies: MorphologyDropDown
var _scalar: Vector3iField
var _PSP: FloatInput
var _synaptic_delay: IntInput
var _inhibitory: ToggleButton
var _plasticity_mode: OptionButton  # Off / STDP / R-STDP
var _modulators: MappingEditorModulatorChips
var _main_row: HBoxContainer
var _sub_row: HBoxContainer
var _eligibility_group: HBoxContainer
var _warning: Label
var _plasticity_window: IntInput
var _plasticity_constant: FloatInput
var _LTP_multiplier: FloatInput
var _LTD_multiplier: FloatInput
var _eligibility_decay: IntInput
var _edit: TextureButton
var _sub_row_top_gap: Control
var _sub_row_bottom_gap: Control
var _eligibility_gap: Control

func _ready() -> void:
	_main_row = $MainRow
	_sub_row = $SubRow
	_morphologies = $MainRow/MappingDefinitionGroup/Morphology_List
	_scalar = $MainRow/Scalar
	_PSP = $MainRow/PSP
	_synaptic_delay = $MainRow/Synaptic_Delay
	_inhibitory = $MainRow/InhibitoryCell/Inhibitory
	_modulators = $MainRow/Modulators
	_plasticity_mode = $MainRow/Plasticity_Mode
	_plasticity_window = $SubRow/Panel/Fields/Plasticity_Window
	_plasticity_constant = $SubRow/Panel/Fields/Plasticity_Constant
	_LTP_multiplier = $SubRow/Panel/Fields/LTP_Multiplier
	_LTD_multiplier = $SubRow/Panel/Fields/LTD_Multiplier
	_eligibility_group = $SubRow/Panel/Fields/EligibilityGroup
	_eligibility_decay = $SubRow/Panel/Fields/EligibilityGroup/Eligibility_Decay_Bursts
	_warning = $SubRow/Panel/Fields/Warning
	_edit = $MainRow/MappingDefinitionGroup/edit
	_apply_column_layout()
	if BV and BV.UI and not BV.UI.theme_changed.is_connected(_on_ui_theme_changed):
		BV.UI.theme_changed.connect(_on_ui_theme_changed)
	_style_sub_row()
	_build_sub_row_spacing()
	_modulators.subscriptions_changed.connect(_refresh_reward_warning)

	# Populate the plasticity-mode dropdown. We do this in code (rather than in the .tscn)
	# to match the convention used by the rest of the editor, where OptionButtons are
	# filled at runtime via add_item().
	if _plasticity_mode.item_count == 0:
		_plasticity_mode.add_item("Off", _MODE_OFF)
		_plasticity_mode.add_item("STDP", _MODE_STDP)
		_plasticity_mode.add_item("R-STDP", _MODE_RSTDP)
	_select_plasticity_mode(_MODE_OFF)

	_morphologies.user_selected_morphology.connect(_on_morphology_selected)

## Sizes every MainRow cell from [constant GenericMappingDetailSettings.COLUMN_WIDTHS] x the current UI scale (same
## table and scale the header uses). Every control is the natural LineEdit height (what the scalar/PSP inputs get from
## the theme), vertically centred. Cells opt out of [ScaleThemeApplier] (meta) because the applier would otherwise
## overwrite their size with the theme's big icon-button size whenever any row is added to the list.
func _apply_column_layout() -> void:
	var s: float = GenericMappingDetailSettings.ui_scale()
	var field_h: float = maxf(_PSP.get_minimum_size().y, 1.0)
	if field_h <= 1.0:
		field_h = GenericMappingDetailSettings.scaled_px(GenericMappingDetailSettings.FIELD_HEIGHT_PX)
	_main_row.add_theme_constant_override(&"separation", int(GenericMappingDetailSettings.scaled_px(GenericMappingDetailSettings.COLUMN_GAP_PX)))
	var widths: Array[int] = GenericMappingDetailSettings.COLUMN_WIDTHS
	var cells: Array[Node] = _main_row.get_children()
	for i in mini(cells.size(), widths.size()):
		var cell: Control = cells[i] as Control
		if cell == null:
			continue
		var is_text_input: bool = cell is LineEdit
		cell.custom_minimum_size = Vector2(GenericMappingDetailSettings.scaled_px(widths[i]), 0.0 if is_text_input else field_h)
		if i == GenericMappingDetailSettings.COLUMN_EXPANDING_INDEX:
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			cell.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		cell.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	# Mapping cell: dropdown (240) + 4px gap + edit button (square, field height) = column width.
	$MainRow/MappingDefinitionGroup.add_theme_constant_override(&"separation", int(GenericMappingDetailSettings.scaled_px(4)))
	_morphologies.custom_minimum_size = Vector2(GenericMappingDetailSettings.scaled_px(240), field_h)
	_morphologies.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_morphologies.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_morphologies.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	for style_name in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
		var base: StyleBox = _morphologies.get_theme_stylebox(style_name)
		if base != null:
			var padded: StyleBox = base.duplicate()
			padded.content_margin_left = 8
			_morphologies.add_theme_stylebox_override(style_name, padded)
	for icon_button in [_edit, $MainRow/remove]:
		var icon_btn := icon_button as TextureButton
		icon_btn.set_meta(&"skip_scale_applier", true)
		icon_btn.custom_minimum_size = Vector2(field_h, field_h)
		icon_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		icon_btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	# Scalar: three 56px boxes, 4px apart (no hidden-label gaps).
	_scalar.custom_minimum_size = Vector2(GenericMappingDetailSettings.scaled_px(widths[1]), 0.0)
	_scalar.add_theme_constant_override(&"separation", int(GenericMappingDetailSettings.scaled_px(4)))
	for sub in ["HBoxContainer", "HBoxContainer2", "HBoxContainer3"]:
		_scalar.get_node(sub).add_theme_constant_override(&"separation", 0)
	for box in [_scalar.get_node("HBoxContainer/IntX"), _scalar.get_node("HBoxContainer2/IntY"), _scalar.get_node("HBoxContainer3/IntZ")]:
		(box as Control).custom_minimum_size = Vector2(GenericMappingDetailSettings.scaled_px(56), 0.0)
	# Inhibitory toggle: left edge of its cell, vertically centred.
	$MainRow/InhibitoryCell.custom_minimum_size = Vector2(GenericMappingDetailSettings.scaled_px(widths[4]), field_h)
	_inhibitory.set_anchor(SIDE_LEFT, 0.0)
	_inhibitory.set_anchor(SIDE_RIGHT, 0.0)
	_inhibitory.set_anchor(SIDE_TOP, 0.5)
	_inhibitory.set_anchor(SIDE_BOTTOM, 0.5)
	_inhibitory.offset_left = 0.0
	_inhibitory.offset_right = 0.0
	_inhibitory.offset_top = 0.0
	_inhibitory.offset_bottom = 0.0
	_inhibitory.grow_horizontal = Control.GROW_DIRECTION_END
	_inhibitory.grow_vertical = Control.GROW_DIRECTION_BOTH
	# Plasticity sub-row starts under the PSP column.
	var indent: float = 0.0
	for i in 2:
		indent += GenericMappingDetailSettings.scaled_px(widths[i] + GenericMappingDetailSettings.COLUMN_GAP_PX)
	$SubRow/Indent.custom_minimum_size = Vector2(indent, 0)
	if _modulators != null:
		_modulators.apply_field_height(field_h)

func _on_ui_theme_changed(_new_theme: Theme = null) -> void:
	call_deferred("_apply_column_layout")

## 4px above and 12px below the learning sub-row, 6px label-to-field and 16px pair-to-pair gaps inside it.
func _build_sub_row_spacing() -> void:
	const FIELD_HEIGHT: float = GenericMappingDetailSettings.FIELD_HEIGHT_PX
	_sub_row_top_gap = Control.new()
	_sub_row_top_gap.name = "SubRowTopGap"
	_sub_row_top_gap.custom_minimum_size = Vector2(0, 4)
	_sub_row_top_gap.visible = false
	add_child(_sub_row_top_gap)
	move_child(_sub_row_top_gap, _sub_row.get_index())
	_sub_row_bottom_gap = Control.new()
	_sub_row_bottom_gap.name = "SubRowBottomGap"
	_sub_row_bottom_gap.custom_minimum_size = Vector2(0, 12)
	_sub_row_bottom_gap.visible = false
	add_child(_sub_row_bottom_gap)
	var fields: HBoxContainer = $SubRow/Panel/Fields
	fields.add_theme_constant_override(&"separation", 6)
	$SubRow/Panel/Fields/EligibilityGroup.add_theme_constant_override(&"separation", 6)
	for field in [_plasticity_window, _plasticity_constant, _LTP_multiplier, _LTD_multiplier, _eligibility_decay]:
		(field as Control).custom_minimum_size.y = FIELD_HEIGHT
	# Spacer of 4px + two 6px separations = 16px between a field and the next label.
	for next_name in ["Label_Constant", "Label_LTP", "Label_LTD", "EligibilityGroup"]:
		var next_node: Control = fields.get_node(next_name)
		var gap := Control.new()
		gap.name = "Gap_" + next_name
		gap.custom_minimum_size = Vector2(4, 0)
		fields.add_child(gap)
		fields.move_child(gap, next_node.get_index())
		if next_name == "EligibilityGroup":
			_eligibility_gap = gap

## Row of the editable columns that the table header aligns to (the sub-row is excluded).
func get_main_row() -> HBoxContainer:
	return _main_row

## Subtle tinted panel with a left accent border so the sub-row reads as part of the row above.
func _style_sub_row() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.04)
	style.border_color = Color(0.45, 0.65, 1.0, 0.7)
	style.border_width_left = 2
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	$SubRow/Panel.add_theme_stylebox_override("panel", style)

func load_settings(restrictions: MappingRestrictionCorticalMorphology, defaults: MappingRestrictionDefault) -> void:
	_restrictions = restrictions
	_defaults = defaults

	if restrictions != null:
		if restrictions.has_restricted_morphologies():
			_morphologies.overwrite_morphologies(restrictions.get_morphologies_restricted_to())
		if restrictions.has_disallowed_morphologies():
			for disallowed in restrictions.get_morphologies_disallowed():
				_morphologies.remove_morphology(disallowed)
		_scalar.editable = restrictions.allow_changing_scalar
		_PSP.editable = restrictions.allow_changing_PSP
		_synaptic_delay.editable = restrictions.allow_changing_PSP
		_inhibitory.disabled = !restrictions.allow_changing_inhibitory
		_plasticity_mode.disabled = !restrictions.allow_changing_plasticity
	else:
		_scalar.editable = true
		_PSP.editable = true
		_synaptic_delay.editable = true
		_inhibitory.disabled = false
		_plasticity_mode.disabled = false

	if defaults != null:
		_morphologies.set_selected_morphology(defaults.try_get_default_morphology())

	# Normal mappings default to Off. Associative-memory mappings require STDP or R-STDP.
	_select_plasticity_mode(_MODE_OFF)
	_apply_associative_plasticity_mode(_morphologies.get_selected_morphology())
	_apply_mode_field_state(_get_selected_plasticity_mode())
	_refresh_morphology_tooltip()

func load_mapping(mapping: SingleMappingDefinition) -> void:
	_morphologies.set_selected_morphology(mapping.morphology_used)
	_scalar.current_vector = mapping.scalar
	_PSP.current_float = absf(mapping.post_synaptic_current_multiplier)
	_synaptic_delay.current_int = mapping.synaptic_delay_bursts
	_inhibitory.set_toggle_no_signal(mapping.post_synaptic_current_multiplier < 0)

	var mode_index: int = _resolve_mode_index_from_mapping(mapping)
	_select_plasticity_mode(mode_index)

	_plasticity_window.current_int = mapping.plasticity_window
	_plasticity_constant.current_float = mapping.plasticity_constant
	_LTP_multiplier.current_float = mapping.LTP_multiplier
	_LTD_multiplier.current_float = mapping.LTD_multiplier
	_eligibility_decay.current_int = mapping.eligibility_decay_bursts
	_modulators.set_ids(mapping.modulator_ids)

	_apply_associative_plasticity_mode(mapping.morphology_used)
	_apply_mode_field_state(_get_selected_plasticity_mode())
	_refresh_morphology_tooltip()

func export_mapping() -> SingleMappingDefinition:
	var morphology_used: BaseMorphology = _morphologies.get_selected_morphology()
	var scalar: Vector3i = _scalar.current_vector
	var PSP: float = _PSP.current_float
	if _inhibitory.button_pressed:
		PSP = -PSP

	var mode_index: int = _get_selected_plasticity_mode()
	# associative_memory always requires a plastic mode. Preserve the user's explicit choice
	# between STDP and R-STDP, while treating an Off selection as STDP.
	if _is_associative_memory_morphology(morphology_used) and mode_index == _MODE_OFF:
		mode_index = _MODE_STDP

	var is_plastic: bool = mode_index != _MODE_OFF
	var plasticity_constant: float = _plasticity_constant.current_float
	var plasticity_window: int = _plasticity_window.current_int
	var LTP_multiplier: float = _LTP_multiplier.current_float
	var LTD_multiplier: float = _LTD_multiplier.current_float
	var delay_bursts: int = maxi(1, _synaptic_delay.current_int)

	# R-STDP-only fields. We only forward them when mode == R-STDP so STDP and Off rules
	# remain wire-compatible with consumers that have not learned about plasticity_mode yet.
	var mode_string: String = ""
	var eligibility_decay_bursts: int = 0
	if mode_index == _MODE_RSTDP:
		mode_string = _MODE_INDEX_TO_STRING[_MODE_RSTDP]
		eligibility_decay_bursts = maxi(0, _eligibility_decay.current_int)
	elif mode_index == _MODE_STDP:
		# Emit the explicit "stdp" string when the user picks STDP from the dropdown so the
		# genome round-trips a value the user can recognize. Off intentionally leaves the
		# field empty so legacy consumers continue to read plasticity_flag=false.
		mode_string = _MODE_INDEX_TO_STRING[_MODE_STDP]

	var mapping := SingleMappingDefinition.new(
		morphology_used,
		scalar,
		PSP,
		is_plastic,
		plasticity_constant,
		LTP_multiplier,
		LTD_multiplier,
		plasticity_window,
		delay_bursts,
		mode_string,
		eligibility_decay_bursts,
	)
	mapping.set_modulator_ids(_modulators.get_ids())
	return mapping

## Returns a user-facing message when this row cannot be sent to FEAGI, or "" when it is fine.
func get_validation_error() -> String:
	if _is_reward_modulator_missing():
		return "R-STDP needs a reward modulator. Subscribe a synaptic.reward modulator in the Modulators column, or switch Plasticity Mode to STDP."
	return ""

func _on_user_PSP(_value: float) -> void:
	# FloatInput updates its internal value on validation; this exists to satisfy the
	# scene-level signal connection.
	pass

## OptionButton.item_selected handler. Toggles edit-state of plasticity-related fields
## according to the new mode selection.
func _on_user_select_plasticity_mode(mode_index: int) -> void:
	var mode: int = _plasticity_mode.get_item_id(mode_index)
	_apply_mode_field_state(mode)

## Full morphology name on hover (the dropdown ellipsizes names longer than its 240px).
func _refresh_morphology_tooltip() -> void:
	_morphologies.tooltip_text = _morphologies.text

func _on_morphology_selected(morphology: BaseMorphology) -> void:
	_refresh_morphology_tooltip()
	_apply_associative_plasticity_mode(morphology)
	_apply_mode_field_state(_get_selected_plasticity_mode())

## Keeps associative-memory mappings plastic without constraining STDP versus R-STDP.
func _apply_associative_plasticity_mode(morphology: BaseMorphology) -> void:
	if _is_associative_memory_morphology(morphology):
		_set_off_mode_visible(false)
		if _get_selected_plasticity_mode() == _MODE_OFF:
			_select_plasticity_mode(_MODE_STDP)
		if _restrictions:
			_plasticity_mode.disabled = !_restrictions.allow_changing_plasticity
		else:
			_plasticity_mode.disabled = false
	else:
		_set_off_mode_visible(true)
		if _restrictions:
			_plasticity_mode.disabled = !_restrictions.allow_changing_plasticity
		else:
			_plasticity_mode.disabled = false

func _is_associative_memory_morphology(morphology: BaseMorphology) -> bool:
	return morphology != null and morphology.name == &"associative_memory"

## Keeps Off available for normal mappings but removes it from associative-memory choices.
func _set_off_mode_visible(visible: bool) -> void:
	var selected_mode: int = _get_selected_plasticity_mode()
	if not visible and selected_mode == _MODE_OFF:
		selected_mode = _MODE_STDP
	_plasticity_mode.clear()
	if visible:
		_plasticity_mode.add_item("Off", _MODE_OFF)
	_plasticity_mode.add_item("STDP", _MODE_STDP)
	_plasticity_mode.add_item("R-STDP", _MODE_RSTDP)
	_select_plasticity_mode(selected_mode)

## Returns the stable mode ID, which differs from the option index when Off is omitted.
func _get_selected_plasticity_mode() -> int:
	return _plasticity_mode.get_selected_id()

## Selects a plasticity mode by its stable item ID.
func _select_plasticity_mode(mode: int) -> void:
	for item_index in _plasticity_mode.item_count:
		if _plasticity_mode.get_item_id(item_index) == mode:
			_plasticity_mode.select(item_index)
			return

## Centralised editability rules for plasticity-related fields, keyed off the dropdown
## selection. Honors mapping restrictions when present.
func _apply_mode_field_state(mode_index: int) -> void:
	var stdp_active: bool = mode_index != _MODE_OFF
	var rstdp_active: bool = mode_index == _MODE_RSTDP

	var allow_constants: bool = true
	if _restrictions:
		allow_constants = _restrictions.allow_changing_plasticity_constant

	# STDP knobs are usable for both STDP and R-STDP.
	_plasticity_window.editable = stdp_active and allow_constants
	_plasticity_constant.editable = stdp_active and allow_constants
	_LTP_multiplier.editable = stdp_active and allow_constants
	_LTD_multiplier.editable = stdp_active and allow_constants

	# R-STDP-only knobs.
	_eligibility_decay.editable = rstdp_active and allow_constants

	# Sub-row: shown for STDP / R-STDP (associative_memory is always plastic, so it always shows).
	# Eligibility decay only applies to R-STDP.
	var sub_row_visible: bool = stdp_active
	var visibility_changed: bool = _sub_row.visible != sub_row_visible
	_sub_row.visible = sub_row_visible
	if _sub_row_top_gap != null:
		_sub_row_top_gap.visible = sub_row_visible
		_sub_row_bottom_gap.visible = sub_row_visible
	if _eligibility_gap != null:
		_eligibility_gap.visible = rstdp_active
	_eligibility_group.visible = rstdp_active
	_refresh_reward_warning()
	if visibility_changed:
		sub_row_visibility_changed.emit()

## True when the learning sub-row is currently shown under this row.
func is_sub_row_visible() -> bool:
	return _sub_row != null and _sub_row.visible

func _is_reward_modulator_missing() -> bool:
	return _get_selected_plasticity_mode() == _MODE_RSTDP and not _modulators.has_reward_modulator()

## Single-line warning at the end of the sub-row while R-STDP has no reward modulator.
## Clipped with an ellipsis; the tooltip carries the full text.
func _refresh_reward_warning() -> void:
	if _warning == null:
		return
	if _is_reward_modulator_missing():
		_warning.text = "R-STDP needs a reward modulator (synaptic.reward)."
		_warning.tooltip_text = "R-STDP needs a reward modulator (synaptic.reward). Subscribe one in the Modulators column, or switch Plasticity Mode to STDP."
	else:
		_warning.text = ""
		_warning.tooltip_text = ""

## Picks the dropdown index for the mapping. Priority:
##   1. explicit plasticity_mode string (off / stdp / rstdp)
##   2. a subscribed modulator (treated as R-STDP)
##   3. legacy plasticity_flag (true => STDP, false => Off)
func _resolve_mode_index_from_mapping(mapping: SingleMappingDefinition) -> int:
	var explicit_mode: String = mapping.plasticity_mode.to_lower()
	if explicit_mode == "rstdp":
		return _MODE_RSTDP
	if explicit_mode == "stdp":
		return _MODE_STDP
	if explicit_mode == "off":
		return _MODE_OFF
	if mapping.is_plastic:
		return _MODE_STDP
	return _MODE_OFF

func _on_edit_pressed() -> void:
	var morphology: BaseMorphology = _morphologies.get_selected_morphology()
	if morphology != null:
		BV.WM.spawn_manager_morphology(morphology)

func _on_mapping_delete_press() -> void:
	get_parent().delete_this()
