extends HBoxContainer
class_name MappingEditorModulatorChips
## Compact "Modulators" cell of a mapping row. Shows the subscribed synaptic modulator instance
## ids as removable rounded chips with a type hint inside one framed, input-styled field (chips wrap onto extra
## lines, so the field grows downward; the tooltip lists all). A "+" inside the field's right edge, or a click on the field, opens a
## menu that lists the other synaptic instances known to FEAGI plus a "+ New..." entry that opens the Create Modulator window.

signal subscriptions_changed()

const SYNAPTIC_PREFIX: String = "synaptic."
const TYPE_REWARD: String = "synaptic.reward"
const SYNAPTIC_TYPES: Array[String] = [
	"synaptic.transmission_gain",
	"synaptic.reward",
	"synaptic.learning_rate",
	"synaptic.gate",
]
const _NEW_ENTRY_ID: int = 100000
const _TEX_PLUS_NORMAL: Texture2D = preload("res://BrainVisualizer/UI/GenericResources/ButtonIcons/Plus_S.png")
const _TEX_PLUS_PRESSED: Texture2D = preload("res://BrainVisualizer/UI/GenericResources/ButtonIcons/Plus_C.png")
const _TEX_PLUS_HOVER: Texture2D = preload("res://BrainVisualizer/UI/GenericResources/ButtonIcons/Plus_H.png")
const _TEX_PLUS_DISABLED: Texture2D = preload("res://BrainVisualizer/UI/GenericResources/ButtonIcons/Plus_D.png")
const _PLACEHOLDER_TEXT: String = "Add modulator…"
const _CHIP_HEIGHT: float = 24.0
const _CHIP_GAP: int = 6
const _DOT_COLORS: Dictionary = {
	"reward_plus": Color(0.30, 0.78, 0.40),
	"reward_minus": Color(0.90, 0.32, 0.32),
	"gate": Color(0.35, 0.60, 1.0),
	"transmission_gain": Color(0.65, 0.65, 0.65),
	"learning_rate": Color(0.98, 0.72, 0.20),
}
const _DOT_COLOR_UNKNOWN: Color = Color(0.65, 0.65, 0.65)

var _ids: Array[String] = []
## modulator instance id -> {"type": String, "magnitude_percent": float}. Only synaptic instances.
var _known: Dictionary = {}
var _chips: HFlowContainer
var _chip_labels: Array[Label] = []
var _line_h: float = 32.0
var _inner: MarginContainer
var _add_holder: MarginContainer
var _field: PanelContainer
var _add_button: TextureButton
var _add_menu: PopupMenu
var _fetching: bool = false

func _ready() -> void:
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	custom_minimum_size.y = GenericMappingDetailSettings.scaled_px(GenericMappingDetailSettings.FIELD_HEIGHT_PX)
	# One framed field with the same dark input background as the LineEdit boxes.
	_field = PanelContainer.new()
	_field.name = "Field"
	_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_field.mouse_filter = Control.MOUSE_FILTER_STOP
	_field.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_field.gui_input.connect(_on_field_gui_input)
	var field_style: StyleBox = get_theme_stylebox(&"normal", &"LineEdit")
	if field_style != null:
		field_style = field_style.duplicate()
		field_style.content_margin_left = 8
		field_style.content_margin_right = 4
		field_style.content_margin_top = 2
		field_style.content_margin_bottom = 2
		_field.add_theme_stylebox_override(&"panel", field_style)
	add_child(_field)
	_line_h = custom_minimum_size.y
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	# The flow area reserves the "+" button width on its right for every line; the button floats top-right over that strip.
	_inner = MarginContainer.new()
	_inner.name = "Inner"
	_inner.mouse_filter = Control.MOUSE_FILTER_PASS
	_field.add_child(_inner)
	_chips = HFlowContainer.new()
	_chips.name = "Chips"
	_chips.add_theme_constant_override(&"h_separation", _CHIP_GAP)
	_chips.add_theme_constant_override(&"v_separation", int(GenericMappingDetailSettings.scaled_px(4)))
	_chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chips.mouse_filter = Control.MOUSE_FILTER_PASS
	_inner.add_child(_chips)
	_add_holder = MarginContainer.new()
	_add_holder.name = "AddHolder"
	_add_holder.size_flags_horizontal = Control.SIZE_SHRINK_END
	_add_holder.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_add_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field.add_child(_add_holder)
	_add_button = TextureButton.new()
	_add_button.name = "Add"
	_add_button.theme_type_variation = &"TextureButton_icon"
	_add_button.set_meta(&"skip_scale_applier", true) # sized by apply_field_height, not the theme's icon-button size
	_add_button.custom_minimum_size = Vector2(24, 24)
	_add_button.texture_normal = _TEX_PLUS_NORMAL
	_add_button.texture_pressed = _TEX_PLUS_PRESSED
	_add_button.texture_hover = _TEX_PLUS_HOVER
	_add_button.texture_disabled = _TEX_PLUS_DISABLED
	_add_button.ignore_texture_size = true
	_add_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_add_button.tooltip_text = "Subscribe a synaptic modulator (gain, reward / punishment, learning rate, gate)"
	_add_button.pressed.connect(_open_add_menu)
	_add_holder.add_child(_add_button)
	_field.resized.connect(_update_label_widths)
	_layout_add_button()
	_add_menu = PopupMenu.new()
	_add_menu.name = "AddMenu"
	_add_menu.about_to_popup.connect(_on_menu_about_to_popup)
	_add_menu.id_pressed.connect(_on_menu_id_pressed)
	add_child(_add_menu)
	_rebuild_menu()
	_rebuild_chips()
	refresh_known_modulators()

## Called by the row: one chip line (and so the single-line field) is [param height] tall; the "+" is a small icon
## button pinned to the top-right inside the first line. Extra chip lines grow the field downward.
func apply_field_height(height: float) -> void:
	custom_minimum_size.y = height
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_line_h = height
	if _field == null:
		return
	var style := _field.get_theme_stylebox(&"panel") as StyleBox
	if style != null:
		style.content_margin_top = 0
		style.content_margin_bottom = 0
	_layout_add_button()
	_rebuild_chips()

func _layout_add_button() -> void:
	var icon: float = maxf(_line_h - 8.0, 12.0)
	_add_button.custom_minimum_size = Vector2(icon, icon)
	_add_holder.add_theme_constant_override(&"margin_top", int(roundf((_line_h - icon) * 0.5)))
	_inner.add_theme_constant_override(&"margin_right", int(icon) + 4)

## Max pixel width of a chip's name so the chip (dot, margins, x button) fits one flow line beside the "+" strip.
func _name_max_width() -> float:
	var field_w: float = maxf(_field.size.x, GenericMappingDetailSettings.scaled_px(float(GenericMappingDetailSettings.COLUMN_WIDTHS[5])))
	var style := _field.get_theme_stylebox(&"panel") as StyleBox
	var pad: float = 12.0
	if style != null:
		pad = style.content_margin_left + style.content_margin_right
	var reserved: float = pad + _add_button.custom_minimum_size.x + 4.0 + 56.0
	return maxf(field_w - reserved, 24.0)

func _update_label_widths() -> void:
	var font: Font = get_theme_font(&"font", &"Label")
	var font_size: int = get_theme_font_size(&"font_size", &"Label")
	var max_w: float = _name_max_width()
	for label in _chip_labels:
		if is_instance_valid(label):
			var text_width: float = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			label.custom_minimum_size.x = ceilf(minf(text_width, max_w))

func _on_field_gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event != null and mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
		_open_add_menu()

func _open_add_menu() -> void:
	if _add_menu == null or _field == null:
		return
	var origin: Vector2 = _field.get_screen_position() + Vector2(0, _field.size.y)
	_add_menu.popup(Rect2i(Vector2i(origin), Vector2i.ZERO))

## Replaces the subscribed ids. Does not emit [signal subscriptions_changed].
func set_ids(ids: Array[String]) -> void:
	_ids.clear()
	for id in ids:
		if not id.is_empty() and id not in _ids:
			_ids.append(id)
	if _chips != null:
		_rebuild_chips()
		_rebuild_menu()

func get_ids() -> Array[String]:
	return _ids.duplicate()

func add_id(id: String) -> void:
	if id.is_empty() or id in _ids:
		return
	_ids.append(id)
	_rebuild_chips()
	_rebuild_menu()
	subscriptions_changed.emit()

func remove_id(id: String) -> void:
	if id not in _ids:
		return
	_ids.erase(id)
	_rebuild_chips()
	_rebuild_menu()
	subscriptions_changed.emit()

## True when at least one subscribed id is (or, while its type is unknown, may be) a reward modulator.
## Unknown ids count so a failed modulator listing never blocks a mapping the server would accept.
func has_reward_modulator() -> bool:
	for id in _ids:
		if not _known.has(id):
			return true
		if str(_known[id].get("type", "")) == TYPE_REWARD:
			return true
	return false

## Re-reads the modulator instances from FEAGI and redraws the chips and the menu.
func refresh_known_modulators() -> void:
	if _fetching or not FeagiCore.can_interact_with_feagi():
		return
	_fetching = true
	var response: FeagiRequestOutput = await FeagiCore.requests.list_modulators()
	_fetching = false
	if not is_instance_valid(self) or response == null or response.has_errored:
		return
	var payload: Dictionary = response.decode_response_as_dict()
	_known.clear()
	InterCorticalMappingSet.reward_modulator_magnitudes.clear()
	for instance_id in payload.keys():
		var body: Variant = payload[instance_id]
		if body is Dictionary and str(body.get("type", "")).begins_with(SYNAPTIC_PREFIX):
			_known[str(instance_id)] = {
				"type": str(body.get("type", "")),
				"magnitude_percent": float(body.get("magnitude_percent", 0.0)),
			}
			if str(body.get("type", "")) == TYPE_REWARD:
				InterCorticalMappingSet.reward_modulator_magnitudes[str(instance_id)] = float(body.get("magnitude_percent", 0.0))
	_rebuild_chips()
	_rebuild_menu()
	subscriptions_changed.emit()

## Short label such as "pleasure (reward +)", "pain (reward −)", "door (gate)", "boost (gain)", "lr (eta)".
func describe_id(id: String) -> String:
	if not _known.has(id):
		return id
	var info: Dictionary = _known[id]
	var hint: String = ""
	match str(info.get("type", "")):
		"synaptic.reward":
			hint = "reward −" if float(info.get("magnitude_percent", 0.0)) < 0.0 else "reward +"
		"synaptic.gate":
			hint = "gate"
		"synaptic.transmission_gain":
			hint = "gain"
		"synaptic.learning_rate":
			hint = "eta"
	if hint.is_empty():
		return id
	return "%s (%s)" % [id, hint]

func _rebuild_chips() -> void:
	var all_text: String = "No modulators subscribed"
	if not _ids.is_empty():
		var described: PackedStringArray = []
		for id in _ids:
			described.append(describe_id(id))
		all_text = ", ".join(described)
	_field.tooltip_text = all_text
	for child in _chips.get_children():
		_chips.remove_child(child)
		child.queue_free()
	_chip_labels.clear()
	if _ids.is_empty():
		var placeholder := Label.new()
		placeholder.text = _PLACEHOLDER_TEXT
		placeholder.modulate = Color(1, 1, 1, 0.45)
		placeholder.size_flags_vertical = Control.SIZE_FILL
		placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_chips.add_child(placeholder)
		return
	var chip_style := StyleBoxFlat.new()
	chip_style.bg_color = Color(1, 1, 1, 0.14)
	chip_style.set_corner_radius_all(12)
	chip_style.content_margin_left = 10
	chip_style.content_margin_right = 10
	chip_style.content_margin_top = 0
	chip_style.content_margin_bottom = 0
	var font: Font = get_theme_font(&"font", &"Label")
	var font_size: int = get_theme_font_size(&"font_size", &"Label")
	for id in _ids:
		# Each flow item is one full line tall; the chip is centred inside it like the old single line.
		var chip_h: float = minf(_CHIP_HEIGHT, maxf(_line_h - 8.0, 12.0))
		var slot := MarginContainer.new()
		slot.mouse_filter = Control.MOUSE_FILTER_PASS
		slot.add_theme_constant_override(&"margin_top", int(floorf((_line_h - chip_h) * 0.5)))
		slot.add_theme_constant_override(&"margin_bottom", int(ceilf((_line_h - chip_h) * 0.5)))
		var chip := PanelContainer.new()
		chip.custom_minimum_size = Vector2(0, chip_h)
		chip.size_flags_vertical = Control.SIZE_FILL
		slot.add_child(chip)
		chip.add_theme_stylebox_override(&"panel", chip_style)
		chip.tooltip_text = _describe_tooltip(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", _CHIP_GAP)
		chip.add_child(row)
		var dot := Panel.new()
		var dot_style := StyleBoxFlat.new()
		dot_style.bg_color = _dot_color_for(id)
		dot_style.set_corner_radius_all(4)
		dot.add_theme_stylebox_override(&"panel", dot_style)
		dot.custom_minimum_size = Vector2(8, 8)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(dot)
		var label := Label.new()
		label.text = id
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.custom_minimum_size.x = ceilf(minf(font.get_string_size(id, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x, _name_max_width()))
		_chip_labels.append(label)
		row.add_child(label)
		var remove := Button.new()
		remove.text = "×"
		remove.flat = true
		remove.focus_mode = Control.FOCUS_NONE
		remove.custom_minimum_size = Vector2(16, _CHIP_HEIGHT)
		remove.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for style_name in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
			remove.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
		remove.tooltip_text = "Unsubscribe %s" % id
		remove.pressed.connect(remove_id.bind(id))
		row.add_child(remove)
		_chips.add_child(slot)

## "<name> — <kind> <magnitude_percent>%"; just the name while the instance is not (yet) known.
func _describe_tooltip(id: String) -> String:
	if not _known.has(id):
		return id
	var info: Dictionary = _known[id]
	var kind: String = str(info.get("type", "")).trim_prefix(SYNAPTIC_PREFIX)
	return "%s — %s %s%%" % [id, kind, str(snappedf(float(info.get("magnitude_percent", 0.0)), 0.1))]

func _dot_color_for(id: String) -> Color:
	if not _known.has(id):
		return _DOT_COLOR_UNKNOWN
	var info: Dictionary = _known[id]
	match str(info.get("type", "")):
		"synaptic.reward":
			return _DOT_COLORS["reward_minus"] if float(info.get("magnitude_percent", 0.0)) < 0.0 else _DOT_COLORS["reward_plus"]
		"synaptic.gate":
			return _DOT_COLORS["gate"]
		"synaptic.transmission_gain":
			return _DOT_COLORS["transmission_gain"]
		"synaptic.learning_rate":
			return _DOT_COLORS["learning_rate"]
	return _DOT_COLOR_UNKNOWN

func _rebuild_menu() -> void:
	if _add_menu == null:
		return
	var popup: PopupMenu = _add_menu
	popup.clear()
	var index: int = 0
	for id in _known.keys():
		if id in _ids:
			continue
		popup.add_item(describe_id(id), index)
		popup.set_item_metadata(popup.get_item_index(index), id)
		index += 1
	if popup.item_count > 0:
		popup.add_separator()
	popup.add_item("+ New...", _NEW_ENTRY_ID)

func _on_menu_about_to_popup() -> void:
	_rebuild_menu()
	refresh_known_modulators()

func _on_menu_id_pressed(menu_id: int) -> void:
	if menu_id == _NEW_ENTRY_ID:
		_open_create_window()
		return
	var popup: PopupMenu = _add_menu
	var item_index: int = popup.get_item_index(menu_id)
	if item_index < 0:
		return
	add_id(str(popup.get_item_metadata(item_index)))

func _open_create_window() -> void:
	var window: WindowCreateModulator = BV.WM.spawn_create_modulator(_field, SYNAPTIC_TYPES, TYPE_REWARD)
	if window != null:
		window.modulator_created.connect(_on_modulator_created)

func _on_modulator_created(instance_id: String) -> void:
	add_id(instance_id)
	refresh_known_modulators()
