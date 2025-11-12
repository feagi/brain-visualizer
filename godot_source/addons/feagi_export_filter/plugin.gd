@tool
extends EditorPlugin

var _web_filter := preload("res://addons/feagi_export_filter/web_filter.gd").new()
var _desktop_filter := preload("res://addons/feagi_export_filter/desktop_filter.gd").new()

func _enter_tree() -> void:
	add_export_plugin(_web_filter)
	add_export_plugin(_desktop_filter)
	print("[FEAGI Export Filter] Plugin loaded")

func _exit_tree() -> void:
	remove_export_plugin(_web_filter)
	remove_export_plugin(_desktop_filter)

