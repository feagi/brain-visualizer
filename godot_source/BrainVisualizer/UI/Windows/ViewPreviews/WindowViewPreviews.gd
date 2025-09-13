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

# cache
var _current_resolution: Vector2i = Vector2i(0,0)
var _preview_image: Image = Image.new()
var _preview_image_texture: ImageTexture = ImageTexture.new()
var _resolution_scalar_dyn: Vector2i = Vector2i(1,1)

# Shared memory video support (desktop preview via SharedMemVideo GDExtension)
var _use_shared_mem: bool = false
var _shm_reader: Variant = null # Use Variant to avoid hard dependency if extension missing

func _ready():
	super()
	print("[Preview] _ready(): initializing View Previews window")
	_resolution_UI = _window_internals.get_node("HBoxContainer/resolution")
	_preview_container = _window_internals.get_node("PanelContainer")
	_visual_preview = _window_internals.get_node("PanelContainer/MarginContainer/TextureRect")
	_buttons = _window_internals.get_node("sizes")
	_shm_status = _window_internals.get_node("SHMStatus")
	_view_toggle = _window_internals.get_node("SHMControls/ViewToggle")
	# Setup toggle options: 0=Raw, 1=FEAGI
	_view_toggle.clear()
	_view_toggle.add_item("Raw", 0)
	_view_toggle.add_item("FEAGI", 1)
	_view_toggle.selected = 0
	# Try core SHM path via environment (provided by FEAGI launcher)
	print("𒓉 [Preview] _ready(): attempting FEAGI_VIZ_SHM shared-memory setup")
	_try_open_core_visualization_shm()
	
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
		_shm_reader = obj
		if _shm_reader and _shm_reader.open(shm_path):
			var info: Dictionary = _shm_reader.get_header_info()
			print("𒓉 [Preview] Using shared memory (FEAGI_VIDEO_SHM): ", shm_path)
			print("𒓉 [Preview] SharedMemVideo header:", info)
			_shm_status.text = "SHM: opened"
			_use_shared_mem = true
			set_process(true)
			return
		else:
			var reason := "open() returned false"
			if _shm_reader == null:
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
	if not _use_shared_mem:
		return
	if _shm_reader == null:
		return
	var tex: ImageTexture = _shm_reader.get_texture()
	if tex:
		# Update resolution and UI on first frame or when dimensions change
		var size: Vector2i = tex.get_size()
		if size != _current_resolution:
			_update_resolution(size)
		# Apply view: left=Raw, right=FEAGI
		var display_tex: ImageTexture = tex
		if _view_toggle.selected == 0:
			# Raw: left half
			display_tex = _crop_half(display_tex, true)
		elif _view_toggle.selected == 1:
			# FEAGI: right half
			display_tex = _crop_half(display_tex, false)
		_visual_preview.texture = display_tex
		_update_container_to_content()
	else:
		# Poll header info for debugging
		var info: Dictionary = _shm_reader.get_header_info()
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
			_shm_reader = obj_v
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
			_shm_reader = obj
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
	print("𒓉 [Preview] Querying /v1/agent/shared_mem for video preview…")
	await worker.worker_done
	var out = worker.retrieve_output_and_close()
	if out.has_errored or out.has_timed_out:
		return
	var resp: Variant = out.decode_response_as_dict()
	if typeof(resp) != TYPE_DICTIONARY:
		return
	# Heuristic: prefer agents whose id contains 'video-agent' and mapping has 'video_stream'
	var chosen_path: String = ""
	var chosen_agent: String = ""
	for aid in resp.keys():
		var mapping = resp[aid]
		if typeof(mapping) != TYPE_DICTIONARY:
			continue
		var path: String = ""
		if mapping.has("video_stream"):
			path = str(mapping["video_stream"])
		elif mapping.has("video_preview_shared_mem_path"):
			path = str(mapping["video_preview_shared_mem_path"])
		if path == "":
			continue
		# Prefer video-agent*; otherwise first available
		if chosen_path == "" or (aid is String and aid.findn("video-agent") != -1):
			chosen_path = path
			chosen_agent = str(aid)
			if aid.findn("video-agent") != -1:
				break
	if chosen_path != "":
		var obj = ClassDB.instantiate("SharedMemVideo")
		if obj and obj.open(chosen_path):
			_shm_reader = obj
			_use_shared_mem = true
			_shm_status.text = "SHM: video preview (API)"
			print("𒓉 [Preview] Using SHM from API for agent ", chosen_agent, ": ", chosen_path)
			set_process(true)
			_update_container_to_content()

func _crop_half(tex: ImageTexture, left_half: bool) -> ImageTexture:
	if tex == null:
		return tex
	var img: Image = tex.get_image()
	if img == null:
		return tex
	var w: int = img.get_width()
	var h: int = img.get_height()
	if w <= 1:
		return tex
	var half_w: int = int(w / 2)
	var rect: Rect2i
	if left_half:
		rect = Rect2i(0, 0, half_w, h)
	else:
		rect = Rect2i(w - half_w, 0, half_w, h)
	# Godot 4: use get_region() to crop an Image
	var cropped: Image = img.get_region(rect)
	var out_tex: ImageTexture = ImageTexture.create_from_image(cropped)
	return out_tex

func _update_container_to_content() -> void:
	# Clamp the preview panel width/height to the current texture size (+ small padding)
	if _visual_preview.texture:
		var sz: Vector2 = _visual_preview.texture.get_size()
		# Apply current scale factor
		sz = Vector2(sz.x * float(SCALAR_RES.x * _resolution_scalar_dyn.x), sz.y * float(SCALAR_RES.y * _resolution_scalar_dyn.y))
		# Set minimum size on the TextureRect and its parent panel to content
		_visual_preview.custom_minimum_size = sz
		_preview_container.custom_minimum_size = sz + Vector2(8, 8)
		
func _fallback_to_websocket() -> void:
	print("[Preview] Using WebSocket visualization stream")
	FeagiCore.network.websocket_API.feagi_return_visual_data.connect(_update_preview_texture_from_raw_data)
		
