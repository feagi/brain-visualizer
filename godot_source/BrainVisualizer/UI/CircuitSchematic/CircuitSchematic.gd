extends GraphEdit
class_name CircuitSchematic
## Read-only view of the whole genome in one scene. Every brain region is a box around its contents:
## the root is open, its regions start as closed blocks, and double-clicking a block opens it in place
## (the header of an open frame closes it again); Show all and Hide all open or close every region at
## once. Shift-clicking a region opens it in Circuit Builder
## and Brain Monitor, and the Export menu saves the whole view as PNG, JPG or PDF. Mappings are merged
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
	_style_menu()
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
	if not _model.is_region(item_index) or BV.UI == null:
		return
	BV.UI.open_region_in_circuit_builder_and_monitor(_model.items[item_index]["object"] as BrainRegion)


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
	var gap: Control = Control.new()
	gap.name = MENU_GROUP_GAP_NAME
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_menu_hbox().add_child(gap)


func _add_open_all_buttons() -> void:
	for is_open: bool in [true, false]:
		var button: Button = Button.new()
		button.text = "Show all" if is_open else "Hide all"
		button.tooltip_text = "Open every region to show its internals" if is_open else "Close every region"
		button.pressed.connect(set_all_regions_open.bind(is_open))
		_add_menu_button(button)


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
		elif child.name == MENU_GROUP_GAP_NAME:
			(child as Control).custom_minimum_size.x = MENU_GROUP_GAP


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


func _try_fit() -> void:
	if not _fit_pending or not is_visible_in_tree() or size.x <= 1.0 or size.y <= 1.0 or _model == null or _model.canvas_rect.size == Vector2.ZERO:
		return
	_fit_pending = false
	# GraphEdit clamps scroll_offset to its scroll range, which only catches up with newly added
	# boxes after a couple of frames (Circuit Builder waits the same way).
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_visible_in_tree() or size.x <= 1.0 or size.y <= 1.0:
		_fit_pending = true
		return
	var canvas: Rect2 = _model.canvas_rect
	var fit_zoom: float = minf(size.x / canvas.size.x, size.y / canvas.size.y) * FIT_MARGIN
	zoom_min = maxf(0.01, minf(fit_zoom * 0.5, 0.2))
	zoom_max = MAX_ZOOM
	zoom = clampf(fit_zoom, zoom_min, zoom_max)
	scroll_offset = canvas.get_center() * zoom - size * 0.5


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
