@tool
extends EditorExportPlugin

func _get_name() -> String:
	return "FEAGI Desktop Export Filter"

func _export_begin(features: PackedStringArray, is_debug: bool, path: String, flags: int) -> void:
	print("[FEAGI Export Filter] Desktop export started")
	print("[FEAGI Export Filter] Filtering out data deserializer extension")

func _export_file(path: String, type: String, features: PackedStringArray) -> void:
	# Skip the data deserializer extension file - it's only needed for web
	# The desktop binary already has it compiled in
	if path == "res://addons/feagi_rust_deserializer/feagi_data_deserializer.gdextension":
		skip()
		print("[FEAGI Export Filter] Skipped: ", path)

func _export_end() -> void:
	print("[FEAGI Export Filter] Desktop export completed")

