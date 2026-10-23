extends RefCounted
class_name SchematicExporter
## Saves the whole Circuit Schematic, not just the part on screen, in a [SchematicImageFile] format.
## A still copy of the view, with the same regions open, is drawn in an off-screen SubViewport sized
## to the whole canvas. Desktop asks where to save; the web build downloads.


## Asks for a file (or downloads on web), then renders and writes [param source] in [param format].
static func export_view(source: CircuitSchematic, format: SchematicImageFile.FORMAT) -> void:
	var file_name: String = SchematicImageFile.default_file_name(format)
	if OS.has_feature("web"):
		var bytes: PackedByteArray = await render_bytes(source, format)
		if not bytes.is_empty():
			JavaScriptBridge.download_buffer(bytes, file_name, SchematicImageFile.MIME_TYPES[format])
		return
	var dialog: FileDialog = FileDialog.new()
	dialog.title = "Export Circuit Schematic"
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = true
	dialog.current_file = file_name
	dialog.filters = PackedStringArray(["*.%s ; %s" % [SchematicImageFile.EXTENSIONS[format], SchematicImageFile.LABELS[format]]])
	dialog.file_selected.connect(func(path: String) -> void:
		dialog.queue_free()
		_write_file(source, format, path))
	dialog.canceled.connect(dialog.queue_free)
	source.add_child(dialog)
	dialog.popup_centered_ratio(0.6)


## The encoded file, or empty if there is nothing to draw.
static func render_bytes(source: CircuitSchematic, format: SchematicImageFile.FORMAT) -> PackedByteArray:
	var image: Image = await render(source)
	if image == null:
		return PackedByteArray()
	return SchematicImageFile.encode(image, format)


## Draws the whole schematic off-screen, with the same regions open as [param source].
static func render(source: CircuitSchematic) -> Image:
	if not is_instance_valid(source) or source.model == null or source.model.canvas_rect.size == Vector2.ZERO:
		return null
	var canvas: Rect2 = source.model.canvas_rect
	var scale: float = SchematicImageFile.export_scale(canvas.size)
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i((canvas.size * scale).ceil()) + Vector2i(SchematicImageFile.MARGIN_PX, SchematicImageFile.MARGIN_PX) * 2
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var copy: CircuitSchematic = CircuitSchematic.new()
	copy.export_mode = true
	# Theme lookup stops at a viewport, so hand the copy the theme the live view draws with.
	copy.theme = _theme_of(source)
	viewport.add_child(copy)
	source.get_tree().root.add_child(viewport)
	copy.size = Vector2(viewport.size)
	copy.set_open_region_ids(source.open_region_ids())
	copy.zoom_min = minf(scale, 0.01)
	copy.zoom_max = maxf(scale, SchematicImageFile.MAX_SCALE)
	copy.zoom = scale
	# GraphEdit only widens its scroll range a couple of frames after boxes are added.
	var tree: SceneTree = source.get_tree()
	await tree.process_frame
	await tree.process_frame
	copy.scroll_offset = canvas.position * scale - Vector2(SchematicImageFile.MARGIN_PX, SchematicImageFile.MARGIN_PX)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	viewport.queue_free()
	return image


static func _write_file(source: CircuitSchematic, format: SchematicImageFile.FORMAT, path: String) -> void:
	var bytes: PackedByteArray = await render_bytes(source, format)
	if bytes.is_empty():
		_notify("Circuit schematic export failed: nothing to draw", NotificationSystemNotification.NOTIFICATION_TYPE.ERROR)
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_notify("Circuit schematic export failed: can't write %s (%s)" % [path, error_string(FileAccess.get_open_error())], NotificationSystemNotification.NOTIFICATION_TYPE.ERROR)
		return
	file.store_buffer(bytes)
	file.close()
	_notify("Exported circuit schematic to %s" % path)


static func _notify(message: String, type: NotificationSystemNotification.NOTIFICATION_TYPE = NotificationSystemNotification.NOTIFICATION_TYPE.INFO) -> void:
	if BV.NOTIF != null:
		BV.NOTIF.add_notification(message, type)


static func _theme_of(control: Control) -> Theme:
	var node: Node = control
	while node != null:
		if node is Control and (node as Control).theme != null:
			return (node as Control).theme
		if node is Window and (node as Window).theme != null:
			return (node as Window).theme
		node = node.get_parent()
	return null
