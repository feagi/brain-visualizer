extends BaseDraggableWindow
class_name WindowSelectCorticalTemplate

const WINDOW_NAME: StringName = "select_cortical_template"

signal template_chosen(template: CorticalTemplate)

var _cancel_button: Button
var _icon_grid: GridContainer
var _is_ipu: bool = true
var _context_region: BrainRegion = null
## When set (before add_child), this window opens just below the + Inputs / + Outputs control.
var _placement_anchor: Control = null

## Called by WindowManager before add_child when spawning from the top bar add buttons.
func set_placement_anchor(anchor: Control) -> void:
	_placement_anchor = anchor

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
	await _populate_grid(cortical_type)
	if _placement_anchor != null and is_instance_valid(_placement_anchor):
		await _apply_placement_below_anchor()


func _apply_placement_below_anchor() -> void:
	# One layout frame while hidden (WindowManager); then show at final position only.
	await get_tree().process_frame
	var window_size: Vector2i = size
	if window_size.x < 2 or window_size.y < 2:
		window_size = get_combined_minimum_size()
	if window_size.x < 2 or window_size.y < 2:
		visible = true
		return
	position = BV.WM.position_window_below_anchor(self, _placement_anchor, window_size)
	visible = true

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
	
	# Call the new API endpoints to get available types dynamically
	match cortical_type:
		AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU:
			await _populate_from_api_endpoint("ipu")
		AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU:
			await _populate_from_api_endpoint("opu")
		_:
			push_error("WindowSelectCorticalTemplate: Unknown cortical type")
			return
	
	# Ensure window is wide enough for 4 tiles (128 each) plus 10% gaps between tiles
	var min_width = 640
	if size.x < min_width:
		custom_minimum_size.x = float(min_width)

func _populate_from_api_endpoint(type_str: String) -> void:
	print("WindowSelectCorticalTemplate: Fetching %s types from API..." % type_str.to_upper())
	
	# Determine which endpoint to call
	var endpoint: StringName
	if type_str == "ipu":
		endpoint = FeagiCore.network.http_API.address_list.GET_corticalAreas_ipu_types
	else:
		endpoint = FeagiCore.network.http_API.address_list.GET_corticalAreas_opu_types
	
	# Make API request
	var request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(endpoint)
	var worker: APIRequestWorker = FeagiCore.network.http_API.make_HTTP_call(request)
	await worker.worker_done
	var response: FeagiRequestOutput = worker.retrieve_output_and_close()
	
	if response.has_errored:
		push_error("WindowSelectCorticalTemplate: Failed to fetch %s types from API" % type_str.to_upper())
		return
	
	# Parse response
	var types_data: Dictionary = response.decode_response_as_dict()
	print("WindowSelectCorticalTemplate: Received %d %s types" % [types_data.size(), type_str.to_upper()])
	
	# Sort by description for consistent ordering
	var sorted_keys: Array = types_data.keys()
	sorted_keys.sort_custom(func(a, b): return types_data[a]["description"] < types_data[b]["description"])
	
	# Create tiles for each type
	for type_key in sorted_keys:
		var type_metadata: Dictionary = types_data[type_key]
		_add_tile_from_api_data(type_key, type_metadata)

func _add_tile_from_api_data(type_key: String, metadata: Dictionary) -> void:
	var tile := VBoxContainer.new()
	tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tile.custom_minimum_size.x = 128
	tile.alignment = BoxContainer.ALIGNMENT_BEGIN
	
	var btn := TextureButton.new()
	btn.custom_minimum_size = Vector2(128, 128)
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	
	# Load icon using the type_key (e.g., "iinf", "omot")
	btn.texture_normal = UIManager.get_icon_texture_by_ID(type_key, _is_ipu)
	btn.texture_hover = btn.texture_normal
	btn.texture_pressed = btn.texture_normal
	
	# Store metadata in the button for later use
	btn.set_meta("type_key", type_key)
	btn.set_meta("metadata", metadata)
	btn.pressed.connect(func(): _choose_from_api(type_key, metadata))
	
	var name_label := Label.new()
	name_label.text = metadata.get("description", type_key)
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

func _choose_from_api(type_key: String, metadata: Dictionary) -> void:
	print("WindowSelectCorticalTemplate: Selected type: %s (%s)" % [type_key, metadata.get("description", "")])
	
	# Create CorticalTemplate from API metadata
	var template_id: StringName = type_key
	var template_name: StringName = metadata.get("description", type_key)
	var structure_name: StringName = metadata.get("structure", "asymmetric")
	var resolution_array: Array[int] = []
	resolution_array.assign(metadata.get("resolution", [1, 1, 1]))
	
	var cortical_type: AbstractCorticalArea.CORTICAL_AREA_TYPE
	if _is_ipu:
		cortical_type = AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU
	else:
		cortical_type = AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU
	
	# Extract unit topology for preview boxes.
	#
	# Primary source (existing BV flow):
	# - `/v1/cortical_area/{ipu,opu}/types` provides `unit_default_topology` already in BV format:
	#   { idx: { "relative_position": [x,y,z], "dimensions": [x,y,z] }, ... }
	#
	# Fallback (new schema for `/v1/genome/cortical_template`):
	# - derive the same structure from `subunits`.
	var unit_topology: Dictionary = metadata.get("unit_default_topology", {})
	if unit_topology.is_empty():
		var subunits: Dictionary = metadata.get("subunits", {})
		for subunit_key in subunits.keys():
			var subunit: Dictionary = subunits.get(subunit_key, {})
			var rel_pos: Array = subunit.get("relative_position", [0, 0, 0])
			var dims: Array = subunit.get("channel_dimensions_default", [1, 1, 1])
			unit_topology[int(subunit_key)] = {
				"relative_position": rel_pos,
				"dimensions": dims,
			}
	
	# Create the template object
	var template: CorticalTemplate = CorticalTemplate.new(
		template_id,
		true,  # is_enabled
		template_name,
		structure_name,
		resolution_array,
		cortical_type,
		null,  # feagi_cortical_type (optional)
		unit_topology  # unit_default_topology
	)
	
	print("WindowSelectCorticalTemplate: Created template - ID: %s, Name: %s, Resolution: %s, Units: %d" % [template_id, template_name, resolution_array, unit_topology.size()])
	
	# Emit the template_chosen signal with our newly created template
	template_chosen.emit(template)
	close_window()

func _choose(template: CorticalTemplate) -> void:
	template_chosen.emit(template)
	close_window()
