@tool
extends EditorPlugin

var _export_plugin := preload("res://addons/feagi_export_filter/web_filter.gd").new()

func _enter_tree() -> void:
	add_export_plugin(_export_plugin)

func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)

