extends RefCounted
class_name SelectionSystem

const DEFAULT_OVERRIDES: Array[OVERRIDE_USECASE] = []

enum ERROR{
	NONE,
	ALREADY_HIGHLIGHTED,
	ALREADY_NOT_HIGHLIGHTED,
	OTHER,
}

enum SOURCE_CONTEXT {
	FROM_CIRCUIT_BUILDER_CLICK,
	FROM_CIRCUIT_BUILDER_DRAG,
	FROM_BRAIN_MONITOR,
	FROM_OBJECT_SELECTION_WINDOW,
	UNKNOWN
}

enum OVERRIDE_USECASE {
	QUICK_CONNECT,
	CORTICAL_PROPERTIES,
}


# Highlighting is mainly a visual thing, to show what objects will be selected
signal highlighted_objects_changed(objects: Array[GenomeObject])
signal highlighted_object_added(object: GenomeObject)
signal highlighted_object_removed(object: GenomeObject)
signal highlighted_cortical_area_added(area: AbstractCorticalArea)
signal highlighted_cortical_area_removed(area: AbstractCorticalArea)
signal highlighted_region_added(region: BrainRegion)
signal highlighted_region_removed(region: BrainRegion)

# Selection allows us to act upon a group of [GenomeObject]s globally
signal objects_selection_event_called(objects: Array[GenomeObject], context: SOURCE_CONTEXT, override_usecases: Array[OVERRIDE_USECASE])
signal cortical_area_voxel_selected(cortical_area_source: AbstractCorticalArea, voxel_coordinate: Vector3i)

var _highlighted_genome_objects: Array[GenomeObject] = []
var _override_use_cases: Array[OVERRIDE_USECASE] = []

func add_override_usecase(usecase: OVERRIDE_USECASE) -> void:
	if usecase in _override_use_cases:
		#ignore
		return
	_override_use_cases.append(usecase)

func remove_override_usecase(usecase: OVERRIDE_USECASE) -> void:
	var index: int = _override_use_cases.find(usecase)
	if index == -1:
		#ignore
		return
	_override_use_cases.remove_at(index)

func clear_all_highlighted() -> void:
	for object in _highlighted_genome_objects:
		object.UI_set_highlighted_state(false)
		highlighted_object_removed.emit(object)
		if object is AbstractCorticalArea:
			highlighted_cortical_area_removed.emit(object as AbstractCorticalArea)
		else:
			highlighted_region_removed.emit(object as BrainRegion)
	_highlighted_genome_objects = []
	highlighted_objects_changed.emit(_highlighted_genome_objects)

func add_to_highlighted(genome_object: GenomeObject) -> ERROR:
	if genome_object in _highlighted_genome_objects:
		push_warning("FEAGI Selection: Attempted to highlighted already highlighted object %s!" % genome_object.genome_ID)
		return ERROR.ALREADY_HIGHLIGHTED
	_highlighted_genome_objects.append(genome_object)
	genome_object.UI_set_highlighted_state(true)
	highlighted_object_added.emit(genome_object)
	if genome_object is AbstractCorticalArea:
		highlighted_cortical_area_added.emit(genome_object as AbstractCorticalArea)
	else:
		highlighted_region_added.emit(genome_object as BrainRegion)
	highlighted_objects_changed.emit(_highlighted_genome_objects)
	return ERROR.NONE

func remove_from_highlighted(genome_object: GenomeObject) -> ERROR:
	var search: int = _highlighted_genome_objects.find(genome_object)
	if search == -1:
		push_warning("FEAGI Selection: Attempted to unhighlighted already unhighlighted object %s!" % genome_object.genome_ID)
		return ERROR.ALREADY_NOT_HIGHLIGHTED
	_highlighted_genome_objects.remove_at(search)
	genome_object.UI_set_highlighted_state(false)
	highlighted_object_removed.emit(genome_object)
	if genome_object is AbstractCorticalArea:
		highlighted_cortical_area_removed.emit(genome_object as AbstractCorticalArea)
	else:
		highlighted_region_removed.emit(genome_object as BrainRegion)
	highlighted_objects_changed.emit(_highlighted_genome_objects)
	return ERROR.NONE

## Generic object selection function
func select_objects(context: SOURCE_CONTEXT = SOURCE_CONTEXT.UNKNOWN, objects_to_select: Array[GenomeObject] = _highlighted_genome_objects) -> void:
	objects_selection_event_called.emit(objects_to_select, context, _override_use_cases)

func cortical_area_voxel_clicked(cortical_area_source: AbstractCorticalArea, voxel_coordinate: Vector3i) -> void:
	cortical_area_voxel_selected.emit(cortical_area_source, voxel_coordinate)
