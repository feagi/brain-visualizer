extends BaseDraggableWindow
class_name WindowViewPreviews

const WINDOW_NAME: StringName = "view_previews"
const MIN_PANEL_WIDTH: int = 200
const DEFAULT_WINDOW_SIZE: Vector2 = Vector2(1200, 600)

# UI References - Shared
var _shm_status: Label
var _agent_dropdown: OptionButton
var _refresh_btn: Button
var _split_container: HSplitContainer

# Window resizing
var _resize_handle: Panel
var _resizing: bool = false
var _resize_start_mouse: Vector2 = Vector2.ZERO
var _resize_start_size: Vector2 = Vector2.ZERO
var _resize_margin: int = 16

# UI References - Raw Video Panel
var _raw_resolution_label: Label
var _raw_aspect_label: Label
var _raw_fps_label: Label
var _raw_texture_rect: TextureRect
var _raw_placeholder: Label

# UI References - FEAGI Preview Panel
var _feagi_resolution_label: Label
var _feagi_aspect_label: Label
var _feagi_fps_label: Label
var _feagi_texture_rect: TextureRect
var _feagi_placeholder: Label

# FPS tracking
var _fps_raw: float = 0.0
var _fps_feagi: float = 0.0
var _frame_times_raw: Array = []
var _frame_times_feagi: Array = []
var _last_frame_time_raw: int = 0
var _last_frame_time_feagi: int = 0
var _last_frame_seq_raw: int = -1
var _last_frame_seq_feagi: int = -1
const FPS_WINDOW_SIZE: int = 30  # Average over last 30 frames

# Agent → video_stream mapping
var _agent_video_map: Dictionary = {}
var _agent_video_map_feagi: Dictionary = {}

# Retry state for opening selected agent SHM
var _video_init_attempts: int = 0
var _video_init_max_attempts: int = 40
var _video_last_error: String = ""
var _is_refreshing: bool = false

# Shared memory video support (desktop preview via SharedMemVideo GDExtension)
var _use_shared_mem: bool = false
var _shm_reader_raw: Variant = null # Use Variant to avoid hard dependency if extension missing
var _shm_reader_feagi: Variant = null

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

# Image Pre-Processing UI controls
var _preproc_controls: VBoxContainer
var _brightness_slider: HSlider
var _contrast_slider: HSlider
var _grayscale_check: CheckButton
var _brightness_val_label: Label
var _contrast_val_label: Label
var _preproc_apply_btn: Button
var _preproc_reset_btn: Button

# Motion Detection UI controls
var _motion_controls: VBoxContainer
var _pixdiff_slider: HSlider
var _receptive_slider: HSlider
var _motion_intensity_slider: HSlider
var _min_blob_slider: HSlider
var _pixdiff_val_label: Label
var _receptive_val_label: Label
var _motion_intensity_val_label: Label
var _min_blob_val_label: Label
var _motion_apply_btn: Button
var _motion_reset_btn: Button

# Local overlay class that draws red guide lines showing 3x3 segmentation
class SegOverlay:
	extends Control
	var get_eccentricity: Callable
	var get_modulation: Callable

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
	print("[Preview] _ready(): initializing split-view View Previews window")
	
	# Get UI references
	_shm_status = _window_internals.get_node("SHMStatus")
	_agent_dropdown = _window_internals.get_node("SHMControls/AgentDropdown")
	
	# Create Refresh button next to AgentDropdown
	var _shm_controls: Node = _window_internals.get_node_or_null("SHMControls")
	if _shm_controls:
		_refresh_btn = Button.new()
		_refresh_btn.name = "RefreshButton"
		_refresh_btn.text = "Refresh"
		_refresh_btn.tooltip_text = "Refresh agents with video streams"
		_shm_controls.add_child(_refresh_btn)
		_refresh_btn.pressed.connect(_on_refresh_clicked)
	
	if _agent_dropdown:
		_agent_dropdown.clear()
		_agent_dropdown.add_item("Select agent…")
		_agent_dropdown.disabled = true
		_agent_dropdown.item_selected.connect(_on_agent_dropdown_selected)
	
	# Get Raw Video Panel references
	var raw_panel = _window_internals.get_node("SplitViewContainer/RawVideoPanel")
	_raw_resolution_label = raw_panel.get_node("RawHeader/RawHeaderMargin/RawHeaderInfo/RawResolution")
	_raw_aspect_label = raw_panel.get_node("RawHeader/RawHeaderMargin/RawHeaderInfo/RawAspect")
	_raw_fps_label = raw_panel.get_node("RawHeader/RawHeaderMargin/RawHeaderInfo/RawFPS")
	_raw_texture_rect = raw_panel.get_node("RawScroll/RawViewport/RawMargin/RawTextureRect")
	_raw_placeholder = raw_panel.get_node("RawScroll/RawViewport/RawMargin/RawPlaceholder")
	
	# Get FEAGI Preview Panel references
	var feagi_panel = _window_internals.get_node("SplitViewContainer/FeagiVideoPanel")
	_feagi_resolution_label = feagi_panel.get_node("FeagiHeader/FeagiHeaderMargin/FeagiHeaderInfo/FeagiResolution")
	_feagi_aspect_label = feagi_panel.get_node("FeagiHeader/FeagiHeaderMargin/FeagiHeaderInfo/FeagiAspect")
	_feagi_fps_label = feagi_panel.get_node("FeagiHeader/FeagiHeaderMargin/FeagiHeaderInfo/FeagiFPS")
	_feagi_texture_rect = feagi_panel.get_node("FeagiScroll/FeagiViewport/FeagiMargin/FeagiTextureRect")
	_feagi_placeholder = feagi_panel.get_node("FeagiScroll/FeagiViewport/FeagiMargin/FeagiPlaceholder")
	
	# Inject segmentation overlay over the RAW video texture (not FEAGI)
	_seg_overlay = SegOverlay.new()
	_seg_overlay.get_eccentricity = Callable(self, "_get_eccentricity")
	_seg_overlay.get_modulation = Callable(self, "_get_modulation")
	_raw_texture_rect.add_child(_seg_overlay)
	_seg_overlay.visible = true
	
	# React to texture changes (resolution/frame) to keep overlay aligned
	_raw_texture_rect.item_rect_changed.connect(_on_raw_preview_rect_changed)

	# Build segmentation UI as its own row (full width)
	_seg_controls = VBoxContainer.new()
	_seg_controls.name = "SegControls"
	_seg_controls.visible = true
	_seg_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seg_controls.custom_minimum_size = Vector2(0, 56)
	_window_internals.add_child(_seg_controls)

	# Title (Gaze Control)
	var spacer_gc := Control.new(); spacer_gc.custom_minimum_size = Vector2(0, 8); _window_internals.add_child(spacer_gc)
	var title := Label.new()
	title.text = "Gaze Control (FEAGI):"
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

	# Image Pre-Processing group
	var spacer_pre := Control.new(); spacer_pre.custom_minimum_size = Vector2(0, 8); _window_internals.add_child(spacer_pre)
	_preproc_controls = VBoxContainer.new()
	_preproc_controls.name = "PreProcControls"
	_preproc_controls.visible = true
	_preproc_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preproc_controls.custom_minimum_size = Vector2(0, 56)
	_window_internals.add_child(_preproc_controls)
	var ptitle := Label.new(); ptitle.text = "Image Pre-Processing:"; _preproc_controls.add_child(ptitle)
	# Brightness row
	var br_row := HBoxContainer.new(); br_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var br_lbl := Label.new(); br_lbl.text = "Brightness"
	_brightness_slider = HSlider.new(); _brightness_slider.min_value = -1.0; _brightness_slider.max_value = 1.0; _brightness_slider.step = 0.01; _brightness_slider.value = 0.0; _brightness_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _brightness_slider.custom_minimum_size = Vector2(160, 0)
	_brightness_val_label = Label.new(); _brightness_val_label.text = "0.00"
	br_row.add_child(br_lbl); br_row.add_child(_brightness_slider); br_row.add_child(_brightness_val_label); _preproc_controls.add_child(br_row)
	# Contrast row
	var ct_row := HBoxContainer.new(); ct_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ct_lbl := Label.new(); ct_lbl.text = "Contrast"
	_contrast_slider = HSlider.new(); _contrast_slider.min_value = 0.0; _contrast_slider.max_value = 2.0; _contrast_slider.step = 0.01; _contrast_slider.value = 1.0; _contrast_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _contrast_slider.custom_minimum_size = Vector2(160, 0)
	_contrast_val_label = Label.new(); _contrast_val_label.text = "1.00"
	ct_row.add_child(ct_lbl); ct_row.add_child(_contrast_slider); ct_row.add_child(_contrast_val_label); _preproc_controls.add_child(ct_row)
	# Grayscale row
	var gs_row := HBoxContainer.new(); gs_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var gs_lbl := Label.new(); gs_lbl.text = "Color to grayscale"
	_grayscale_check = CheckButton.new(); _grayscale_check.button_pressed = false
	gs_row.add_child(gs_lbl); gs_row.add_child(_grayscale_check); _preproc_controls.add_child(gs_row)
	# Buttons
	var pbtn_row := HBoxContainer.new(); _preproc_apply_btn = Button.new(); _preproc_apply_btn.text = "Apply"; _preproc_reset_btn = Button.new(); _preproc_reset_btn.text = "Reset"; pbtn_row.add_child(_preproc_apply_btn); pbtn_row.add_child(_preproc_reset_btn); _preproc_controls.add_child(pbtn_row)

	# Motion Detection group
	var spacer_mo := Control.new(); spacer_mo.custom_minimum_size = Vector2(0, 8); _window_internals.add_child(spacer_mo)
	_motion_controls = VBoxContainer.new(); _motion_controls.name = "MotionControls"; _motion_controls.visible = true; _motion_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _motion_controls.custom_minimum_size = Vector2(0, 56)
	_window_internals.add_child(_motion_controls)
	var mtitle := Label.new(); mtitle.text = "Motion Detection:"; _motion_controls.add_child(mtitle)
	# Pixel intensity difference
	var pd_row := HBoxContainer.new(); pd_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pd_lbl := Label.new(); pd_lbl.text = "Pixel intensity difference"
	_pixdiff_slider = HSlider.new(); _pixdiff_slider.min_value = 0.0; _pixdiff_slider.max_value = 1.0; _pixdiff_slider.step = 0.01; _pixdiff_slider.value = 0.15; _pixdiff_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _pixdiff_slider.custom_minimum_size = Vector2(160, 0)
	_pixdiff_val_label = Label.new(); _pixdiff_val_label.text = "0.15"
	pd_row.add_child(pd_lbl); pd_row.add_child(_pixdiff_slider); pd_row.add_child(_pixdiff_val_label); _motion_controls.add_child(pd_row)
	# Receptive field
	var rf_row := HBoxContainer.new(); rf_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rf_lbl := Label.new(); rf_lbl.text = "Receptive field"
	_receptive_slider = HSlider.new(); _receptive_slider.min_value = 1; _receptive_slider.max_value = 64; _receptive_slider.step = 1; _receptive_slider.value = 8; _receptive_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _receptive_slider.custom_minimum_size = Vector2(160, 0)
	_receptive_val_label = Label.new(); _receptive_val_label.text = "8"
	rf_row.add_child(rf_lbl); rf_row.add_child(_receptive_slider); rf_row.add_child(_receptive_val_label); _motion_controls.add_child(rf_row)
	# Motion intensity
	var mi_row := HBoxContainer.new(); mi_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mi_lbl := Label.new(); mi_lbl.text = "Motion intensity"
	_motion_intensity_slider = HSlider.new(); _motion_intensity_slider.min_value = 0.0; _motion_intensity_slider.max_value = 1.0; _motion_intensity_slider.step = 0.01; _motion_intensity_slider.value = 0.5; _motion_intensity_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _motion_intensity_slider.custom_minimum_size = Vector2(160, 0)
	_motion_intensity_val_label = Label.new(); _motion_intensity_val_label.text = "0.50"
	mi_row.add_child(mi_lbl); mi_row.add_child(_motion_intensity_slider); mi_row.add_child(_motion_intensity_val_label); _motion_controls.add_child(mi_row)
	# Minimum blob size
	var mb_row := HBoxContainer.new(); mb_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mb_lbl := Label.new(); mb_lbl.text = "Minimum blob size"
	_min_blob_slider = HSlider.new(); _min_blob_slider.min_value = 1; _min_blob_slider.max_value = 1024; _min_blob_slider.step = 1; _min_blob_slider.value = 16; _min_blob_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _min_blob_slider.custom_minimum_size = Vector2(160, 0)
	_min_blob_val_label = Label.new(); _min_blob_val_label.text = "16"
	mb_row.add_child(mb_lbl); mb_row.add_child(_min_blob_slider); mb_row.add_child(_min_blob_val_label); _motion_controls.add_child(mb_row)
	# Buttons
	var mbtn_row := HBoxContainer.new(); _motion_apply_btn = Button.new(); _motion_apply_btn.text = "Apply"; _motion_reset_btn = Button.new(); _motion_reset_btn.text = "Reset"; mbtn_row.add_child(_motion_apply_btn); mbtn_row.add_child(_motion_reset_btn); _motion_controls.add_child(mbtn_row)

	# Wire signals
	_eccx_slider.value_changed.connect(_on_seg_value_changed)
	_eccy_slider.value_changed.connect(_on_seg_value_changed)
	_modx_slider.value_changed.connect(_on_seg_value_changed)
	_mody_slider.value_changed.connect(_on_seg_value_changed)
	_apply_btn.pressed.connect(_on_apply_segmentation)
	_reset_btn.pressed.connect(_on_reset_segmentation)
	# Wire new UI signals
	_brightness_slider.value_changed.connect(_on_preproc_value_changed)
	_contrast_slider.value_changed.connect(_on_preproc_value_changed)
	_grayscale_check.toggled.connect(func(_pressed: bool): _on_preproc_value_changed(0.0))
	_preproc_apply_btn.pressed.connect(_on_apply_preproc)
	_preproc_reset_btn.pressed.connect(_on_reset_preproc)
	_pixdiff_slider.value_changed.connect(_on_motion_value_changed)
	_receptive_slider.value_changed.connect(_on_motion_value_changed)
	_motion_intensity_slider.value_changed.connect(_on_motion_value_changed)
	_min_blob_slider.value_changed.connect(_on_motion_value_changed)
	_motion_apply_btn.pressed.connect(_on_apply_motion)
	_motion_reset_btn.pressed.connect(_on_reset_motion)
	
	# Get split container reference
	_split_container = _window_internals.get_node("SplitViewContainer")
	
	# Set initial window size
	custom_minimum_size = DEFAULT_WINDOW_SIZE
	size = DEFAULT_WINDOW_SIZE
	
	# Create resize handle with visual indicator
	_resize_handle = Panel.new()
	_resize_handle.name = "ResizeHandle"
	_resize_handle.custom_minimum_size = Vector2(_resize_margin, _resize_margin)
	_resize_handle.mouse_filter = Control.MOUSE_FILTER_PASS
	_resize_handle.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	_resize_handle.gui_input.connect(_on_resize_handle_gui_input)
	
	# Add visual grip lines indicator
	var grip_icon := Control.new()
	grip_icon.name = "GripIcon"
	grip_icon.custom_minimum_size = Vector2(_resize_margin, _resize_margin)
	grip_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grip_icon.draw.connect(_draw_resize_grip.bind(grip_icon))
	_resize_handle.add_child(grip_icon)
	
	add_child(_resize_handle)
	_resize_handle.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_resize_handle.offset_left = -_resize_margin
	_resize_handle.offset_top = -_resize_margin
	_resize_handle.z_index = 1000
	
	# Populate agents with video streams
	_try_fetch_video_shm_from_api()
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
	_fallback_to_websocket()

func _process(_dt: float) -> void:
	if not _use_shared_mem:
		return
	
	var current_time: int = Time.get_ticks_msec()
	
	# Poll BOTH readers every frame to prevent stale buffers
	var tex_raw: Texture2D = null
	var tex_feagi: Texture2D = null
	
	if _shm_reader_raw != null:
		tex_raw = _shm_reader_raw.get_texture()
		# Track FPS independently of texture display
		var info_raw: Dictionary = _shm_reader_raw.get_header_info()
		var frame_seq: int = int(info_raw.get("frame_seq", -1))
		# Detect restart: frame_seq jumped backward (writer restarted)
		if frame_seq >= 0 and frame_seq < _last_frame_seq_raw:
			print("𒓉 [Preview] Raw video restart detected (seq %d -> %d), reopening SHM..." % [_last_frame_seq_raw, frame_seq])
			_last_frame_seq_raw = -1  # Reset to detect new frames
			_frame_times_raw.clear()
			_fps_raw = 0.0
			_last_frame_time_raw = 0
			# Close and reopen the SHM file to get new memory mapping
			var old_path: String = _shm_reader_raw.get_path()
			_shm_reader_raw = null  # Close old mapping
			if old_path != "":
				await get_tree().create_timer(0.1).timeout  # Brief delay for file recreation
				var new_reader = _try_open_video_once(old_path)
				if new_reader != null:
					_shm_reader_raw = new_reader
					print("𒓉 [Preview] Raw video SHM reopened successfully")
				else:
					print("⚠️ [Preview] Failed to reopen raw video SHM: ", _video_last_error)
		if frame_seq != _last_frame_seq_raw and frame_seq >= 0:
			_update_fps_tracker(true, current_time, frame_seq)
	
	if _shm_reader_feagi != null:
		tex_feagi = _shm_reader_feagi.get_texture()
		# Track FPS independently of texture display
		var info_feagi: Dictionary = _shm_reader_feagi.get_header_info()
		var frame_seq: int = int(info_feagi.get("frame_seq", -1))
		# Detect restart: frame_seq jumped backward (writer restarted)
		if frame_seq >= 0 and frame_seq < _last_frame_seq_feagi:
			print("𒓉 [Preview] FEAGI video restart detected (seq %d -> %d), reopening SHM..." % [_last_frame_seq_feagi, frame_seq])
			_last_frame_seq_feagi = -1  # Reset to detect new frames
			_frame_times_feagi.clear()
			_fps_feagi = 0.0
			_last_frame_time_feagi = 0
			# Close and reopen the SHM file to get new memory mapping
			var old_path: String = _shm_reader_feagi.get_path()
			_shm_reader_feagi = null  # Close old mapping
			if old_path != "":
				await get_tree().create_timer(0.1).timeout  # Brief delay for file recreation
				var new_reader = _try_open_video_once(old_path)
				if new_reader != null:
					_shm_reader_feagi = new_reader
					print("𒓉 [Preview] FEAGI video SHM reopened successfully")
				else:
					print("⚠️ [Preview] Failed to reopen FEAGI video SHM: ", _video_last_error)
		if frame_seq != _last_frame_seq_feagi and frame_seq >= 0:
			_update_fps_tracker(false, current_time, frame_seq)
	
	# Update Raw Video Panel
	if tex_raw:
		_raw_texture_rect.texture = tex_raw
		_raw_placeholder.visible = false
		_update_stream_info(true, tex_raw.get_size(), _fps_raw)
	else:
		_raw_placeholder.visible = true
		_update_stream_info(true, Vector2i.ZERO, 0.0)
	
	# Update FEAGI Preview Panel
	if tex_feagi:
		_feagi_texture_rect.texture = tex_feagi
		_feagi_placeholder.visible = false
		_update_stream_info(false, tex_feagi.get_size(), _fps_feagi)
		if is_instance_valid(_seg_overlay):
			_seg_overlay.queue_redraw()
	else:
		_feagi_placeholder.visible = true
		_update_stream_info(false, Vector2i.ZERO, 0.0)

func _update_stream_info(is_raw: bool, resolution: Vector2i, fps: float) -> void:
	"""Update resolution, aspect ratio, and FPS labels for a stream."""
	var res_label: Label = _raw_resolution_label if is_raw else _feagi_resolution_label
	var aspect_label: Label = _raw_aspect_label if is_raw else _feagi_aspect_label
	var fps_label: Label = _raw_fps_label if is_raw else _feagi_fps_label
	
	if resolution == Vector2i.ZERO:
		res_label.text = "--x--"
		aspect_label.text = "(--:--)"
		fps_label.text = "-- FPS"
	else:
		res_label.text = "%dx%d" % [resolution.x, resolution.y]
		# Calculate aspect ratio (simplified)
		var gcd_val: int = _gcd(resolution.x, resolution.y)
		var aspect_w: int = resolution.x / gcd_val
		var aspect_h: int = resolution.y / gcd_val
		aspect_label.text = "(%d:%d)" % [aspect_w, aspect_h]
		fps_label.text = "%.1f FPS" % fps

func _gcd(a: int, b: int) -> int:
	"""Calculate greatest common divisor for aspect ratio."""
	while b != 0:
		var t: int = b
		b = a % b
		a = t
	return a

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
	# Populate dropdown with agents that have canonical 'video' capability (fallback to legacy keys if present)
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
		# Canonical key: 'video' (agent-owned preview stream)
		var raw_path: String = str(mapping.get("video", ""))
		# FEAGI processed video (segmented mosaic) - try both 'feagi' (new) and 'video_feagi' (legacy)
		var feagi_path: String = str(mapping.get("feagi", ""))
		if feagi_path == "":
			feagi_path = str(mapping.get("video_feagi", ""))
		# Backward compatibility with legacy keys
		if raw_path == "":
			var legacy_raw := str(mapping.get("video_stream_raw", ""))
			var legacy_alt := str(mapping.get("video_stream", ""))
			if legacy_raw != "":
				raw_path = legacy_raw
			elif legacy_alt != "":
				raw_path = legacy_alt
		# Accept if either raw or feagi path is available
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

func _on_refresh_clicked() -> void:
	if _is_refreshing:
		return
	_is_refreshing = true
	if _agent_dropdown:
		_agent_dropdown.disabled = true
	if _shm_status:
		_shm_status.text = "SHM: refreshing…"
	await _try_fetch_video_shm_from_api()
	if _agent_dropdown:
		_agent_dropdown.disabled = false
	_is_refreshing = false
	if not _use_shared_mem and _shm_status:
		_shm_status.text = "SHM: select an agent"

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
	print("𒓉 [Preview] Selected agent paths: raw='%s' feagi='%s'" % [raw_path, feagi_path])
	if raw_path == "" and feagi_path == "":
		return
	_init_agent_video_shm_dual(raw_path, feagi_path)

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
			if raw_obj != null:
				print("𒓉 [Preview] Raw video SHM opened successfully")
			else:
				print("𒓉 [Preview] Raw video SHM failed: ", _video_last_error)
		if feagi_path != "":
			feagi_obj = _try_open_video_once(feagi_path)
			if feagi_obj != null:
				print("𒓉 [Preview] FEAGI video SHM opened successfully")
			else:
				print("𒓉 [Preview] FEAGI video SHM failed: ", _video_last_error)
		
		# Check if we have all required streams
		var raw_ready: bool = (raw_path == "" or raw_obj != null)
		var feagi_ready: bool = (feagi_path == "" or feagi_obj != null)
		
		if raw_ready and feagi_ready:
			_shm_reader_raw = raw_obj
			_shm_reader_feagi = feagi_obj
			_use_shared_mem = true
			_shm_status.text = "SHM: video preview (agent)"
			set_process(true)
			print("𒓉 [Preview] Both SHM streams ready (raw=%s, feagi=%s)" % [str(raw_obj != null), str(feagi_obj != null)])
			return
		print("𒓉 [Preview] SHM try ", _video_init_attempts, "/", _video_init_max_attempts, ": waiting for both streams...")
		await get_tree().create_timer(0.25).timeout
	print("𒓉 [Preview] SHM activation failed after ", _video_init_max_attempts, " attempts; last_error=", _video_last_error)

func _fallback_to_websocket() -> void:
	print("[Preview] Using WebSocket visualization stream")
	FeagiCore.network.websocket_API.feagi_return_visual_data.connect(_update_preview_texture_from_raw_data)

func _update_preview_texture_from_raw_data(bytes: PackedByteArray) -> void:
	# WebSocket fallback: decode and display on FEAGI panel only
	var resolution: Vector2i = Vector2i(bytes.decode_u16(2), bytes.decode_u16(4))
	if resolution == Vector2i(0,0):
		return
	var preview_image: Image = Image.create_empty(resolution.x, resolution.y, false, Image.FORMAT_RGB8)
	preview_image.set_data(resolution.x, resolution.y, false, Image.FORMAT_RGB8, bytes.slice(6))
	var preview_texture: ImageTexture = ImageTexture.create_from_image(preview_image)
	_feagi_texture_rect.texture = preview_texture
	_feagi_placeholder.visible = false
	_update_stream_info(false, resolution, 0.0)

func _on_seg_value_changed(_val: float) -> void:
	if _ecc_val_label:
		_ecc_val_label.text = "(%.2f, %.2f)" % [_eccx_slider.value, _eccy_slider.value]
	if _mod_val_label:
		_mod_val_label.text = "(%.2f, %.2f)" % [_modx_slider.value, _mody_slider.value]
	if is_instance_valid(_seg_overlay):
		_seg_overlay.queue_redraw()

func _on_apply_segmentation() -> void:
	print("𒓉 [SegCtl] Apply eccentricity=(", str(_eccx_slider.value), ", ", str(_eccy_slider.value), ") modularity=(", str(_modx_slider.value), ", ", str(_mody_slider.value), ")")
	_send_segmentation_to_feagi()

func _on_preproc_value_changed(_val: float) -> void:
	if _brightness_val_label:
		_brightness_val_label.text = "%.2f" % [_brightness_slider.value]
	if _contrast_val_label:
		_contrast_val_label.text = "%.2f" % [_contrast_slider.value]

func _on_motion_value_changed(_val: float) -> void:
	if _pixdiff_val_label:
		_pixdiff_val_label.text = "%.2f" % [_pixdiff_slider.value]
	if _receptive_val_label:
		_receptive_val_label.text = "%d" % [int(_receptive_slider.value)]
	if _motion_intensity_val_label:
		_motion_intensity_val_label.text = "%.2f" % [_motion_intensity_slider.value]
	if _min_blob_val_label:
		_min_blob_val_label.text = "%d" % [int(_min_blob_slider.value)]

func _on_apply_preproc() -> void:
	print("𒓉 [PreProc] Apply brightness=", _brightness_slider.value, " contrast=", _contrast_slider.value, " grayscale=", _grayscale_check.button_pressed)

func _on_reset_preproc() -> void:
	_brightness_slider.value = 0.0
	_contrast_slider.value = 1.0
	_grayscale_check.button_pressed = false
	_on_preproc_value_changed(0.0)

func _on_apply_motion() -> void:
	print("𒓉 [Motion] Apply pix_diff=", _pixdiff_slider.value, " receptive=", int(_receptive_slider.value), " intensity=", _motion_intensity_slider.value, " min_blob=", int(_min_blob_slider.value))

func _on_reset_motion() -> void:
	_pixdiff_slider.value = 0.15
	_receptive_slider.value = 8
	_motion_intensity_slider.value = 0.5
	_min_blob_slider.value = 16
	_on_motion_value_changed(0.0)

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

func _on_raw_preview_rect_changed() -> void:
	if is_instance_valid(_seg_overlay):
		_seg_overlay.queue_redraw()

# Helper getters for overlay callables
func _get_eccentricity() -> Vector2:
	return Vector2(_eccx_slider.value, _eccy_slider.value)

func _get_modulation() -> Vector2:
	return Vector2(_modx_slider.value, _mody_slider.value)

func _update_fps_tracker(is_raw: bool, current_time: int, frame_seq: int) -> void:
	"""Track frame times and calculate rolling average FPS based on actual new frames."""
	var last_time: int = _last_frame_time_raw if is_raw else _last_frame_time_feagi
	var frame_times: Array = _frame_times_raw if is_raw else _frame_times_feagi
	
	# Update frame sequence tracker
	if is_raw:
		_last_frame_seq_raw = frame_seq
	else:
		_last_frame_seq_feagi = frame_seq
	
	# Skip first frame (no previous time)
	if last_time == 0:
		if is_raw:
			_last_frame_time_raw = current_time
		else:
			_last_frame_time_feagi = current_time
		return
	
	# Calculate frame delta time in milliseconds
	var delta_ms: int = current_time - last_time
	if delta_ms <= 0:
		return  # Skip if no time passed (same frame)
	
	# Add to rolling window
	frame_times.append(delta_ms)
	if frame_times.size() > FPS_WINDOW_SIZE:
		frame_times.pop_front()
	
	# Calculate average FPS
	if frame_times.size() > 0:
		var avg_delta_ms: float = 0.0
		for dt in frame_times:
			avg_delta_ms += float(dt)
		avg_delta_ms /= float(frame_times.size())
		
		var fps: float = 1000.0 / avg_delta_ms if avg_delta_ms > 0 else 0.0
		
		if is_raw:
			_fps_raw = fps
			_last_frame_time_raw = current_time
			_frame_times_raw = frame_times
		else:
			_fps_feagi = fps
			_last_frame_time_feagi = current_time
			_frame_times_feagi = frame_times

# Window resizing handlers
func _on_resize_handle_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_resizing = true
				_resize_start_mouse = get_global_mouse_position()
				_resize_start_size = size
			else:
				_resizing = false
	
	elif event is InputEventMouseMotion and _resizing:
		var delta := get_global_mouse_position() - _resize_start_mouse
		var new_size := _resize_start_size + delta
		
		# Enforce minimum size
		new_size.x = max(new_size.x, MIN_PANEL_WIDTH * 2 + 50)
		new_size.y = max(new_size.y, 400)
		
		size = new_size
		custom_minimum_size = new_size

# Draw resize grip indicator (simple square on the right edge)
func _draw_resize_grip(control: Control) -> void:
	var grip_color := Color(0.6, 0.6, 0.6, 0.9)  # Medium gray
	var square_size := 8
	
	# Draw square at the RIGHT side of the 16x16 control
	# x should be close to 16 (right edge), y centered at 8
	var x_pos := _resize_margin - square_size  # Right-aligned within the 16px width
	var y_pos := (_resize_margin - square_size) / 2.0  # Vertically centered
	
	var rect := Rect2(Vector2(x_pos, y_pos), Vector2(square_size, square_size))
	control.draw_rect(rect, grip_color, true)
