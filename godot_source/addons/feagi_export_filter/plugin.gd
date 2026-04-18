@tool
extends EditorPlugin

var _web_filter: EditorExportPlugin = null
var _desktop_filter: EditorExportPlugin = null

func _enter_tree() -> void:
	if _web_filter == null:
		_web_filter = preload("res://addons/feagi_export_filter/web_filter.gd").new()
	if _desktop_filter == null:
		_desktop_filter = preload("res://addons/feagi_export_filter/desktop_filter.gd").new()
	add_export_plugin(_web_filter)
	add_export_plugin(_desktop_filter)
	print("[FEAGI Export Filter] Plugin loaded")

func _exit_tree() -> void:
	# In headless CI export mode, shutdown order can invalidate export plugin internals
	# during teardown, causing native aborts after a successful export. We skip explicit
	# remove in that environment and let process teardown release instances.
	if DisplayServer.get_name() == "headless":
		return
	if _web_filter != null:
		remove_export_plugin(_web_filter)
	_web_filter = null
	if _desktop_filter != null:
		remove_export_plugin(_desktop_filter)
	_desktop_filter = null

