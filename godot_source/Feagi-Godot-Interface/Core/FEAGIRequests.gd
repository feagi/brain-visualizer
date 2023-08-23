extends Node
## AUTOLOADED
## General actions to request of FEAGI
## Try to use the functions here to call feagi actions instead of through FEAGIInterface


var _feagi_interface: FEAGIInterface # MUST be set ASAP externally or the below will crash!

################################ Cortical Areas #################################

## Requests from FEAGI summary of all cortical areas (name, dimensions, 2D/3D location, and visibility)
## Triggers an update in FEAGI Cached cortical areas, which cascades to signals for cortical areas added / removed
func refresh_cortical_areas() -> void:
	_feagi_interface.calls.GET_GE_CorticalArea_geometry() # This will afterwards trigger "refresh_connection_list()"



func delete_cortical_area(cortical_id: StringName) -> void:
	_feagi_interface.calls.DELETE_GE_corticalArea(cortical_id)


################################# Morphologies ##################################

## Requests from FEAGI a dict of all morphologies in the genome and each type.
## Triggers an update in FEAGI Cached morphologies, which cascades to signals for morphologies added / removed
func refresh_morphology_list() -> void:
	_feagi_interface.calls.GET_MO_list_types()


################################## Connections ##################################

## Requests from FEAGI a dict of all conneciton mappings between cortical areas, and the number of mappings per each
## Triggers an update in FEAGI cached connections, which cascades to signals for connections added and removed
## NOTE FOR STARTUP: This should be called after cortical areas have been loaded into memory, otherwise cortical ID references here will be invalid
func refresh_connection_list() -> void:
	_feagi_interface.calls.GET_GE_corticalMap()

################################# FEAGI General #################################


func refresh_delay_between_bursts() -> void:
	_feagi_interface.calls.GET_BU_stimulationPeriod()

func set_delay_between_bursts(delay_between_bursts_in_seconds: float) -> void:
	_feagi_interface.calls.POST_FE_burstEngine(delay_between_bursts_in_seconds)

