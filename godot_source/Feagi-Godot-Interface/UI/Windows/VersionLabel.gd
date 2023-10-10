extends Label
class_name VersionLabel

func _ready() -> void:
	text = Time.get_datetime_string_from_unix_time(VisConfig.version.automatic_version)
