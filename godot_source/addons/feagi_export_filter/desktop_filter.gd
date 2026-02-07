@tool
extends EditorExportPlugin

func _get_name() -> String:
	return "FEAGI Desktop Export Filter"

func _export_begin(features: PackedStringArray, is_debug: bool, path: String, flags: int) -> void:
	print("[FEAGI Export Filter] Desktop export started")
	print("[FEAGI Export Filter] Filtering out data deserializer extension")
	print("[FEAGI Export Filter] Filtering out feagi_embedded (Remote mode - embedded not needed)")

func _export_file(path: String, type: String, features: PackedStringArray) -> void:
	# Skip the data deserializer extension file - it's only needed for web
	# The desktop binary already has it compiled in
	if path == "res://addons/feagi_rust_deserializer/feagi_data_deserializer.gdextension":
		skip()
		print("[FEAGI Export Filter] Skipped: ", path)

	# Skip feagi_embedded addon - Remote mode connects to external FEAGI, does not need in-process embedded
	# Saves ~6MB on PyPI package size
	if path.begins_with("res://addons/feagi_embedded/"):
		skip()
		return

	# Skip legacy Feagi-Godot-Interface BVVersion to avoid class name conflict
	# The correct BVVersion is in BrainVisualizer/BVVersion.gd
	if path == "res://Feagi-Godot-Interface/Core/NonCache-Objects/BVVersion.gd":
		skip()
		print("[FEAGI Export Filter] Skipped legacy BVVersion: ", path)

func _export_end() -> void:
	print("[FEAGI Export Filter] Desktop export completed")

