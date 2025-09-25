extends BaseDraggableWindow
class_name WindowSelectCorticalTemplate

const WINDOW_NAME: StringName = "select_cortical_template"

signal template_chosen(template: CorticalTemplate)

var _cancel_button: Button
var _icon_grid: GridContainer
var _is_ipu: bool = true
var _context_region: BrainRegion = null

func _ready() -> void:
	super()
	_cancel_button = _window_internals.get_node("Buttons/Cancel")
	_icon_grid = _window_internals.get_node("Scroll/ContentMargin/IconGrid")
	_cancel_button.pressed.connect(_on_cancel)

func setup_for_type(cortical_type: AbstractCorticalArea.CORTICAL_AREA_TYPE, context_region: BrainRegion = null) -> void:
	_setup_base_window(WINDOW_NAME)
	_context_region = context_region
	_is_ipu = cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU
	# Update window title accordingly
	var tb = get_node("TitleBar")
	if tb != null:
		if _is_ipu:
			tb.set("title", "Add Input Cortical Area")
		else:
			tb.set("title", "Add Output Cortical Area")
	_populate_grid(cortical_type)

func _on_cancel() -> void:
	close_window()

func _populate_grid(cortical_type: AbstractCorticalArea.CORTICAL_AREA_TYPE) -> void:
	for child in _icon_grid.get_children():
		child.queue_free()
	# Ensure vertical gap between rows (icons are 128px)
	_icon_grid.add_theme_constant_override("v_separation", 40)
	# Increase scroll height to keep 4 rows visible (approx 4 * 128 + gaps)
	var scroll: ScrollContainer = _window_internals.get_node("Scroll")
	if scroll:
		scroll.custom_minimum_size.y = 720.0
	var templates: Array[CorticalTemplate] = []
	match cortical_type:
		AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU:
			for t: CorticalTemplate in FeagiCore.feagi_local_cache.IPU_templates.values():
				if t.is_enabled:
					templates.append(t)
		AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU:
			for t: CorticalTemplate in FeagiCore.feagi_local_cache.OPU_templates.values():
				if t.is_enabled:
					templates.append(t)
		_:
			push_error("WindowSelectCorticalTemplate: Unknown cortical type")
			return
	templates.sort_custom(func(a: CorticalTemplate, b: CorticalTemplate): return a.cortical_name < b.cortical_name)
	for template: CorticalTemplate in templates:
		_add_tile(template)
	# Ensure window is wide enough for 4 tiles (128 each) plus 10% gaps between tiles
	var min_width = 640
	if size.x < min_width:
		custom_minimum_size.x = float(min_width)

func _add_tile(template: CorticalTemplate) -> void:
	var tile := VBoxContainer.new()
	tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tile.custom_minimum_size.x = 128
	tile.alignment = BoxContainer.ALIGNMENT_BEGIN
	var btn := TextureButton.new()
	btn.custom_minimum_size = Vector2(128, 128)
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.texture_normal = UIManager.get_icon_texture_by_ID(template.ID, _is_ipu)
	btn.texture_hover = btn.texture_normal
	btn.texture_pressed = btn.texture_normal
	btn.pressed.connect(func(): _choose(template))
	var name_label := Label.new()
	name_label.text = template.cortical_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.custom_minimum_size.x = 128
	# Reserve space for two lines to keep icon tops aligned across the row
	name_label.custom_minimum_size.y = 40
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	name_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	name_label.max_lines_visible = 2
	tile.add_child(btn)
	tile.add_child(name_label)
	_icon_grid.add_child(tile)

func _choose(template: CorticalTemplate) -> void:
	template_chosen.emit(template)
	close_window()
