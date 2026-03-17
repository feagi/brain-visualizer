extends BaseDraggableWindow
class_name WindowSelectRegionTemplate

const WINDOW_NAME: StringName = "select_region_template"
const CREATE_REGION_LABEL: StringName = "Create New Circuit"
const CIRCUIT_ICON: Texture2D = preload("res://BrainVisualizer/UI/GenericResources/ButtonIcons/architecture.png")
const CIRCUITS_DIR_NAME: StringName = "circuits"
const MANIFEST_FILENAME: StringName = "manifest.json"
const GENOME_FILENAME: StringName = "genome.json"

var _cancel_button: Button
var _icon_grid: GridContainer
var _parent_region: BrainRegion = null
var _footer_note: Label


func _ready() -> void:
	super()
	_cancel_button = _window_internals.get_node("Buttons/Cancel")
	_icon_grid = _window_internals.get_node("Scroll/ContentMargin/IconGrid")
	_footer_note = _window_internals.get_node("FooterNote")
	_cancel_button.pressed.connect(_on_cancel)
	_apply_footer_font_bump()


## Prepare and display the circuit selection window.
func setup(parent_region: BrainRegion = null) -> void:
	_setup_base_window(WINDOW_NAME)
	_parent_region = parent_region
	var title_bar = get_node("TitleBar")
	if title_bar != null:
		title_bar.set("title", "Add Circuit")
	_populate_grid()


## Close the window without action.
func _on_cancel() -> void:
	close_window()


## Populate the selection grid with fixed options.
func _populate_grid() -> void:
	for child in _icon_grid.get_children():
		child.queue_free()
	_icon_grid.add_theme_constant_override("v_separation", 40)
	var scroll: ScrollContainer = _window_internals.get_node("Scroll")
	if scroll:
		scroll.custom_minimum_size.y = 720.0
	_add_locked_create_region_tile()
	_add_manifest_tiles()


## Add the first tile that opens the Create Brain Region window.
func _add_locked_create_region_tile() -> void:
	var tile := VBoxContainer.new()
	tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tile.custom_minimum_size.x = 128
	tile.alignment = BoxContainer.ALIGNMENT_BEGIN
	tile.set_meta("locked", true)
	
	var button := TextureButton.new()
	button.custom_minimum_size = Vector2(128, 128)
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.texture_normal = CIRCUIT_ICON
	button.texture_hover = button.texture_normal
	button.texture_pressed = button.texture_normal
	button.pressed.connect(_open_create_region)
	
	var name_label := Label.new()
	name_label.text = CREATE_REGION_LABEL
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.custom_minimum_size.x = 128
	name_label.custom_minimum_size.y = 40
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	name_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	name_label.max_lines_visible = 2
	
	tile.add_child(button)
	tile.add_child(name_label)
	_icon_grid.add_child(tile)


## Open the existing Create Brain Region window.
func _open_create_region() -> void:
	var parent_region: BrainRegion = _parent_region
	if parent_region == null:
		parent_region = FeagiCore.feagi_local_cache.brain_regions.get_root_region()
	var empty_selection: Array[GenomeObject] = []
	BV.WM.spawn_create_region(parent_region, empty_selection)
	close_window()

## Increase footer note font size by two points.
func _apply_footer_font_bump() -> void:
	if _footer_note == null:
		return
	var base_size := _footer_note.get_theme_font_size("font_size")
	if base_size > 0:
		_footer_note.add_theme_font_size_override("font_size", base_size + 2)

## Load circuits from the manifest and add tiles.
func _add_manifest_tiles() -> void:
	var manifest := _load_manifest()
	if manifest.is_empty():
		return
	var circuits: Dictionary = manifest.get("circuits", {})
	if circuits.is_empty():
		return
	
	var sorted_keys: Array = circuits.keys()
	sorted_keys.sort_custom(func(a, b):
		var a_title: String = String(circuits.get(a, {}).get("title", a))
		var b_title: String = String(circuits.get(b, {}).get("title", b))
		return a_title.to_lower() < b_title.to_lower()
	)
	
	for circuit_key in sorted_keys:
		var circuit_data: Dictionary = circuits.get(circuit_key, {})
		_add_circuit_tile(String(circuit_key), circuit_data)


## Add a circuit tile from manifest data.
func _add_circuit_tile(circuit_folder: String, metadata: Dictionary) -> void:
	var title: String = String(metadata.get("title", circuit_folder))
	var icon_rel_path: String = String(metadata.get("icon_path", ""))
	if icon_rel_path == "":
		BV.NOTIF.add_notification("Circuit '%s' missing icon_path in manifest" % title, NotificationSystemNotification.NOTIFICATION_TYPE.ERROR)
		return
	
	var icon_path := _resolve_circuits_path(icon_rel_path)
	if not FileAccess.file_exists(icon_path):
		BV.NOTIF.add_notification("Circuit icon not found: %s" % icon_rel_path, NotificationSystemNotification.NOTIFICATION_TYPE.ERROR)
		return
	
	var image := Image.new()
	var image_err := image.load(icon_path)
	if image_err != OK:
		BV.NOTIF.add_notification("Failed to load circuit icon: %s" % icon_rel_path, NotificationSystemNotification.NOTIFICATION_TYPE.ERROR)
		return
	var texture := ImageTexture.create_from_image(image)
	
	var genome_path := _resolve_circuits_path(circuit_folder.path_join(GENOME_FILENAME))
	if not FileAccess.file_exists(genome_path):
		BV.NOTIF.add_notification("Circuit genome not found: %s" % genome_path.get_file(), NotificationSystemNotification.NOTIFICATION_TYPE.ERROR)
		return
	
	var tile := VBoxContainer.new()
	tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tile.custom_minimum_size.x = 128
	tile.alignment = BoxContainer.ALIGNMENT_BEGIN
	
	var button := TextureButton.new()
	button.custom_minimum_size = Vector2(128, 128)
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.texture_normal = texture
	button.texture_hover = texture
	button.texture_pressed = texture
	button.pressed.connect(func(): await _upload_circuit(button, title, genome_path))
	
	var name_label := Label.new()
	name_label.text = title
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.custom_minimum_size.x = 128
	name_label.custom_minimum_size.y = 40
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	name_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	name_label.max_lines_visible = 2
	
	tile.add_child(button)
	tile.add_child(name_label)
	_icon_grid.add_child(tile)


## Upload the selected circuit genome to FEAGI.
func _upload_circuit(button: TextureButton, title: String, genome_path: String) -> void:
	button.disabled = true
	var result: FeagiRequestOutput = await FeagiCore.requests.request_amalgamation_by_upload(genome_path)
	button.disabled = false
	
	if result.has_timed_out or result.has_errored or result.failed_requirement:
		BV.NOTIF.add_notification("Failed to load circuit '%s'" % title, NotificationSystemNotification.NOTIFICATION_TYPE.ERROR)
		return
	
	BV.NOTIF.add_notification("Circuit '%s' uploaded. Waiting for placement..." % title, NotificationSystemNotification.NOTIFICATION_TYPE.INFO)
	close_window()


## Read circuits manifest from disk.
func _load_manifest() -> Dictionary:
	var manifest_path := _resolve_circuits_path(MANIFEST_FILENAME)
	if not FileAccess.file_exists(manifest_path):
		BV.NOTIF.add_notification("Circuits manifest not found: %s" % manifest_path.get_file(), NotificationSystemNotification.NOTIFICATION_TYPE.ERROR)
		return {}
	var file := FileAccess.open(manifest_path, FileAccess.READ)
	if file == null:
		BV.NOTIF.add_notification("Unable to read circuits manifest", NotificationSystemNotification.NOTIFICATION_TYPE.ERROR)
		return {}
	var content := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(content)
	if parsed is Dictionary:
		return parsed
	BV.NOTIF.add_notification("Invalid circuits manifest format", NotificationSystemNotification.NOTIFICATION_TYPE.ERROR)
	return {}


## Resolve a path relative to the circuits folder.
func _resolve_circuits_path(relative_path: String) -> String:
	var res_root := ProjectSettings.globalize_path("res://")
	var project_root := res_root.path_join("..")
	var circuits_root := project_root.path_join(CIRCUITS_DIR_NAME)
	return circuits_root.path_join(relative_path)
