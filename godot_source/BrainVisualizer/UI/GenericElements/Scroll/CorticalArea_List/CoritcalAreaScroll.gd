extends GenericTextIDScroll
class_name CorticalAreaScroll

signal cortical_area_selected(cortical_area: BaseCorticalArea)

@export var load_cortical_areas_on_load: bool = true

func _ready():
	super()
	item_selected.connect(_cortical_Area_button_pressed)
	FeagiCore.feagi_local_cache.cortical_areas.cortical_area_about_to_be_removed.connect(_respond_to_deleted_cortical_area)
	FeagiCore.feagi_local_cache.cortical_areas.cortical_area_added.connect(_respond_to_added_cortical_area)
	FeagiCore.feagi_local_cache.cortical_areas.cortical_area_mass_updated.connect(_respond_to_updated_cortical_area)
	if load_cortical_areas_on_load:
		repopulate_from_cache()

## Clears list, then loads morphology list from FeagiCache
func repopulate_from_cache() -> void:
	delete_all()
	for cortical_area in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.values():
		append_single_item(cortical_area, cortical_area.name)

## Manually set the selected cortical area through code. Causes the button to emit the selected signal
func select_cortical_area(cortical_area: BaseCorticalArea) -> void:
	# This is essentially a pointless proxy, only existing for convinient naming purposes
	set_selected(cortical_area)

## User selected cortical area from the list
func _cortical_Area_button_pressed(cortical_area_selection: BaseCorticalArea) -> void:
	# This is essentially a pointless proxy, only existing for convinient naming purposes
	cortical_area_selected.emit(cortical_area_selection)

func _respond_to_deleted_cortical_area(cortical_area: BaseCorticalArea) -> void:
	remove_by_ID(cortical_area)

func _respond_to_added_cortical_area(cortical_area: BaseCorticalArea) -> void:
	append_single_item(cortical_area, cortical_area.name)

func _respond_to_updated_cortical_area(updated_cortical_area: BaseCorticalArea) -> void:
	var button: GenericScrollItemText = get_button_by_ID(updated_cortical_area)
	if button.text != updated_cortical_area.name:
		button.text = updated_cortical_area.name
	
