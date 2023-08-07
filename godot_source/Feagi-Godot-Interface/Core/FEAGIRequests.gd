extends Node
## AUTOLOADED
## General actions to request of FEAGI
var _feagi_interface: FEAGIInterface # MUST be set ASAP or the below will crash!


# Cortical Areas

# Morphologies

func refresh_morphology_list() -> void:
    _feagi_interface.calls.GET_GE_morphologyList()