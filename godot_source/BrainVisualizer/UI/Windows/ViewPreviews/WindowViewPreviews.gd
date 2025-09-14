extends BaseDraggableWindow
class_name WindowViewPreviews

const WINDOW_NAME: StringName = "view_previews"
const SCALAR_RES: Vector2i = Vector2i(2,2)

var _resolution_UI: Label
var _preview_container: PanelContainer
var _visual_preview: TextureRect
var _buttons: HBoxContainer
var _shm_status: Label
var _view_toggle: OptionButton
var _agent_dropdown: OptionButton

# agent → video_stream mapping
var _agent_video_map: Dictionary = {}
var _agent_video_map_feagi: Dictionary = {}

# Retry state for opening selected agent SHM
var _video_init_attempts: int = 0
var _video_init_max_attempts: int = 40
var _video_last_error: String = ""

# cache
var _current_resolution: Vector2i = Vector2i(0,0)
var _preview_image: Image = Image.new()
var _preview_image_texture: ImageTexture = ImageTexture.new()
var _resolution_scalar_dyn: Vector2 = Vector2(1.0, 1.0)

# Shared memory video support (desktop preview via SharedMemVideo GDExtension)
var _use_shared_mem: bool = false
var _shm_reader_raw: Variant = null # Use Variant to avoid hard dependency if extension missing
var _shm_reader_feagi: Variant = null

# User-resizable viewport (bottom-right drag)
var _user_view_size: Vector2 = Vector2.ZERO
var _resizing: bool = false
var _resize_margin: int = 16
var _resize_start_mouse: Vector2 = Vector2.ZERO
var _resize_start_size: Vector2 = Vector2.ZERO
var _resize_handle: Panel
var _window_border_pad: int = 12

# Segmentation UI controls (FEAGI view only)
var _seg_controls: VBoxContainer
var _eccx_slider: HSlider
var _eccy_slider: HSlider
var _modx_slider: HSlider
var _mody_slider: HSlider
var _ecc_val_label: Label
var _mod_val_label: Label
var _apply_btn: Button
var _reset_btn: Button
var _default_ecc: Vector2 = Vector2(0.5, 0.5)
var _default_mod: Vector2 = Vector2(0.85, 0.85)

# Overlay to visualize segmentation preview on top of the FEAGI video
var _seg_overlay: Control
var _scale_row: HBoxContainer
var _scale_raw: float = 1.0
var _scale_feagi: float = 1.0

# Local overlay class that draws red guide lines showing 3x3 segmentation
class SegOverlay:
	extends Control
	var get_eccentricity: Callable
	var get_modulation: Callable
	var is_feagi_view: Callable

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		top_level = false
		z_index = 10000
		set_anchors_preset(Control.PRESET_FULL_RECT)
		var p = get_parent()
		if p and p is Control:
			(p as Control).item_rect_changed.connect(_on_parent_rect_changed)

	func _on_parent_rect_changed() -> void:
		queue_redraw()

	func _compute_draw_rect(tr: TextureRect, tex: Texture2D) -> Rect2:
		var ctrl_size: Vector2 = tr.size
		var img_size: Vector2 = tex.get_size()
		if img_size.x <= 0.0 or img_size.y <= 0.0:
			return Rect2(Vector2.ZERO, ctrl_size)
		var mode: int = tr.stretch_mode
		# Default: fill entire rect
		var rect_pos: Vector2 = Vector2.ZERO
		var rect_size: Vector2 = ctrl_size
		match mode:
			TextureRect.STRETCH_SCALE, TextureRect.STRETCH_TILE:
				rect_pos = Vector2.ZERO
				rect_size = ctrl_size
			TextureRect.STRETCH_KEEP:
				rect_pos = Vector2.ZERO
				rect_size = img_size
			TextureRect.STRETCH_KEEP_CENTERED:
				rect_size = img_size
				rect_pos = (ctrl_size - rect_size) * 0.5
			TextureRect.STRETCH_KEEP_ASPECT, TextureRect.STRETCH_KEEP_ASPECT_CENTERED, TextureRect.STRETCH_KEEP_ASPECT_COVERED:
				var sx: float = ctrl_size.x / img_size.x
				var sy: float = ctrl_size.y / img_size.y
				var s: float = sx
				if mode == TextureRect.STRETCH_KEEP_ASPECT or mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
					s = min(sx, sy)
				else:
					s = max(sx, sy)
				rect_size = img_size * s
				rect_pos = (ctrl_size - rect_size) * 0.5
		return Rect2(rect_pos, rect_size)

	func _draw() -> void:
		if is_feagi_view and not is_feagi_view.call():
			return
		var parent_tr: TextureRect = get_parent() as TextureRect
		if parent_tr == null or parent_tr.texture == null:
			return
		var draw_rect: Rect2 = _compute_draw_rect(parent_tr, parent_tr.texture)
		# Read sliders
		var ecc: Vector2 = Vector2(0.5, 0.5)
		if get_eccentricity:
			ecc = get_eccentricity.call()
		var mod: Vector2 = Vector2(0.85, 0.85)
		if get_modulation:
			mod = get_modulation.call()
		ecc.x = clamp(ecc.x, 0.0, 1.0)
		ecc.y = clamp(ecc.y, 0.0, 1.0)
		mod.x = clamp(mod.x, 0.0, 1.0)
		mod.y = clamp(mod.y, 0.0, 1.0)
		# Compute center rectangle from eccentricity (center) and modulation (size)
		var cx: float = draw_rect.position.x + ecc.x * draw_rect.size.x
		var cy: float = draw_rect.position.y + ecc.y * draw_rect.size.y
		var w: float = mod.x * draw_rect.size.x
		var h: float = mod.y * draw_rect.size.y
		var x_left: float = clamp(cx - (w * 0.5), draw_rect.position.x, draw_rect.position.x + draw_rect.size.x)
		var x_right: float = clamp(cx + (w * 0.5), draw_rect.position.x, draw_rect.position.x + draw_rect.size.x)
		var y_top: float = clamp(cy - (h * 0.5), draw_rect.position.y, draw_rect.position.y + draw_rect.size.y)
		var y_bottom: float = clamp(cy + (h * 0.5), draw_rect.position.y, draw_rect.position.y + draw_rect.size.y)
		var color: Color = Color(1.0, 0.0, 0.0, 0.95)
		var thickness: float = max(2.0, min(draw_rect.size.x, draw_rect.size.y) * 0.003)
		# Draw full-length grid lines for 3x3 segmentation
		draw_line(Vector2(x_left, draw_rect.position.y), Vector2(x_left, draw_rect.position.y + draw_rect.size.y), color, thickness)
		draw_line(Vector2(x_right, draw_rect.position.y), Vector2(x_right, draw_rect.position.y + draw_rect.size.y), color, thickness)
		draw_line(Vector2(draw_rect.position.x, y_top), Vector2(draw_rect.position.x + draw_rect.size.x, y_top), color, thickness)
		draw_line(Vector2(draw_rect.position.x, y_bottom), Vector2(draw_rect.position.x + draw_rect.size.x, y_bottom), color, thickness)

func _ready():
	super()
	print("[Preview] _ready(): initializing View Previews window")
	_resolution_UI = _window_internals.get_node("HBoxContainer/resolution")
	# After wrapping preview in a ScrollContainer, path changes
	_preview_container = _window_internals.get_node("Scroll/PanelContainer")
	_visual_preview = _window_internals.get_node("Scroll/PanelContainer/MarginContainer/TextureRect")
	# Inject segmentation overlay over the preview texture
	_seg_overlay = SegOverlay.new()
	_seg_overlay.get_eccentricity = Callable(self, "_get_eccentricity")
	_seg_overlay.get_modulation = Callable(self, "_get_modulation")
	_seg_overlay.is_feagi_view = Callable(self, "_is_feagi_view")
	_visual_preview.add_child(_seg_overlay)
	_seg_overlay.visible = false
	# React to texture changes (resolution/frame) to keep overlay aligned
	_visual_preview.item_rect_changed.connect(_on_preview_rect_changed)
	_buttons = _window_internals.get_node("sizes")
	_setup_scale_buttons()
	_shm_status = _window_internals.get_node("SHMStatus")
	_view_toggle = _window_internals.get_node("SHMControls/ViewToggle")
	_agent_dropdown = _window_internals.get_node("SHMControls/AgentDropdown")
	if _agent_dropdown:
		_agent_dropdown.clear()
		_agent_dropdown.add_item("Select agent…")
		_agent_dropdown.disabled = true
		_agent_dropdown.item_selected.connect(_on_agent_dropdown_selected)
	# Setup toggle options: 0=Raw, 1=FEAGI
	_view_toggle.clear()
	_view_toggle.add_item("Raw", 0)
	_view_toggle.add_item("FEAGI", 1)
	_view_toggle.selected = 0
	_view_toggle.item_selected.connect(_on_view_toggle_selected)
	# Initialize scale for default view after initial layout
	call_deferred("_apply_current_scale")

	# Build segmentation UI as its own row (full width)
	_seg_controls = VBoxContainer.new()
	_seg_controls.name = "SegControls"
	_seg_controls.visible = false
	_seg_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seg_controls.custom_minimum_size = Vector2(0, 56)
	_window_internals.add_child(_seg_controls)

	# Title
	var title := Label.new()
	title.text = "Segmentation (FEAGI):"
	_seg_controls.add_child(title)

	# Eccentricity row
	var ecc_row := HBoxContainer.new(); ecc_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ecc_lbl := Label.new(); ecc_lbl.text = "Eccentricity"
	_eccx_slider = HSlider.new(); _eccx_slider.min_value = 0.0; _eccx_slider.max_value = 1.0; _eccx_slider.step = 0.01; _eccx_slider.value = _default_ecc.x; _eccx_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _eccx_slider.custom_minimum_size = Vector2(160, 0)
	_eccy_slider = HSlider.new(); _eccy_slider.min_value = 0.0; _eccy_slider.max_value = 1.0; _eccy_slider.step = 0.01; _eccy_slider.value = _default_ecc.y; _eccy_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _eccy_slider.custom_minimum_size = Vector2(160, 0)
	_ecc_val_label = Label.new(); _ecc_val_label.text = "(%.2f, %.2f)" % [_default_ecc.x, _default_ecc.y]
	ecc_row.add_child(ecc_lbl); ecc_row.add_child(_eccx_slider); ecc_row.add_child(_eccy_slider); ecc_row.add_child(_ecc_val_label)
	_seg_controls.add_child(ecc_row)

	# Modularity row
	var mod_row := HBoxContainer.new(); mod_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mod_lbl := Label.new(); mod_lbl.text = "Modularity"
	_modx_slider = HSlider.new(); _modx_slider.min_value = 0.0; _modx_slider.max_value = 1.0; _modx_slider.step = 0.01; _modx_slider.value = _default_mod.x; _modx_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _modx_slider.custom_minimum_size = Vector2(160, 0)
	_mody_slider = HSlider.new(); _mody_slider.min_value = 0.0; _mody_slider.max_value = 1.0; _mody_slider.step = 0.01; _mody_slider.value = _default_mod.y; _mody_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _mody_slider.custom_minimum_size = Vector2(160, 0)
	_mod_val_label = Label.new(); _mod_val_label.text = "(%.2f, %.2f)" % [_default_mod.x, _default_mod.y]
	mod_row.add_child(mod_lbl); mod_row.add_child(_modx_slider); mod_row.add_child(_mody_slider); mod_row.add_child(_mod_val_label)
	_seg_controls.add_child(mod_row)

	# Buttons row
	var btn_row := HBoxContainer.new()
	_apply_btn = Button.new(); _apply_btn.text = "Apply"; _apply_btn.tooltip_text = "Apply eccentricity/modularity"
	_reset_btn = Button.new(); _reset_btn.text = "Reset"
	btn_row.add_child(_apply_btn); btn_row.add_child(_reset_btn)
	_seg_controls.add_child(btn_row)

	# Wire signals
	_eccx_slider.value_changed.connect(_on_seg_value_changed)
	_eccy_slider.value_changed.connect(_on_seg_value_changed)
	_modx_slider.value_changed.connect(_on_seg_value_changed)
	_mody_slider.value_changed.connect(_on_seg_value_changed)
	_apply_btn.pressed.connect(_on_apply_segmentation)
	_reset_btn.pressed.connect(_on_reset_segmentation)
	# Populate agents with video streams
	_try_fetch_video_shm_from_api()
	# Try core SHM path via environment (provided by FEAGI launcher)
	print("𒓉 [Preview] _ready(): attempting FEAGI_VIZ_SHM shared-memory setup")
	_try_open_core_visualization_shm()

	# Add a visible bottom-right resize handle
	_resize_handle = Panel.new()
	_resize_handle.name = "ResizeHandle"
	_resize_handle.mouse_filter = Control.MOUSE_FILTER_STOP
	_resize_handle.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	_resize_handle.size = Vector2(18, 18)
	_resize_handle.z_index = 1000
	# Make handle top-level so it's not constrained by Container layout and always on top
	add_child(_resize_handle)
	_resize_handle.top_level = true
	_resize_handle.z_index = 10000
	_resize_handle.visible = true
	# Position initially and on window resize
	_position_resize_handle()
	if is_instance_valid(_window_panel):
		_window_panel.resized.connect(_position_resize_handle)
		_window_panel.item_rect_changed.connect(_position_resize_handle)
	# Reposition when this window moves or changes
	item_rect_changed.connect(_position_resize_handle)
	# Simple visual style
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.85, 0.85, 0.85, 0.95)
	sb.border_color = Color(0.6, 0.6, 0.6, 1.0)
	sb.border_width_bottom = 1
	sb.border_width_right = 1
	_resize_handle.add_theme_stylebox_override("panel", sb)
	_resize_handle.gui_input.connect(_on_resize_handle_gui_input)
	
func setup() -> void:
	_setup_base_window(WINDOW_NAME)
	# If SHM already active from _ready() discovery, skip WS fallback
	if _use_shared_mem:
		print("𒓉 [Preview] setup(): SHM already active; skipping WS fallback")
		return
	# Prefer shared memory reader if explicitly configured via environment
	var shm_path: String = OS.get_environment("FEAGI_VIDEO_SHM")
	print("𒓉 [Preview] setup(): FEAGI_VIDEO_SHM=\"%s\"; SharedMemVideo available? %s" % [shm_path, str(ClassDB.class_exists("SharedMemVideo"))])
	if shm_path != "":
		var exists_env := FileAccess.file_exists(shm_path)
		print("𒓉 [Preview] setup(): FEAGI_VIDEO_SHM exists? ", str(exists_env))
	if shm_path != "" and ClassDB.class_exists("SharedMemVideo"):
		var obj = ClassDB.instantiate("SharedMemVideo")
		_shm_reader_feagi = obj
		if _shm_reader_feagi and _shm_reader_feagi.open(shm_path):
			var info: Dictionary = _shm_reader_feagi.get_header_info()
			print("𒓉 [Preview] Using shared memory (FEAGI_VIDEO_SHM): ", shm_path)
			print("𒓉 [Preview] SharedMemVideo header:", info)
			_shm_status.text = "SHM: opened"
			_use_shared_mem = true
			set_process(true)
			return
		else:
			var reason := "open() returned false"
			if _shm_reader_feagi == null:
				reason = "SharedMemVideo.instantiate() returned null"
			elif not FileAccess.file_exists(shm_path):
				reason = "file does not exist"
			print("𒓉 [Preview] setup(): SHM selection failed for FEAGI_VIDEO_SHM (", shm_path, "): ", reason)
	# Fallback to existing FEAGI visual data stream
	print("𒓉 [Preview] setup(): falling back to WebSocket visualization stream")
	FeagiCore.network.websocket_API.feagi_return_visual_data.connect(_update_preview_texture_from_raw_data)
	
func _update_preview_texture_from_raw_data(bytes: PackedByteArray) -> void:
	var resolution: Vector2i = Vector2i(bytes.decode_u16(2), bytes.decode_u16(4))
	if resolution == Vector2i(0,0):
		return
	if resolution != _current_resolution:
		_update_resolution(resolution)
	_preview_image.set_data(resolution.x, resolution.y, false, Image.FORMAT_RGB8, bytes.slice(6))
	_preview_image_texture.update(_preview_image)
	_visual_preview.texture = _preview_image_texture
	_update_container_to_content()

func _update_resolution(res: Vector2i) -> void:
	_current_resolution = res
	if !_preview_container.visible:
		_preview_container.visible = true
		# Ensure ScrollContainer is also revealed
		var sc: ScrollContainer = _window_internals.get_node_or_null("Scroll")
		if sc:
			sc.visible = true
		_buttons.visible = true
		_update_scale_size()
	_resolution_UI.text = "%d x %d" % [res.x, res.y]
	_preview_image = Image.create_empty(res.x, res.y, false, Image.FORMAT_RGB8)
	_preview_image_texture.set_image(_preview_image)
	_visual_preview.texture = _preview_image_texture
	_update_container_to_content()
	if is_instance_valid(_seg_overlay):
		_seg_overlay.queue_redraw()
	
func _update_scale_size() -> void:
	var base: Vector2 = Vector2(float(_current_resolution.x * SCALAR_RES.x), float(_current_resolution.y * SCALAR_RES.y))
	_visual_preview.custom_minimum_size = Vector2(base.x * _resolution_scalar_dyn.x, base.y * _resolution_scalar_dyn.y)
	_update_container_to_content()
	if is_instance_valid(_seg_overlay):
		_seg_overlay.queue_redraw()

func _scale_button_pressed(scalar: float) -> void: # set with custom arguments from TSCN signal
	# Maintain independent scale for Raw vs FEAGI view
	if _view_toggle and _view_toggle.selected == 0:
		_scale_raw = scalar
	else:
		_scale_feagi = scalar
	_apply_current_scale()
	if is_instance_valid(_seg_overlay):
		_seg_overlay.queue_redraw()

func _apply_current_scale() -> void:
	var active_scale: float = 1.0
	if _view_toggle and _view_toggle.selected == 0:
		active_scale = _scale_raw
	else:
		active_scale = _scale_feagi
	_resolution_scalar_dyn = Vector2(active_scale, active_scale)
	_update_scale_size()
	_update_container_to_content()
	
func _process(_dt: float) -> void:
	# Keep resize handle glued to the window position
	_position_resize_handle()
	if not _use_shared_mem:
		return
	var is_raw: bool = _view_toggle.selected == 0
	var reader: Variant = _shm_reader_raw
	if not is_raw:
		reader = _shm_reader_feagi
	if reader == null:
		return
	var tex: Texture2D = reader.get_texture()
	if tex:
		# Update resolution and UI on first frame or when dimensions change
		var size: Vector2i = tex.get_size()
		if size != _current_resolution:
			_update_resolution(size)
		_visual_preview.texture = tex
		_update_container_to_content()
		if is_instance_valid(_seg_overlay):
			_seg_overlay.queue_redraw()
	else:
		# Poll header info for debugging
		var info: Dictionary = reader.get_header_info()
		print("SharedMemVideo tick: ", info)
		_shm_status.text = "SHM: tick " + str(info.get("frame_seq", 0))

func _try_open_core_visualization_shm() -> void:
	if not ClassDB.class_exists("SharedMemVideo"):
		print("𒓉 [Preview] SharedMemVideo GDExtension not found; using WebSocket")
		_shm_status.text = "SHM: extension missing - using websocket"
		_fallback_to_websocket()
		return
	# Prefer explicit video preview path if provided
	var video_path: String = OS.get_environment("FEAGI_VIDEO_SHM")
	if video_path != "":
		var obj_v = ClassDB.instantiate("SharedMemVideo")
		if obj_v and obj_v.open(video_path):
			_shm_reader_feagi = obj_v
			_use_shared_mem = true
			_shm_status.text = "SHM: video preview"
			print("𒓉 [Preview] Using shared memory (FEAGI_VIDEO_SHM): ", video_path)
			set_process(true)
			_update_container_to_content()
			return
	# Fallback to core visualization path
	var core_viz_path: String = OS.get_environment("FEAGI_VIZ_SHM")
	if core_viz_path != "":
		var obj = ClassDB.instantiate("SharedMemVideo")
		if obj and obj.open(core_viz_path):
			_shm_reader_feagi = obj
			_use_shared_mem = true
			_shm_status.text = "SHM: core visualization"
			print("𒓉 [Preview] Using shared memory (FEAGI_VIZ_SHM): ", core_viz_path)
			set_process(true)
			_update_container_to_content()
			return
	# Attempt API discovery: GET /v1/agent/shared_mem
	_try_fetch_video_shm_from_api()
	if _use_shared_mem:
		return
	# Final fallback: WebSocket
	print("𒓉 [Preview] No SHM path available; using WebSocket")
	_shm_status.text = "SHM: not provided - using websocket"
	_fallback_to_websocket()


func _try_fetch_video_shm_from_api() -> void:
	if not FeagiCore or not FeagiCore.network or not FeagiCore.network.http_API or FeagiCore.network.http_API.address_list == null:
		return
	var http_API = FeagiCore.network.http_API
	var def = APIRequestWorkerDefinition.define_single_GET_call(http_API.address_list.GET_agent_shared_mem)
	var worker = http_API.make_HTTP_call(def)
	print("𒓉 [Preview] Querying /v1/agent/shared_mem for agents with video preview streams…")
	await worker.worker_done
	var out = worker.retrieve_output_and_close()
	if out.has_errored or out.has_timed_out:
		return
	var resp: Variant = out.decode_response_as_dict()
	if typeof(resp) != TYPE_DICTIONARY:
		return
	# Populate dropdown with agents that have video_stream_raw/feagi (or legacy video_stream)
	_agent_video_map.clear()
	_agent_video_map_feagi.clear()
	if _agent_dropdown:
		_agent_dropdown.disabled = true
		_agent_dropdown.clear()
		_agent_dropdown.add_item("Select agent…")
	var count := 0
	for aid in resp.keys():
		var mapping = resp[aid]
		if typeof(mapping) != TYPE_DICTIONARY:
			continue
		var raw_path: String = str(mapping.get("video_stream_raw", ""))
		var feagi_path: String = str(mapping.get("video_stream_feagi", ""))
		var legacy_path: String = str(mapping.get("video_stream", ""))
		if raw_path == "" and legacy_path != "":
			raw_path = legacy_path
		if raw_path != "" or feagi_path != "":
			_agent_video_map[aid] = raw_path
			_agent_video_map_feagi[aid] = feagi_path
			if _agent_dropdown:
				_agent_dropdown.add_item(str(aid))
				var idx := _agent_dropdown.get_item_count() - 1
				var md := {"raw": raw_path, "feagi": feagi_path}
				_agent_dropdown.set_item_metadata(idx, md)
				count += 1
	if _agent_dropdown:
		_agent_dropdown.disabled = count == 0
		print("𒓉 [Preview] Agents with video streams found: ", str(count))

func _on_agent_dropdown_selected(index: int) -> void:
	if index <= 0:
		return
	if not _agent_dropdown:
		return
	var md = _agent_dropdown.get_item_metadata(index)
	var raw_path: String = ""
	var feagi_path: String = ""
	if typeof(md) == TYPE_DICTIONARY:
		raw_path = str(md.get("raw", ""))
		feagi_path = str(md.get("feagi", ""))
	if raw_path == "" and feagi_path == "":
		return
	_init_agent_video_shm_dual(raw_path, feagi_path)



func _open_video_shm_path(path: String) -> Variant:
	if not ClassDB.class_exists("SharedMemVideo"):
		print("𒓉 [Preview] SharedMemVideo not available; cannot open ", path)
		return null
	var obj = ClassDB.instantiate("SharedMemVideo")
	if obj and obj.open(path):
		return obj
	else:
		print("𒓉 [Preview] Failed to open SHM (agent selection): ", path)
		return null

func _try_open_video_once(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		_video_last_error = "file does not exist"
		return null
	if not ClassDB.class_exists("SharedMemVideo"):
		_video_last_error = "SharedMemVideo not available"
		return null
	# Probe header readiness
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		_video_last_error = "cannot open file"
		return null
	var fsize := f.get_length()
	if fsize < 256:
		_video_last_error = "header too small (" + str(fsize) + ") at path: " + path
		return null
	f.seek(0)
	var magic_bytes := f.get_buffer(8)
	var magic_hex := magic_bytes.hex_encode()
	# 'FEAGIVID' in hex = 4645414749564944
	if magic_hex != "4645414749564944":
		_video_last_error = "invalid magic (" + magic_hex + ")"
		return null
	var obj = ClassDB.instantiate("SharedMemVideo")
	if obj and obj.open(path):
		var info: Dictionary = obj.get_header_info()
		print("𒓉 [Preview] Opened SHM (agent): ", path, " header=", info)
		return obj
	_video_last_error = "open() returned false"
	return null

func _init_agent_video_shm_dual(raw_path: String, feagi_path: String) -> void:
	_video_init_attempts = 0
	_video_last_error = ""
	for i in range(_video_init_max_attempts):
		_video_init_attempts = i + 1
		var raw_obj: Variant = null
		var feagi_obj: Variant = null
		if raw_path != "":
			raw_obj = _try_open_video_once(raw_path)
		if feagi_path != "":
			feagi_obj = _try_open_video_once(feagi_path)
		if raw_obj != null or feagi_obj != null:
			_shm_reader_raw = raw_obj
			_shm_reader_feagi = feagi_obj
			_use_shared_mem = true
			_shm_status.text = "SHM: video preview (agent)"
			set_process(true)
			_update_container_to_content()
			return
		print("𒓉 [Preview] SHM try ", _video_init_attempts, "/", _video_init_max_attempts, ": ", _video_last_error)
		await get_tree().create_timer(0.25).timeout
	print("𒓉 [Preview] SHM activation failed after ", _video_init_max_attempts, " attempts; last_error=", _video_last_error)

func _crop_half(tex: Texture2D, left_half: bool) -> Texture2D:
	if tex == null:
		return tex
	var sz: Vector2i = tex.get_size()
	if sz.x <= 1:
		return tex
	var half_w: int = int(sz.x / 2)
	var rect: Rect2i = Rect2i(0, 0, half_w, sz.y) if left_half else Rect2i(sz.x - half_w, 0, half_w, sz.y)
	var img: Image = tex.get_image()
	if img == null:
		return tex
	var cropped: Image = img.get_region(rect)
	var out_tex: ImageTexture = ImageTexture.create_from_image(cropped)
	return out_tex

func _update_container_to_content() -> void:
	# Set preview viewport to 1/5 of active screen and allow scroll
	var screen_size: Vector2 = DisplayServer.window_get_size()
	var default_view: Vector2 = screen_size / 5.0
	if _visual_preview.texture:
		var tex_sz: Vector2 = _visual_preview.texture.get_size()
		# Apply current scale factor
		var scaled: Vector2 = Vector2(tex_sz.x * float(SCALAR_RES.x * _resolution_scalar_dyn.x), tex_sz.y * float(SCALAR_RES.y * _resolution_scalar_dyn.y))
		# Content should reflect full scaled size; viewport is clamped via Scroll
		_visual_preview.custom_minimum_size = scaled
		_preview_container.custom_minimum_size = scaled
		var sc: ScrollContainer = _window_internals.get_node_or_null("Scroll")
		if sc:
			var view_size: Vector2 = _user_view_size if _user_view_size != Vector2.ZERO else default_view
			sc.custom_minimum_size = view_size
			# Ensure the outer window width tracks the viewport width so the titlebar matches
			if is_instance_valid(_window_panel):
				_window_panel.custom_minimum_size = Vector2(view_size.x + float(_window_border_pad), _window_panel.custom_minimum_size.y)
			# Also set this window's minimum size to drive the titlebar width
			custom_minimum_size = Vector2(view_size.x + float(_window_border_pad), custom_minimum_size.y)
			if is_instance_valid(_titlebar):
				_titlebar.custom_minimum_size = Vector2(view_size.x + float(_window_border_pad), _titlebar.custom_minimum_size.y)
		

func _gui_input(event):
	# Handle bottom-right corner resize
	if event is InputEventMouseMotion:
		var local_pos: Vector2 = get_local_mouse_position()
		var near_corner: bool = local_pos.x >= size.x - _resize_margin and local_pos.y >= size.y - _resize_margin
		mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE if near_corner else Control.CURSOR_ARROW
		if _resizing:
			var delta: Vector2 = get_global_mouse_position() - _resize_start_mouse
			var new_size: Vector2 = _resize_start_size + delta
			new_size.x = max(160.0, new_size.x)
			new_size.y = max(120.0, new_size.y)
			_user_view_size = new_size
			_update_container_to_content()
			accept_event()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var local_pos2: Vector2 = get_local_mouse_position()
				var on_corner: bool = local_pos2.x >= size.x - _resize_margin and local_pos2.y >= size.y - _resize_margin
				if on_corner:
					_resizing = true
					_resize_start_mouse = get_global_mouse_position()
					var sc2: ScrollContainer = _window_internals.get_node_or_null("Scroll")
					_resize_start_size = sc2.custom_minimum_size if sc2 else Vector2.ZERO
					accept_event()
			else:
				_resizing = false
				accept_event()

func _position_resize_handle() -> void:
	if _resize_handle == null:
		return
	var r: Rect2 = _window_panel.get_global_rect() if is_instance_valid(_window_panel) else get_global_rect()
	var margin: Vector2 = Vector2(4, 4)
	var pos: Vector2 = r.position + r.size - _resize_handle.size - margin
	_resize_handle.global_position = pos

func _on_view_toggle_selected(index: int) -> void:
	# Show segmentation controls only for FEAGI view
	if _seg_controls:
		_seg_controls.visible = (index == 1)
	if is_instance_valid(_seg_overlay):
		_seg_overlay.visible = (index == 1)
		_seg_overlay.queue_redraw()
	# Apply per-view scale when switching
	_apply_current_scale()

func _on_seg_value_changed(_val: float) -> void:
	if _ecc_val_label:
		_ecc_val_label.text = "(%.2f, %.2f)" % [_eccx_slider.value, _eccy_slider.value]
	if _mod_val_label:
		_mod_val_label.text = "(%.2f, %.2f)" % [_modx_slider.value, _mody_slider.value]
	if is_instance_valid(_seg_overlay):
		_seg_overlay.queue_redraw()

func _on_apply_segmentation() -> void:
	# UI-only for now: log the intended values. Backend will send via motor stream later.
	print("𒓉 [SegCtl] Apply eccentricity=(", str(_eccx_slider.value), ", ", str(_eccy_slider.value), ") modularity=(", str(_modx_slider.value), ", ", str(_mody_slider.value), ")")
	_send_segmentation_to_feagi()

func _on_reset_segmentation() -> void:
	_eccx_slider.value = _default_ecc.x
	_eccy_slider.value = _default_ecc.y
	_modx_slider.value = _default_mod.x
	_mody_slider.value = _default_mod.y
	_on_seg_value_changed(0.0)

func _send_segmentation_to_feagi() -> void:
	# Use existing manual stimulation endpoint to transmit control signals for oecc00 and omod00
	if not FeagiCore or not FeagiCore.network or not FeagiCore.network.http_API:
		push_warning("SegCtl: HTTP API not available")
		return
	var eccx: float = clamp(_eccx_slider.value, 0.0, 1.0)
	var eccy: float = clamp(_eccy_slider.value, 0.0, 1.0)
	var modx: float = clamp(_modx_slider.value, 0.0, 1.0)
	var mody: float = clamp(_mody_slider.value, 0.0, 1.0)
	# Encode as simple Z-channels at origin (x=0,y=0): z=0 holds X, z=1 holds Y
	var stim: Dictionary = {}
	stim["oecc00"] = [[0,0,0],[0,0,1]]
	stim["omod00"] = [[0,0,0],[0,0,1]]
	var payload: Dictionary = {"stimulation_payload": stim}
	print("𒓉 [SegCtl] Sending control stimulation payload: ", payload)
	var def: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_POST_call(FeagiCore.network.http_API.address_list.POST_agent_manualStimulation, payload)
	var worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(def)
	await worker.worker_done
	var out: FeagiRequestOutput = worker.retrieve_output_and_close()
	if out.has_errored or out.has_timed_out:
		push_warning("SegCtl: stimulation send failed")
	else:
		print("𒓉 [SegCtl] Stimulation sent OK")

func _on_resize_handle_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_resizing = true
			_resize_start_mouse = get_global_mouse_position()
			var sc: ScrollContainer = _window_internals.get_node_or_null("Scroll")
			_resize_start_size = sc.custom_minimum_size if sc else Vector2.ZERO
			accept_event()
		else:
			_resizing = false
			accept_event()
	elif event is InputEventMouseMotion and _resizing:
		var delta: Vector2 = get_global_mouse_position() - _resize_start_mouse
		var new_size: Vector2 = _resize_start_size + delta
		new_size.x = max(160.0, new_size.x)
		new_size.y = max(120.0, new_size.y)
		_user_view_size = new_size
		_update_container_to_content()
		accept_event()
		if is_instance_valid(_seg_overlay):
			_seg_overlay.queue_redraw()
func _fallback_to_websocket() -> void:
	print("[Preview] Using WebSocket visualization stream")
	FeagiCore.network.websocket_API.feagi_return_visual_data.connect(_update_preview_texture_from_raw_data)
	if is_instance_valid(_seg_overlay):
		_seg_overlay.queue_redraw()

# Helper getters for overlay callables
func _get_eccentricity() -> Vector2:
	return Vector2(_eccx_slider.value, _eccy_slider.value)

func _get_modulation() -> Vector2:
	return Vector2(_modx_slider.value, _mody_slider.value)

func _is_feagi_view() -> bool:
	return _view_toggle and _view_toggle.selected == 1

func _on_preview_rect_changed() -> void:
	if is_instance_valid(_seg_overlay):
		_seg_overlay.queue_redraw()

func _setup_scale_buttons() -> void:
	# Create or populate a row of scale buttons (1x..4x) above segmentation
	var container_parent: Control = _window_internals
	var insertion_index: int = -1
	if _seg_controls and _seg_controls.get_parent() == _window_internals:
		insertion_index = _window_internals.get_children().find(_seg_controls)
	# Use existing sizes container if present; repurpose it directly to avoid duplicates
	if _buttons and _buttons is HBoxContainer:
		_scale_row = _buttons
		# Remove any pre-existing scale UI (legacy buttons/labels)
		for child in _scale_row.get_children():
			if child is Button or child is Label or (child is Control and (child as Control).name == "ScaleButtons"):
				(child as Node).queue_free()
		_buttons.visible = true
	else:
		# If there is no dedicated sizes container, create a single ScaleButtons row (only once)
		_scale_row = _window_internals.get_node_or_null("ScaleButtons") as HBoxContainer
		if _scale_row == null:
			_scale_row = HBoxContainer.new()
			_scale_row.name = "ScaleButtons"
			_scale_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if insertion_index >= 0:
				_window_internals.add_child(_scale_row)
				_window_internals.move_child(_scale_row, insertion_index)
			else:
				_window_internals.add_child(_scale_row)
		else:
			for child in _scale_row.get_children():
				(child as Node).queue_free()
	# Add scale buttons: 1/2x, 1x, 2x, 4x, 8x
	var lbl := Label.new()
	lbl.text = "Scale:"
	_scale_row.add_child(lbl)
	var entries := [0.5, 1.0, 2.0, 4.0, 8.0]
	for s in entries:
		var b := Button.new()
		if s < 1.0:
			var denom := int(round(1.0 / s))
			b.text = "1/" + str(denom) + "x"
		else:
			b.text = str(int(s)) + "x"
		b.toggle_mode = false
		b.pressed.connect(_on_scale_button.bind(s))
		_scale_row.add_child(b)

func _on_scale_button(scalar: float) -> void:
	_scale_button_pressed(scalar)
