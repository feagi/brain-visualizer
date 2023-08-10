extends Node
## AUTOLOADED
## General actions to request of FEAGI
var _feagi_interface: FEAGIInterface # MUST be set ASAP or the below will crash!


# Cortical Areas


################################# Morphologies ##################################

## Requests from FEAGI a dict of all morphologies in the genome and each type.
## Triggers an update in FEAGI Cache morphologies, which cascades to signals for morphologies adde / removed
func refresh_morphology_list() -> void:
    _feagi_interface.calls.GET_MO_list_types()