extends GrowingPanel
class_name WindowLeftPanel


var _cortical_area_ref: CorticalArea
var _top_section # cannot define type due to godot bug
var _middle_section

var _cortical_area_properties_to_request_top: Dictionary = {}


func _ready():
	super._ready()
	var top_collapsible = $Main_Body/Top_Section
	var middle_collapsible = $Main_Body/Middle_Section
	_top_section = top_collapsible.collapsing_node
	_middle_section = middle_collapsible.collapsing_node

func setup(cortical_area_reference: CorticalArea) -> void:
	_cortical_area_ref = cortical_area_reference
	
	_top_section.setup(_cortical_area_ref)
	_middle_section.setup(_cortical_area_ref)

	_cortical_area_ref.dimensions_updated.connect(_top_section.FEAGI_set_cortical_dimension)
	_cortical_area_ref.coordinates_3D_updated.connect(_top_section.FEAGI_set_cortical_position)
	_cortical_area_ref.name_updated.connect(_top_section.FEAGI_set_cortical_name)
	_cortical_area_ref.details_updated.connect(_middle_section.FEAGI_set_properties)



## Called from top or middle, user sent dict of properties to request FEAGI to set
func _user_requested_updated(changed_values: Dictionary) -> void:
	FeagiRequests.set_cortical_area_properties(_cortical_area_ref.cortical_ID, changed_values)


################################### Top Bar  ##################################

################################## Middle Bar #################################
