extends GrowingPanel
class_name WindowLeftPanel


var _cortical_area_ref: CorticalArea
var _top_section # cannot define type due to godot bug


func _ready():
	super._ready()
	var top_collapsible = $Top_Section/VerticalCollapsible
	_top_section = top_collapsible.collapsing_node

func setup(cortical_area_reference: CorticalArea) -> void:
	_cortical_area_ref = cortical_area_reference
	_update_UI_from_cache()
	_cortical_area_ref.dimensions_updated.connect(_update_dimensions_from_signal)
	_cortical_area_ref.coordinates_3D_updated.connect(_update_coordinate_3D_from_signal)
	_cortical_area_ref.details_updated.connect(_update_details_from_signal)



#TODO add signal response

func _update_UI_from_cache() -> void:
	_top_section.cortical_name = _cortical_area_ref.name
	_top_section.cortical_ID = _cortical_area_ref.cortical_ID
	_top_section.cortical_Type = str(_cortical_area_ref.group)
	_top_section.cortical_position = _cortical_area_ref.coordinates_3D
	_top_section.cortical_dimension = _cortical_area_ref.dimensions

func _update_dimensions_from_signal(dim: Vector3i) -> void:
	if _top_section.cortical_dimension == dim: return
	_top_section.cortical_dimension = dim

func _update_coordinate_3D_from_signal(coords: Vector3i) -> void:
	if _top_section.cortical_position == coords: return
	_top_section.cortical_position = coords

func _update_details_from_signal(details: Dictionary) -> void:
	pass




