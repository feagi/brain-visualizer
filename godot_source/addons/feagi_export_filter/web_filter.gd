@tool
extends EditorExportPlugin

var _renamed: Array[String] = []

func _get_name() -> String:
	return "FEAGI Export Filter"

func _supports_platform(_platform: EditorExportPlatform) -> bool:
	# Avoid calling methods that may not exist; we handle gating by features in callbacks
	return true

func _export_begin(features: PackedStringArray, is_debug: bool, path: String, flags: int) -> void:
	if not features.has("web"):
		return
	# Proactively rename native GDExtension files so the exporter doesn't scan them on Web
	var candidates := ["res://addons/feagi_rust_deserializer/feagi_data_deserializer.gdextension"]
	for p in candidates:
		if FileAccess.file_exists(p):
			var off: String = p + ".off"
			# Ensure we don't overwrite an existing .off
			if FileAccess.file_exists(off):
				# Already renamed; remember to restore
				_renamed.append(off)
				continue
			var dir := DirAccess.open(p.get_base_dir())
			if dir and dir.file_exists(p.get_file()):
				var err := dir.rename(p.get_file(), off.get_file())
				if err == OK:
					_renamed.append(off)

func _export_end() -> void:
	# Restore any files we renamed
	for off in _renamed:
		var orig: String = off.trim_suffix(".off")
		var dir := DirAccess.open(off.get_base_dir())
		if dir and dir.file_exists(off.get_file()):
			dir.rename(off.get_file(), orig.get_file())
	_renamed.clear()

func _export_file(path: String, type: String, features: PackedStringArray) -> void:
	# Exclude target/ and bin/ directories from all exports (build artifacts)
	if "/target/" in path or path.ends_with("/target") or "/bin/" in path or path.ends_with("/bin"):
		skip()
		return
	
	# Exclude .gdextension.off files (disabled extensions)
	if path.ends_with(".gdextension.off"):
		skip()
		return
	
	# Exclude duplicate libraries in feagi_rust_deserializer (disabled addon)
	if path.begins_with("res://addons/feagi_rust_deserializer/"):
		skip()
		return
	
	# Exclude duplicate .dylib files (only the ones next to .gdextension should be included)
	# This prevents multiple copies of the same library from different build locations
	if path.ends_with(".dylib") or path.ends_with(".so") or path.ends_with(".dll"):
		# Only allow libraries that are directly in addon root (next to .gdextension)
		var path_parts = path.split("/")
		# Check if dylib is in target/ or bin/ subdirectory
		if "target" in path_parts or "bin" in path_parts:
			skip()
			return
	
	if not features.has("web"):
		return
	# Strip native GDExtension configs from Web exports to avoid warnings
	if path.ends_with(".gdextension"):
		skip() # do not include this file
		return

