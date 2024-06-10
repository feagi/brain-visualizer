extends BaseDraggableWindow
class_name WindowMappingEditor

const WINDOW_NAME: StringName = "mapping_editor"

var _source: GenomeObject
var _destination: GenomeObject

var _source_button: GenomeObjectSelectorButton
var _destination_button: GenomeObjectSelectorButton


func setup(source: GenomeObject, destination: GenomeObject) -> void:
	_source_button = _window_internals.get_node("ends/Source")
	_destination_button = _window_internals.get_node("ends/Destination")
	_setup_base_window(WINDOW_NAME)
	_source = source
	_destination = destination
	_source_button.setup(source, GenomeObject.SINGLE_MAKEUP.SINGLE_CORTICAL_AREA)
	_destination_button.setup(destination, GenomeObject.SINGLE_MAKEUP.SINGLE_CORTICAL_AREA)


func set_2_genome_objects(source: GenomeObject, destination: GenomeObject) -> void:
	_source_button.update_selection(source)
	_destination_button.update_selection(destination)


func _set_2_cortical_areas(source: AbstractCorticalArea, destination: AbstractCorticalArea) -> void:
	pass

func _set_window_mode(is_memory: bool) -> void:
	pass

