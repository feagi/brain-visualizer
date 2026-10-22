extends Node
## Runs the Phase 0 measurements and writes <out>/<label>.json plus screenshots.

const StressGenome = preload("res://make_stress_genome.gd")
const SchematicModel = preload("res://schematic_model.gd")
const BoxNode = preload("res://box_node.gd")
const EdgeLayer = preload("res://edge_layer.gd")
const CBStyleLine = preload("res://cb_style_line.gd")

const BATCH_SIZE: int = 40
const WARMUP_FRAMES: int = 10

var _params: Dictionary
var _results: Dictionary = {}
var _graph: GraphEdit
var _model: RefCounted
var _edge_layer: GraphElement
var _boxes: Dictionary = {} ## item index -> GraphElement
var _frame_ms: PackedFloat64Array = []
var _last_us: int = 0
var _recording: bool = false
var _out_dir: String


func _ready() -> void:
	_params = StressGenome.parse_args(OS.get_cmdline_user_args())
	_out_dir = String(_params.get("out", "user://spike"))
	DirAccess.make_dir_recursive_absolute(_out_dir)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	OS.low_processor_usage_mode = false
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	DisplayServer.window_set_size(Vector2i(int(_params.get("width", 1920)), int(_params.get("height", 1080))))
	await get_tree().process_frame
	await get_tree().process_frame
	await _run()
	_write_results()
	get_tree().quit(0)


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	if _recording and _last_us > 0:
		_frame_ms.append((now - _last_us) / 1000.0)
	_last_us = now


func _run() -> void:
	var lines_mode: String = String(_params.get("lines", "multiline"))
	_results["params"] = _params
	_results["machine"] = {"cpu": OS.get_processor_name(), "renderer": RenderingServer.get_current_rendering_method(),
		"gpu": RenderingServer.get_video_adapter_name(), "window": DisplayServer.window_get_size(), "viewport": get_viewport().get_visible_rect().size}

	# Data side: no nodes.
	var memory_before: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	var t: int = Time.get_ticks_usec()
	var data: Dictionary = StressGenome.generate(_params)
	_results["generate_ms"] = _ms(t)
	_model = SchematicModel.new()
	t = Time.get_ticks_usec()
	_model.build(data)
	_results["tree_build_ms"] = _ms(t)
	t = Time.get_ticks_usec()
	_model.layout()
	_results["layout_ms"] = _ms(t)
	_results["model_memory_mb"] = (Performance.get_monitor(Performance.MEMORY_STATIC) - memory_before) / 1048576.0
	_results["counts"] = {"regions": _model.region_indexes.size(), "areas": _model.area_indexes.size(), "mappings": _model.mappings.size(),
		"canvas": _model.canvas_rect.size}

	var open_all: PackedByteArray = _model.mask_where(func(_it: Dictionary) -> bool: return true)
	var open_root: PackedByteArray = _model.mask_where(func(_it: Dictionary) -> bool: return false)
	var open_shallow: PackedByteArray = _model.mask_where(func(it: Dictionary) -> bool: return int(it["depth"]) <= 2)
	var grouping: Dictionary = {}
	var all_edges: Array = []
	for case_name in ["all_open", "root_only", "depth_le_2"]:
		var mask: PackedByteArray = {"all_open": open_all, "root_only": open_root, "depth_le_2": open_shallow}[case_name]
		t = Time.get_ticks_usec()
		var grouped: Dictionary = _model.group_edges(mask)
		var took: float = _ms(t)
		var line_total: int = 0
		for edge in grouped.edges:
			line_total += int(edge[2])
		var badge_total: int = 0
		for count in grouped.badges.values():
			badge_total += int(count)
		grouping[case_name] = {"ms": took, "drawn_lines": grouped.edges.size(), "badges": grouped.badges.size(),
			"conserved": line_total + badge_total == _model.mappings.size()}
		if case_name == "all_open":
			all_edges = grouped.edges
	_results["grouping"] = grouping

	# View side.
	_graph = GraphEdit.new()
	_graph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_graph.zoom_min = 0.005
	_graph.zoom_max = 2.0
	_graph.minimap_enabled = true
	add_child(_graph)
	await get_tree().process_frame
	var view_size: Vector2 = _graph.size
	var fit_zoom: float = minf(view_size.x / _model.canvas_rect.size.x, view_size.y / _model.canvas_rect.size.y) * 0.95
	_results["fit_zoom"] = fit_zoom

	# Open/close decision cost at three views.
	var decide: Dictionary = {}
	for zoom_case in [["fit", fit_zoom], ["mid", fit_zoom * 6.0], ["close", 1.0]]:
		var zoom: float = zoom_case[1]
		var view_rect: Rect2 = Rect2(_model.canvas_rect.get_center() - view_size / zoom * 0.5, view_size / zoom)
		t = Time.get_ticks_usec()
		var mask: PackedByteArray = _model.decide_open(open_root, view_rect, zoom, 400.0, 250.0)
		var decide_ms: float = _ms(t)
		var opened: int = 0
		for i in _model.region_indexes:
			opened += mask[i]
		t = Time.get_ticks_usec()
		var grouped: Dictionary = _model.group_edges(mask)
		decide[zoom_case[0]] = {"zoom": zoom, "decide_ms": decide_ms, "group_ms": _ms(t), "open_regions": opened, "drawn_lines": grouped.edges.size()}
	_results["lod_pass"] = decide

	_set_view(fit_zoom, _model.canvas_rect.get_center())

	# Build every box in batches, recording frame times while it fills in.
	var order: Array[int] = []
	var regions_by_depth: Array = Array(_model.region_indexes)
	regions_by_depth.sort_custom(func(a: int, b: int) -> bool: return _model.items[a]["depth"] < _model.items[b]["depth"])
	order.assign(regions_by_depth)
	order.append_array(Array(_model.area_indexes))
	var spawn_us: int = 0
	_start_recording()
	t = Time.get_ticks_usec()
	for start in range(0, order.size(), BATCH_SIZE):
		var batch_started: int = Time.get_ticks_usec()
		for i in range(start, mini(start + BATCH_SIZE, order.size())):
			_spawn_box(order[i])
		spawn_us += Time.get_ticks_usec() - batch_started
		await get_tree().process_frame
	_recording = false
	# Lines go above every frame and below every area: frames, then the line layer, then areas.
	if lines_mode == "multiline" or lines_mode == "polyline":
		_edge_layer = EdgeLayer.new()
		_graph.add_child(_edge_layer)
		_graph.move_child(_edge_layer, _model.region_indexes.size())
		_edge_layer.setup(_graph, _model, all_edges, lines_mode)
	_results["build"] = {"elements": order.size(), "total_ms": _ms(t), "spawn_cpu_ms": spawn_us / 1000.0,
		"spawn_cpu_ms_per_element": spawn_us / 1000.0 / order.size(), "frames": _stats(_frame_ms, 0)}

	if lines_mode == "cb":
		_start_recording()
		t = Time.get_ticks_usec()
		spawn_us = 0
		for start in range(0, all_edges.size(), BATCH_SIZE):
			var batch_started: int = Time.get_ticks_usec()
			for i in range(start, mini(start + BATCH_SIZE, all_edges.size())):
				_spawn_cb_line(all_edges[i])
			spawn_us += Time.get_ticks_usec() - batch_started
			await get_tree().process_frame
		_recording = false
		_results["cb_lines_build"] = {"lines": all_edges.size(), "total_ms": _ms(t), "spawn_cpu_ms": spawn_us / 1000.0, "frames": _stats(_frame_ms, 0)}

	for i in 5:
		await get_tree().process_frame
	_results["nodes"] = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	_results["memory_static_mb"] = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0

	await _screenshot("fit")
	_set_view(fit_zoom * 6.0, _deep_area_center())
	await _screenshot("mid")
	_set_view(1.0, _deep_area_center())
	await _screenshot("close")

	var center: Vector2 = _model.canvas_rect.get_center()
	var canvas: Vector2 = _model.canvas_rect.size
	var phases: Dictionary = {}
	phases["fit_pan"] = await _bench(4.0, func(u: float) -> void:
		_set_view(fit_zoom, center + Vector2(sin(u * TAU * 2.0) * canvas.x * 0.2, 0)))
	phases["zoom_sweep"] = await _bench(6.0, func(u: float) -> void:
		_set_view(fit_zoom * pow(1.0 / fit_zoom, sin(u * PI)), center))
	phases["close_pan"] = await _bench(6.0, func(u: float) -> void:
		_set_view(1.0, _model.canvas_rect.position + canvas * (0.1 + 0.8 * u)))
	_results["phases"] = phases
	if _edge_layer != null:
		_results["edge_draw_cpu_ms"] = _stats(_edge_layer.draw_cpu_ms, 0)

	_results["frame_click_raises_above_children"] = await _check_frame_raise(fit_zoom)


func _spawn_box(index: int) -> void:
	var item: Dictionary = _model.items[index]
	var box: GraphElement = BoxNode.new()
	if item["kind"] == "region":
		box.setup_frame(item["name"], item["depth"], item["size"])
	else:
		box.setup_area(item["name"], item["type"], item["size"])
	box.position_offset = item["global"]
	_graph.add_child(box)
	_boxes[index] = box


## Same nodes CB adds per connection: the line element plus one terminal row on each box.
func _spawn_cb_line(edge: Array) -> void:
	var from_rect: Rect2 = _model.global_rect(edge[0])
	var to_rect: Rect2 = _model.global_rect(edge[1])
	var line: GraphElement = CBStyleLine.new()
	_graph.add_child(line)
	_graph.move_child(line, _model.region_indexes.size())
	line.setup(Vector2(from_rect.end.x, from_rect.get_center().y), Vector2(to_rect.position.x, to_rect.get_center().y), EdgeLayer.KIND_COLORS[0])
	for end in [edge[0], edge[1]]:
		var row: HBoxContainer = HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label: Label = Label.new()
		label.text = "port"
		row.add_child(label)
		var port: TextureRect = TextureRect.new()
		row.add_child(port)
		_boxes[end].add_child(row)


func _set_view(zoom: float, center: Vector2) -> void:
	_graph.zoom = zoom
	_graph.scroll_offset = center * _graph.zoom - _graph.size * 0.5


func _bench(duration_s: float, step: Callable) -> Dictionary:
	_start_recording()
	var started: int = Time.get_ticks_usec()
	var draw_calls: Array[float] = []
	var process_ms: Array[float] = []
	var render_cpu_ms: Array[float] = []
	var render_gpu_ms: Array[float] = []
	var viewport_rid: RID = get_viewport().get_viewport_rid()
	while true:
		var elapsed: float = (Time.get_ticks_usec() - started) / 1e6
		if elapsed > duration_s:
			break
		step.call(elapsed / duration_s)
		await get_tree().process_frame
		draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		render_cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid) + RenderingServer.get_frame_setup_time_cpu())
		render_gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid))
	_recording = false
	var stats: Dictionary = _stats(_frame_ms, WARMUP_FRAMES)
	stats["draw_calls_median"] = _median(draw_calls)
	stats["process_ms_median"] = _median(process_ms)
	stats["render_cpu_ms_median"] = _median(render_cpu_ms)
	stats["render_gpu_ms_median"] = _median(render_gpu_ms)
	return stats


func _median(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	return snappedf(sorted[sorted.size() / 2], 0.01)


func _start_recording() -> void:
	_frame_ms = PackedFloat64Array()
	_last_us = 0
	_recording = true


## Clicks a depth-1 frame's header and reports whether GraphEdit moved it above its own areas.
func _check_frame_raise(fit_zoom: float) -> Variant:
	var frame_index: int = -1
	for i in _model.region_indexes:
		if _model.items[i]["depth"] == 1:
			frame_index = i
			break
	if frame_index == -1:
		return null
	var area_child: int = -1
	for child in _model.items[frame_index]["children"]:
		if _model.items[child]["kind"] == "area":
			area_child = child
			break
	if area_child == -1:
		return null
	var rect: Rect2 = _model.global_rect(frame_index)
	_set_view(minf(1.0, fit_zoom * 4.0), rect.get_center())
	await get_tree().process_frame
	await get_tree().process_frame
	var before: Array[int] = [_boxes[frame_index].get_index(), _boxes[area_child].get_index()]
	var click_at: Vector2 = (rect.position + Vector2(rect.size.x * 0.5, 12)) * _graph.zoom - _graph.scroll_offset + _graph.global_position
	for pressed in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = click_at
		event.global_position = click_at
		Input.parse_input_event(event)
		await get_tree().process_frame
	await get_tree().process_frame
	var clicked_selected: bool = _boxes[frame_index].selected
	# A real press on a GraphElement emits raise_request, which GraphEdit answers by moving it to the front.
	if not clicked_selected:
		_boxes[frame_index].raise_request.emit()
		await get_tree().process_frame
	var after: Array[int] = [_boxes[frame_index].get_index(), _boxes[area_child].get_index()]
	return {"before_frame_vs_area_index": before, "after_frame_vs_area_index": after, "synthetic_click_selected": clicked_selected,
		"raise_request_emitted_directly": not clicked_selected, "raised_above": before[0] < before[1] and after[0] > after[1]}


func _deep_area_center() -> Vector2:
	var deepest: int = _model.area_indexes[0]
	for i in _model.area_indexes:
		if _model.items[i]["depth"] > _model.items[deepest]["depth"]:
			deepest = i
	return _model.global_rect(deepest).get_center()


func _screenshot(name: String) -> void:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png("%s/%s_%s.png" % [_out_dir, _params.get("label", "run"), name])


func _stats(samples: PackedFloat64Array, skip: int) -> Dictionary:
	var values: Array = Array(samples.slice(mini(skip, samples.size())))
	if values.is_empty():
		return {"frames": 0}
	values.sort()
	var total: float = 0.0
	for v in values:
		total += v
	var mean: float = total / values.size()
	return {"frames": values.size(), "mean_ms": snappedf(mean, 0.01), "fps": snappedf(1000.0 / mean, 0.1),
		"p95_ms": snappedf(values[int(values.size() * 0.95)], 0.01), "p99_ms": snappedf(values[int(values.size() * 0.99)], 0.01),
		"max_ms": snappedf(values[-1], 0.01)}


func _ms(started_us: int) -> float:
	return snappedf((Time.get_ticks_usec() - started_us) / 1000.0, 0.001)


func _write_results() -> void:
	var path: String = "%s/%s.json" % [_out_dir, _params.get("label", "run")]
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(_results, "  "))
	file.close()
	print(JSON.stringify(_results, "  "))
