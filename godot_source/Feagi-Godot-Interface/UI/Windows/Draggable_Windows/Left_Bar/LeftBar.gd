extends GrowingPanel
class_name WindowLeftPanel


var _cortical_area_ref: CorticalArea
var _top_section

func _ready():
	super._ready()
	var top_collapsible = $Top_Section/VerticalCollapsible
	_top_section = top_collapsible.collapsing_node

func setup(cortical_area_reference: CorticalArea) -> void:
	_cortical_area_ref = cortical_area_reference
	_update_UI_from_cache()

#TODO add signal response

func _update_UI_from_cache():
	_top_section.cortical_name = _cortical_area_ref.name
	_top_section.cortical_ID = _cortical_area_ref.cortical_ID
	_top_section.cortical_Type = str(_cortical_area_ref.group)
	_top_section.cortical_position = _cortical_area_ref.coordinates_3D
	_top_section.cortical_dimension = _cortical_area_ref.dimensions
