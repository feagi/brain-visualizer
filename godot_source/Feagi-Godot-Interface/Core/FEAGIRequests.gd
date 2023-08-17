extends Node
## AUTOLOADED
## General actions to request of FEAGI
## Try to use the functions here to call feagi actions instead of through FEAGIInterface


var _feagi_interface: FEAGIInterface # MUST be set ASAP or the below will crash!


################################ Cortical Areas #################################

## Requests from FEAGI summary of all cortical areas (name, dimensions, 2D/3D location, and visibility)
## Triggers an update in FEAGI Cached cortical areas, which cascades to signals for cortical areas added / removed
func refresh_cortical_areas() -> void:
	_feagi_interface.calls.GET_GE_CorticalArea_geometry()



func delete_cortical_area(cortical_id: StringName) -> void:
	_feagi_interface.calls.DELETE_GE_corticalArea(cortical_id)


################################# Morphologies ##################################

## Requests from FEAGI a dict of all morphologies in the genome and each type.
## Triggers an update in FEAGI Cached morphologies, which cascades to signals for morphologies added / removed
func refresh_morphology_list() -> void:
	_feagi_interface.calls.GET_MO_list_types()
