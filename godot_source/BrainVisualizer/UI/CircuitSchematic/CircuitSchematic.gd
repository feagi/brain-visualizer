extends GraphEdit
class_name CircuitSchematic
## Read-only view of the whole genome in one scene. Every brain region is a box around its contents:
## the root is open, its regions start as closed blocks, and double-clicking a block opens it in place
## (the header of an open frame closes it again); Show all and Hide all open or close every region at
## once. Hovering a cortical area box dims everything not related to it: the areas upstream that reach it
## and downstream that it reaches through any chain of mappings, and only the mappings on those chains
## (see [SchematicReachability]); the mouse leaving restores everything. Region frames never dim, and the
## export never shows the dimming. The Filter box at the top left matches cortical areas and regions by
## name (case-insensitive substring): matches stay lit, the rest dims, the regions holding a match open
## and the view fits the matches; clearing it restores the earlier open state and the whole-genome fit.
## Show all also covers regions created later, until Hide all. Shift-clicking an area or region shows it in the Brain
## Monitor, as global search does when it is selected (UIManager.focus_searched_object), and the Export menu saves the whole view as PNG, JPG or PDF. Mappings are merged
## into one line per pair of visible ends, with a count when more than one mapping is merged. Editing
## stays in Circuit Builder.
## See docs/CIRCUIT_SCHEMATIC_VIEW_DESIGN.md.

const TAB_TITLE: StringName = &"Circuit Schematic"
const REBUILD_DELAY_S: float = 0.3
const FIT_MARGIN: float = 0.9
const MAX_ZOOM: float = 2.0
const COMBO_STYLER = preload("res://BrainVisualizer/UI/GenericElements/Buttons/ComboButtonStripStyler.gd")
const ICON_EXPORT_MENU: Texture2D = preload("res://BrainVisualizer/UI/GenericResources/ButtonIcons/Triangle_Down_S.png")
## Plate colors match the tab strips (BrainObjectsCombo ICON_BUTTON_PLATE_COLOR).
const MENU_PLATE_COLORS: Dictionary = {
	"normal": Color8(67, 67, 67),
	"hover": Color8(84, 84, 84),
	"pressed": Color8(48, 48, 48),
	"hover_pressed": Color8(48, 48, 48),
	"disabled": Color8(52, 52, 52),
}
const MENU_TEXT_COLOR: Color = Color8(220, 220, 220)
const MENU_TEXT_COLOR_DISABLED: Color = Color8(130, 130, 130)
const MENU_INSET: float = 8.0
## Export is a menu; Show all and Hide all are a pair. The wider gap separates the two.
const MENU_GROUP_GAP: float = 8.0
const MENU_GROUP_GAP_NAME: StringName = &"GroupGap"
const MENU_FALLBACK_HEIGHT: float = 28.0
const FILTER_MIN_WIDTH: float = 220.0  ## Floor; the real width is measured from the placeholder in _style_menu.
const FILTER_WIDTH_PAD: float = 8.0
const FILTER_DEBOUNCE_S: float = 0.15
const FILTER_FIT_PAD: float = 64.0
const FILTER_FOCUS_COLOR: Color = Color8(120, 160, 220)
const FILTER_ERROR_COLOR: Color = Color8(235, 95, 95)
const FILTER_PLACEHOLDER_COLOR: Color = Color8(140, 140, 140)
const FILTER_TOOLTIP: String = "Type part of a cortical area or circuit name: matches stay lit, the rest dims, and regions holding a match open. Clear to restore."
const MENU_GAP_META: StringName = &"schematic_menu_gap"
## Triangle icons have built-in padding, so they need more than the plus-icon share of the height.
const MENU_ICON_SCALE: float = 0.6

var model: SchematicModel:
	get: return _model

## Set before adding to the tree: a still copy for [SchematicExporter], with no menu, minimap, grid,
## fitting or live updates.
var export_mode: bool = false

var _model: SchematicModel
var _open: PackedByteArray = []
var _boxes: Dictionary = {} ## item index -> SchematicBox
var _order: Array = [] ## child order: open frames, the line layer, then the other boxes
var _edge_layer: SchematicEdgeLayer
var _rebuild_timer: Timer
var _fit_pending: bool = true
var _reachability: SchematicReachability
var _item_of_area: Dictionary = {} ## AbstractCorticalArea -> item index
## The area box under the mouse. Held as the object, not an index, so it survives rebuilds.
var _hovered_area: AbstractCorticalArea
## Show all stays on until Hide all, so regions created later open too.
var _show_all_mode: bool = false
var _known_region_ids: Dictionary = {} ## region_ID -> true for the regions of the current model
## Name filter. The query is stored, never item indices, so it survives rebuilds.
var _filter_edit: LineEdit
var _filter_timer: Timer
var _filter_query: String = ""
var _filter_matches: Array[int] = []
var _filter_items: Dictionary = {} ## item index -> true: a match or anything inside a matching region
var _pre_filter_open: Dictionary = {} ## open_region_ids() from before the query became active
var _fit_target: Rect2 = Rect2() ## zero size = the whole canvas
var _fit_generation: int = 0


func _ready() -> void:
	name = TAB_TITLE
	minimap_enabled = not export_mode
	# The top-left menu holds only the Export, Show all and Hide all buttons.
	show_zoom_label = false
	show_zoom_buttons = false
	show_grid_buttons = false
	show_minimap_button = false
	show_arrange_button = false
	_edge_layer = SchematicEdgeLayer.new()
	add_child(_edge_layer)
	if export_mode:
		show_menu = false
		show_grid = false
		_fit_pending = false
		rebuild()
		return
	_add_export_menu()
	_add_open_all_buttons()
	_add_filter_box()
	_style_menu()
	AreaTypeLegend.add_to(self, SchematicTreeBuilder.CLASSIFIER_COLOR, true)
	if BV.UI != null:
		BV.UI.theme_changed.connect(_style_menu.unbind(1))
	_rebuild_timer = Timer.new()
	_rebuild_timer.one_shot = true
	_rebuild_timer.wait_time = REBUILD_DELAY_S
	_rebuild_timer.timeout.connect(rebuild)
	add_child(_rebuild_timer)
	# The tab can be created inside a hidden panel; fit once it is shown at its real size.
	resized.connect(_try_fit)
	visibility_changed.connect(_try_fit.call_deferred)
	_connect_cache_signals()
	rebuild()


## Rebuilds the model from the cache, keeping open regions that still exist.
func rebuild() -> void:
	var open_ids: Dictionary = open_region_ids()
	var first_build: bool = _model == null
	_model = SchematicTreeBuilder.build_from_cache()
	if _model == null:
		_model = SchematicModel.new()
		_model.finish()
	for box: SchematicBox in _boxes.values():
		remove_child(box)
		box.queue_free()
	_boxes.clear()
	_hovered_area = null
	_reachability = SchematicReachability.new(_model)
	_item_of_area.clear()
	var region_ids: Dictionary = {}
	for i in _model.items.size():
		var object: Object = _model.items[i]["object"]
		if object is AbstractCorticalArea:
			_item_of_area[object] = i
		elif object is BrainRegion and i > 0 and not _model.items[i]["closed_only"]:
			var region_id: Variant = (object as BrainRegion).region_ID
			region_ids[region_id] = true
			if _show_all_mode and not _known_region_ids.has(region_id):
				open_ids[region_id] = true
				if not _filter_query.is_empty():
					_pre_filter_open[region_id] = true
	_known_region_ids = region_ids
	# Rebuilds only refresh the matches and the dimming; they never re-open regions or re-fit.
	_recompute_filter()
	set_open_region_ids(open_ids)
	if first_build and not export_mode:
		request_initial_fit()


## region_ID -> true for every region open right now.
func open_region_ids() -> Dictionary:
	var ids: Dictionary = {}
	if _model == null:
		return ids
	for i in _model.items.size():
		if _open[i] == 1 and _model.items[i]["object"] is BrainRegion:
			ids[(_model.items[i]["object"] as BrainRegion).region_ID] = true
	return ids


## Opens exactly the given regions (plus the root, which is always open).
func set_open_region_ids(ids: Dictionary) -> void:
	_open = _model.default_open_mask()
	for i in _model.items.size():
		var object: Object = _model.items[i]["object"]
		if object is BrainRegion and ids.has((object as BrainRegion).region_ID):
			_open[i] = 1
	_sync_nodes()


## Fits the whole genome once this view has a size.
func request_initial_fit() -> void:
	_fit_pending = true
	_fit_target = Rect2()
	_fit_generation += 1
	_try_fit()


func set_region_open(item_index: int, is_open: bool) -> void:
	if item_index <= 0 or not _model.is_region(item_index) or _model.items[item_index]["closed_only"]:
		return
	if (_open[item_index] == 1) == is_open:
		return
	_open[item_index] = 1 if is_open else 0
	_sync_nodes()


## Opens every region that can be opened, or closes all but the root.
func set_all_regions_open(is_open: bool) -> void:
	_show_all_mode = is_open
	if is_open:
		_open.resize(_model.items.size())
		for i in _model.items.size():
			_open[i] = 1 if _model.is_region(i) and not _model.items[i]["closed_only"] else 0
		if not _model.items.is_empty():
			_open[0] = 1
	else:
		_open = _model.default_open_mask()
	_sync_nodes()


## Brings the live boxes in line with the open state: one box per visible item, frames for open
## regions, blocks for closed ones; then orders frames, the line layer, then everything else.
func _sync_nodes() -> void:
	var visible: Array[int] = _model.visible_items(_open)
	var grouped: Dictionary = _model.group_lines(_open)
	var wanted: Dictionary = {}
	for index in visible:
		wanted[index] = _look_for(index)
	for index in _boxes.keys():
		var box: SchematicBox = _boxes[index]
		if not wanted.has(index) or box.look != wanted[index]:
			remove_child(box)
			box.queue_free()
			_boxes.erase(index)
	for index in visible:
		if _boxes.has(index):
			continue
		var box: SchematicBox = SchematicBox.new()
		box.setup(index, _model.items[index], wanted[index], int(grouped.inside.get(index, 0)))
		add_child(box)
		# GraphEdit raises a pressed box to the front, which would put a frame over its own contents.
		box.raise_request.connect(_restore_order, CONNECT_DEFERRED)
		box.double_clicked.connect(_on_box_double_clicked)
		box.shift_clicked.connect(_on_box_shift_clicked)
		if not export_mode:
			box.hovered.connect(_on_box_hovered)
			box.unhovered.connect(_on_box_unhovered)
		_boxes[index] = box
	_order.clear()
	for index in visible:
		if wanted[index] == SchematicBox.LOOK.FRAME:
			_order.append(_boxes[index])
	_order.append(_edge_layer)
	for index in visible:
		if wanted[index] != SchematicBox.LOOK.FRAME:
			_order.append(_boxes[index])
	_restore_order()
	_edge_layer.set_lines(_model, grouped.lines)
	_apply_highlight(grouped.lines)


func _on_box_hovered(item_index: int) -> void:
	var object: Object = _model.items[item_index]["object"]
	if not object is AbstractCorticalArea:
		return
	_hovered_area = object as AbstractCorticalArea
	_apply_highlight(_model.group_lines(_open).lines)


func _on_box_unhovered(item_index: int) -> void:
	if _hovered_area == null or _item_of_area.get(_hovered_area, -1) != item_index:
		return
	_hovered_area = null
	_apply_highlight(_model.group_lines(_open).lines)


## Dims every box and line not related to the hovered area, or lights everything when none is hovered.
## A box is lit when the item it shows (an item, or the closed region or classifier that stands for it)
## is related. Open frames are never dimmed. [param lines] is from [method SchematicModel.group_lines].
func _apply_highlight(lines: Array) -> void:
	var hovered_item: int = _item_of_area.get(_hovered_area, -1) if _hovered_area != null else -1
	if hovered_item == -1 or not _boxes.has(hovered_item):
		_hovered_area = null
		if _filter_items.is_empty():
			for box: SchematicBox in _boxes.values():
				box.set_lit(true)
			_edge_layer.set_highlight(null)
		else:
			_apply_filter_highlight(lines)
		return
	var related: Dictionary = _reachability.related_to(hovered_item)
	var lit_ends: Dictionary = {}
	for item: int in related.items:
		lit_ends[_model.visible_end(item, _open)] = true
	for index: int in _boxes:
		(_boxes[index] as SchematicBox).set_lit(lit_ends.has(index))
	var lit_lines: PackedByteArray = PackedByteArray()
	lit_lines.resize(lines.size())
	for i in lines.size():
		for mapping_index: int in lines[i][6]:
			if related.mappings.has(mapping_index):
				lit_lines[i] = 1
				break
	_edge_layer.set_highlight(lit_lines)


## The filter's lit state: a box is lit when it is where some in-filter item shows (the item itself, or
## the closed region holding it); a line is lit when a mapping it merges has both ends in the filter.
func _apply_filter_highlight(lines: Array) -> void:
	var lit_ends: Dictionary = {}
	for item: int in _filter_items:
		lit_ends[_model.visible_end(item, _open)] = true
	for index: int in _boxes:
		(_boxes[index] as SchematicBox).set_lit(lit_ends.has(index))
	var lit_lines: PackedByteArray = PackedByteArray()
	lit_lines.resize(lines.size())
	for i in lines.size():
		for mapping_index: int in lines[i][6]:
			var mapping: PackedInt32Array = _model.mappings[mapping_index]
			if _filter_items.has(mapping[0]) and _filter_items.has(mapping[1]):
				lit_lines[i] = 1
				break
	_edge_layer.set_highlight(lit_lines)


## Open frames first (parents before children), then the line layer, then every other box.
func _restore_order() -> void:
	for i in _order.size():
		if is_instance_valid(_order[i]) and _order[i].get_parent() == self:
			move_child(_order[i], i)


func _look_for(index: int) -> SchematicBox.LOOK:
	if not _model.is_region(index):
		return SchematicBox.LOOK.LEAF
	return SchematicBox.LOOK.FRAME if _open[index] == 1 else SchematicBox.LOOK.BLOCK


func _on_box_double_clicked(item_index: int) -> void:
	if not _model.is_region(item_index):
		return
	if _model.items[item_index]["closed_only"]:
		if BV.NOTIF != null:
			BV.NOTIF.add_notification(GenomeClassifier.INTEGRATED_CIRCUIT_INTERNALS_TOOLTIP)
		return
	set_region_open(item_index, _open[item_index] == 0)


func _on_box_shift_clicked(item_index: int) -> void:
	if BV.UI == null:
		return
	var object: Object = _model.items[item_index]["object"]
	if object is AbstractCorticalArea or object is BrainRegion:
		BV.UI.focus_searched_object(object)


func _add_export_menu() -> void:
	var button: MenuButton = MenuButton.new()
	button.text = "Export"
	button.tooltip_text = "Save the whole schematic, with the regions open as shown"
	button.flat = false
	button.icon = ICON_EXPORT_MENU
	button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var popup: PopupMenu = button.get_popup()
	for format: int in SchematicImageFile.FORMAT.values():
		popup.add_item(SchematicImageFile.LABELS[format], format)
	popup.id_pressed.connect(func(format: int) -> void: SchematicExporter.export_view(self, format as SchematicImageFile.FORMAT))
	_add_menu_button(button)
	_add_menu_gap()


func _add_open_all_buttons() -> void:
	for is_open: bool in [true, false]:
		var button: Button = Button.new()
		button.text = "Show all" if is_open else "Hide all"
		button.tooltip_text = "Open every region, including ones created later, until Hide all" if is_open else "Close every region"
		button.pressed.connect(set_all_regions_open.bind(is_open))
		_add_menu_button(button)


func _add_filter_box() -> void:
	_add_menu_gap()
	_filter_edit = LineEdit.new()
	_filter_edit.placeholder_text = "Filter areas or circuits"
	_filter_edit.tooltip_text = FILTER_TOOLTIP
	_filter_edit.clear_button_enabled = true
	_filter_edit.select_all_on_focus = true
	_filter_edit.mouse_default_cursor_shape = Control.CURSOR_IBEAM
	_filter_edit.add_theme_color_override("font_color", MENU_TEXT_COLOR)
	_filter_edit.add_theme_color_override("font_placeholder_color", FILTER_PLACEHOLDER_COLOR)
	_set_filter_error(false)
	_filter_edit.text_changed.connect(_on_filter_text_changed)
	get_menu_hbox().add_child(_filter_edit)
	_filter_timer = Timer.new()
	_filter_timer.one_shot = true
	_filter_timer.wait_time = FILTER_DEBOUNCE_S
	_filter_timer.timeout.connect(_apply_filter_query)
	add_child(_filter_timer)


## Plate like the menu buttons. A border marks focus, and a red one (with red text) marks no match.
func _set_filter_error(is_error: bool) -> void:
	_filter_edit.add_theme_color_override("font_color", FILTER_ERROR_COLOR if is_error else MENU_TEXT_COLOR)
	for state: String in ["normal", "focus", "read_only"]:
		var plate: StyleBoxFlat = StyleBoxFlat.new()
		plate.bg_color = MENU_PLATE_COLORS["normal"]
		plate.content_margin_left = COMBO_STYLER.ROW_PAD_X
		plate.content_margin_right = COMBO_STYLER.ROW_PAD_X
		if is_error:
			plate.border_color = FILTER_ERROR_COLOR
			plate.set_border_width_all(1)
		elif state == "focus":
			plate.border_color = FILTER_FOCUS_COLOR
			plate.set_border_width_all(1)
		_filter_edit.add_theme_stylebox_override(state, plate)


func _on_filter_text_changed(_text: String) -> void:
	_filter_timer.start()


## Recomputes the matches and the open set from the query. The open set is the state from before the
## filter plus the ancestors of the matches, rebuilt each time so keystrokes never accumulate.
func _apply_filter_query() -> void:
	var query: String = _filter_edit.text.strip_edges()
	if query == _filter_query:
		return
	var was_active: bool = not _filter_query.is_empty()
	_filter_query = query
	if query.is_empty():
		_set_filter_error(false)
		_recompute_filter()
		set_open_region_ids(_pre_filter_open)
		_pre_filter_open = {}
		request_initial_fit()
		return
	if not was_active:
		_pre_filter_open = open_region_ids()
	_recompute_filter()
	_set_filter_error(_filter_matches.is_empty())
	var ids: Dictionary = _pre_filter_open.duplicate()
	var target: Rect2 = Rect2()
	for match_index: int in _filter_matches:
		for ancestor: int in _model.ancestors[match_index]:
			var object: Object = _model.items[ancestor]["object"]
			if ancestor > 0 and object is BrainRegion and not _model.items[ancestor]["closed_only"]:
				ids[(object as BrainRegion).region_ID] = true
		var rect: Rect2 = _model.global_rect(match_index)
		target = rect if target.size == Vector2.ZERO else target.merge(rect)
	set_open_region_ids(ids)
	if not _filter_matches.is_empty():
		_try_fit(target.grow(FILTER_FIT_PAD))


## Matches and in-filter items from the stored query on the current model.
func _recompute_filter() -> void:
	_filter_matches = _model.items_matching(_filter_query)
	_filter_items.clear()
	var matched: Dictionary = {}
	for index: int in _filter_matches:
		matched[index] = true
	for i in _model.items.size():
		var inside: bool = matched.has(i)
		if not inside:
			for ancestor: int in _model.ancestors[i]:
				if matched.has(ancestor):
					inside = true
					break
		if inside:
			_filter_items[i] = true


func _add_menu_gap() -> void:
	var gap: Control = Control.new()
	gap.name = MENU_GROUP_GAP_NAME
	gap.set_meta(MENU_GAP_META, true)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_menu_hbox().add_child(gap)


## Menu buttons are plain plates like the Circuit Builder and Brain Monitor tab strips.
func _add_menu_button(button: Button) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.expand_icon = false
	for state: String in MENU_PLATE_COLORS:
		var plate: StyleBoxFlat = StyleBoxFlat.new()
		plate.bg_color = MENU_PLATE_COLORS[state]
		plate.content_margin_left = COMBO_STYLER.ROW_PAD_X
		plate.content_margin_right = COMBO_STYLER.ROW_PAD_X
		button.add_theme_stylebox_override(state, plate)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", MENU_TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", MENU_TEXT_COLOR_DISABLED)
	button.add_theme_color_override("icon_normal_color", MENU_TEXT_COLOR)
	button.add_theme_color_override("icon_hover_color", Color.WHITE)
	button.add_theme_color_override("icon_pressed_color", Color.WHITE)
	button.add_theme_constant_override("h_separation", COMBO_STYLER.INNER_CONTENT_SEPARATION)
	get_menu_hbox().add_child(button)


## Sizes the menu like the tab strips: their theme, their button height, and their 8 px inset.
func _style_menu() -> void:
	var inset: StyleBoxEmpty = StyleBoxEmpty.new()
	inset.set_content_margin_all(MENU_INSET)
	add_theme_stylebox_override("menu_panel", inset)
	var hbox: HBoxContainer = get_menu_hbox()
	hbox.add_theme_constant_override("separation", COMBO_STYLER.COMBO_PLATE_GAP)
	var strip_theme: Theme = _tab_strip_theme()
	if strip_theme != null:
		hbox.theme = strip_theme
	var height: float = _tab_strip_button_height(strip_theme)
	var icon_size: int = int(round(height * MENU_ICON_SCALE))
	for child: Node in hbox.get_children():
		var button: Button = child as Button
		if button != null:
			button.custom_minimum_size.y = height
			button.add_theme_constant_override("icon_max_width", icon_size)
		elif child.has_meta(MENU_GAP_META):
			(child as Control).custom_minimum_size.x = MENU_GROUP_GAP
		elif child == _filter_edit:
			_filter_edit.custom_minimum_size.y = height
	_filter_edit.custom_minimum_size.x = _filter_width_for_placeholder()


## Width that fits the placeholder in the font the menu theme gives the LineEdit (never below the floor).
func _filter_width_for_placeholder() -> float:
	var font: Font = _filter_edit.get_theme_font("font")
	var font_size: int = _filter_edit.get_theme_font_size("font_size")
	if font == null:
		return FILTER_MIN_WIDTH
	var text_width: float = font.get_string_size(_filter_edit.placeholder_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var plate: StyleBox = _filter_edit.get_theme_stylebox("normal")
	var margins: float = 0.0
	if plate != null:
		margins = plate.get_content_margin(SIDE_LEFT) + plate.get_content_margin(SIDE_RIGHT)
	var clear_icon: Texture2D = _filter_edit.get_theme_icon("clear")
	var clear_width: float = float(clear_icon.get_width()) if clear_icon != null else 0.0
	return maxf(FILTER_MIN_WIDTH, ceilf(text_width + margins + clear_width + FILTER_WIDTH_PAD))


## Same theme as the Circuit Builder and Brain Monitor tab strips (two scale steps smaller).
func _tab_strip_theme() -> Theme:
	if BV.UI == null:
		return null
	var target_scale: float = BrainObjectsCombo.scale_steps_below(BV.UI.possible_UI_scales, BV.UI.loaded_theme_scale.x, BrainObjectsCombo.TAB_STRIP_SCALE_STEPS_SMALLER)
	if is_equal_approx(target_scale, BV.UI.loaded_theme_scale.x):
		return BV.UI.loaded_theme
	var smaller: Theme = BV.UI.load_theme_resource(target_scale, UIManager.THEME_COLORS.DARK)
	return smaller if smaller != null else BV.UI.loaded_theme


func _tab_strip_button_height(strip_theme: Theme) -> float:
	var element: StringName = COMBO_STYLER.TOP_BAR_CONTROL_THEME
	if strip_theme != null and strip_theme.has_constant("size_y", element):
		return float(strip_theme.get_constant("size_y", element))
	return MENU_FALLBACK_HEIGHT


## Fits the view to [param target] (canvas units) once this view has a size. With no target it continues
## the pending fit, which is the whole canvas unless a filter fit was requested. A newer request
## cancels an older one still waiting for the scroll range to settle.
func _try_fit(target: Rect2 = Rect2()) -> void:
	if target.size != Vector2.ZERO:
		_fit_target = target
		_fit_pending = true
		_fit_generation += 1
	if not _fit_pending or not is_visible_in_tree() or size.x <= 1.0 or size.y <= 1.0 or _model == null or _model.canvas_rect.size == Vector2.ZERO:
		return
	_fit_pending = false
	var generation: int = _fit_generation
	# GraphEdit clamps scroll_offset to its scroll range, which only catches up with newly added
	# boxes after a couple of frames (Circuit Builder waits the same way).
	await get_tree().process_frame
	await get_tree().process_frame
	if generation != _fit_generation:
		return
	if not is_visible_in_tree() or size.x <= 1.0 or size.y <= 1.0:
		_fit_pending = true
		return
	var canvas: Rect2 = _model.canvas_rect
	var area: Rect2 = _fit_target if _fit_target.size != Vector2.ZERO else canvas
	var canvas_zoom: float = minf(size.x / canvas.size.x, size.y / canvas.size.y) * FIT_MARGIN
	var fit_zoom: float = minf(size.x / area.size.x, size.y / area.size.y) * FIT_MARGIN
	# The zoom floor comes from the whole canvas, so a close-up never stops zooming back out.
	zoom_min = maxf(0.01, minf(canvas_zoom * 0.5, 0.2))
	zoom_max = MAX_ZOOM
	zoom = clampf(fit_zoom, zoom_min, zoom_max)
	scroll_offset = area.get_center() * zoom - size * 0.5


func _connect_cache_signals() -> void:
	if FeagiCore == null or FeagiCore.feagi_local_cache == null:
		return
	var cache: FEAGILocalCache = FeagiCore.feagi_local_cache
	for cache_signal: Signal in [cache.genome_cache_replaced, cache.brain_regions_reloaded, cache.cortical_areas_reloaded,
			cache.mappings_reloaded, cache.classifiers_reloaded, cache.cache_cleared]:
		cache_signal.connect(_schedule_rebuild)
	cache.mapping_data.mapping_created.connect(_schedule_rebuild.unbind(1))
	cache.mapping_data.mapping_updated.connect(_schedule_rebuild.unbind(1))


func _schedule_rebuild() -> void:
	if _rebuild_timer != null and is_inside_tree():
		_rebuild_timer.start()
