extends BaseDraggableWindow
class_name WindowMappingEditor

var _source_button: Button
var _destination_button: Button


func setup_with_2_cortical_areas(source: BaseCorticalArea, destination: BaseCorticalArea) -> void:
	_setup_base_window("edit_mappings")
	set_2_cortical_areas(source, destination)

func set_2_cortical_areas(source: BaseCorticalArea, destination: BaseCorticalArea) -> void:
	pass




func _set_window_mode(is_memory: bool) -> void:
	pass

