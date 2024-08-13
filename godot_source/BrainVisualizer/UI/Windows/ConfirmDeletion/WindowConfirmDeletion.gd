extends BaseDraggableWindow
class_name WindowConfirmDeletion

const WINDOW_NAME: StringName = "confirm_deletion"

var _label: Label
var _deletion_targets: Array[GenomeObject]
var _is_deleting_internals: bool
var _mode: GenomeObject.ARRAY_MAKEUP
var _scroll: ScrollSectionGeneric

func setup(selection: Array[GenomeObject], region_deleting_internals: bool = false) -> void:
	_label = _window_internals.get_node("DeleteText")
	_scroll = _window_internals.get_node("ScrollSectionGeneric")
	_deletion_targets = selection
	_is_deleting_internals = region_deleting_internals
	_mode = GenomeObject.get_makeup_of_array(selection)
	_setup_base_window(WINDOW_NAME)
	match _mode:
		GenomeObject.ARRAY_MAKEUP.SINGLE_CORTICAL_AREA:
			_label.text = "Are you sure you wish to delete cortical area %s?" % selection[0].friendly_name
			_scroll.visible = false
		GenomeObject.ARRAY_MAKEUP.SINGLE_BRAIN_REGION:
			var internals: Array[GenomeObject] = (selection[0] as BrainRegion).get_all_included_genome_objects()
			_scroll_show_objects(internals)
			if region_deleting_internals:
				_label.text = "Are you sure you wish to delete brain region %s with these %d internals?" % [selection[0].friendly_name, len(internals)]
			else:
				# raising internals instead
				_label.text = "Are you sure you wish to delete brain region %s and raise its %d internals to the parent region %s?" % [selection[0].friendly_name, len(internals), selection[0].current_parent_region.friendly_name]
				
		GenomeObject.ARRAY_MAKEUP.MULTIPLE_CORTICAL_AREAS:
			_label.text = "Are you sure you wish to delete %d cortical areas?" % len(selection)
			_scroll_show_objects(selection)
		GenomeObject.ARRAY_MAKEUP.MULTIPLE_BRAIN_REGIONS:
			_label.text = "Are you sure you wish to delete %d brain regions and their internals?" % len(selection)
			_scroll_show_objects(selection)
		GenomeObject.ARRAY_MAKEUP.VARIOUS_GENOME_OBJECTS:
			_label.text = "Are you sure you wish to delete %d objects and their internals?" % len(selection)
			_scroll_show_objects(selection)
		_:
			push_error("UI: Unknown deletion target for deletion confirmation window! Closing!")
			close_window()

func _scroll_show_objects(objects: Array[GenomeObject]) -> void:
	for object in objects:
		_scroll.add_text_button(object, object.friendly_name, Callable())

func _yes_pressed() -> void:
	match _mode:
		GenomeObject.ARRAY_MAKEUP.SINGLE_CORTICAL_AREA:
			FeagiCore.requests.delete_cortical_area((_deletion_targets[0] as AbstractCorticalArea))
		GenomeObject.ARRAY_MAKEUP.SINGLE_BRAIN_REGION:
			if _is_deleting_internals:
				pass #TODO
			else:
				FeagiCore.requests.delete_regions_and_raise_internals(_deletion_targets[0] as BrainRegion)
		GenomeObject.ARRAY_MAKEUP.MULTIPLE_CORTICAL_AREAS:
			FeagiCore.requests.mass_delete_cortical_areas(GenomeObject.filter_cortical_areas(_deletion_targets)) #idc
	close_window()

func _no_pressed() -> void:
	close_window()
