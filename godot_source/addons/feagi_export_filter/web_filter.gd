extends EditorExportPlugin

var _renamed: Array[String] = []

func _supports_platform(platform: EditorExportPlatform) -> bool:
	return platform.get_name() == "Web"

func _export_begin(features: PackedStringArray, is_debug: bool, path: String, flags: int) -> void:
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
	# Strip native GDExtension configs from Web exports to avoid warnings
	if path.ends_with(".gdextension"):
		skip() # do not include this file
		return
	# Also ignore any native library artifacts under the Rust addon
	if path.begins_with("res://addons/feagi_rust_deserializer/"):
		skip()

