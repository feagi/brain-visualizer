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
var _resolution_scalar_dyn: Vector2i = Vector2i(1,1)

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

func _ready():
	super()
	print("[Preview] _ready(): initializing View Previews window")
	_resolution_UI = _window_internals.get_node("HBoxContainer/resolution")
	# After wrapping preview in a ScrollContainer, path changes
	_preview_container = _window_internals.get_node("Scroll/PanelContainer")
	_visual_preview = _window_internals.get_node("Scroll/PanelContainer/MarginContainer/TextureRect")
	_buttons = _window_internals.get_node("sizes")
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
	
func _update_scale_size() -> void:
	_visual_preview.custom_minimum_size = _current_resolution * SCALAR_RES * _resolution_scalar_dyn
	_update_container_to_content()

func _scale_button_pressed(scalar: int) -> void: # set with custom arguments from TSCN signal
	_resolution_scalar_dyn = Vector2i(scalar, scalar)
	_update_scale_size()
	
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
func _fallback_to_websocket() -> void:
	print("[Preview] Using WebSocket visualization stream")
	FeagiCore.network.websocket_API.feagi_return_visual_data.connect(_update_preview_texture_from_raw_data)
		
