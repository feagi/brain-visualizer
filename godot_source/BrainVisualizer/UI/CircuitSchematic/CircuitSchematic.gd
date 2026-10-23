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
	var popup: PopupMenu = button.get_popup()
	for format: int in SchematicImageFile.FORMAT.values():
		popup.add_item(SchematicImageFile.LABELS[format], format)
	popup.id_pressed.connect(func(format: int) -> void: SchematicExporter.export_view(self, format as SchematicImageFile.FORMAT))
	get_menu_hbox().add_child(button)


func _add_open_all_buttons() -> void:
	for is_open: bool in [true, false]:
		var button: Button = Button.new()
		button.text = "Show all" if is_open else "Hide all"
		button.tooltip_text = "Open every region to show its internals" if is_open else "Close every region"
		button.pressed.connect(set_all_regions_open.bind(is_open))
		get_menu_hbox().add_child(button)


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


func _input(event: InputEvent) -> void: # TEMP SCHEMATIC-DEBUG
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse != null and is_visible_in_tree() and get_global_rect().has_point(mouse.global_position):
		var hovered: Control = get_viewport().gui_get_hovered_control()
		print("SCHEMATIC-DEBUG raw btn=%d pressed=%s dbl=%s dev=%d hovered=%s t=%d" % [mouse.button_index, mouse.pressed, mouse.double_click, mouse.device, hovered.get_path() if hovered != null else "none", Time.get_ticks_msec()])
