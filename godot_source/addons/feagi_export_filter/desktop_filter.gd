@tool
extends EditorExportPlugin

const GUIDES_DIR := "res://BrainVisualizer/Guides"
const REQUIRED_GDEXTENSION_MANIFESTS := [
	"res://addons/FeagiCoreIntegration/feagi_agent_client.gdextension",
	"res://addons/FeagiCoreIntegration/feagi_type_system.gdextension",
]

func _get_name() -> String:
	return "FEAGI Desktop Export Filter"

func _export_begin(features: PackedStringArray, is_debug: bool, path: String, flags: int) -> void:
	print("[FEAGI Export Filter] Desktop export started")
	print("[FEAGI Export Filter] Filtering out data deserializer extension")
	print("[FEAGI Export Filter] Filtering out feagi_embedded (Remote mode - embedded not needed)")
	_add_guide_files()
	_add_required_gdextension_manifests()

## Add user guide .md and _guide_order.txt to the export.
## Godot excludes non-imported text files from the pck; these must be added explicitly.
func _add_guide_files() -> void:
	var dir := DirAccess.open(GUIDES_DIR)
	if dir == null:
		push_warning("[FEAGI Export Filter] Guides directory not found: %s" % GUIDES_DIR)
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	var count := 0
	while name != "":
		if name == "." or name == "..":
			name = dir.get_next()
			continue
		var file_path := GUIDES_DIR.path_join(name)
		if dir.current_is_dir():
			name = dir.get_next()
			continue
		var ext := name.get_extension().to_lower()
		if ext != "md" and ext != "markdown" and ext != "txt":
			name = dir.get_next()
			continue
		var file := FileAccess.open(file_path, FileAccess.READ)
		if file == null:
			push_warning("[FEAGI Export Filter] Could not read guide file: %s" % file_path)
			name = dir.get_next()
			continue
		var content := file.get_as_text()
		file.close()
		add_file(file_path, content.to_utf8_buffer(), false)
		count += 1
		name = dir.get_next()
	dir.list_dir_end()
	if count > 0:
		print("[FEAGI Export Filter] Added %d guide files to export" % count)

## Ensure required GDExtension manifests are always included in exported PCK.
## This avoids runtime "GDExtension dynamic library not found" due to manifest omission.
func _add_required_gdextension_manifests() -> void:
	var added := 0
	for manifest_path in REQUIRED_GDEXTENSION_MANIFESTS:
		if not FileAccess.file_exists(manifest_path):
			push_warning("[FEAGI Export Filter] Required manifest missing: %s" % manifest_path)
			continue
		var file := FileAccess.open(manifest_path, FileAccess.READ)
		if file == null:
			push_warning("[FEAGI Export Filter] Could not read manifest: %s" % manifest_path)
			continue
		var content := file.get_as_text()
		file.close()
		add_file(manifest_path, content.to_utf8_buffer(), false)
		added += 1
	if added > 0:
		print("[FEAGI Export Filter] Added %d GDExtension manifests to export" % added)

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

