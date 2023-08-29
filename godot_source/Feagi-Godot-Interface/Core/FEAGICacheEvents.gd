extends Node
## AUTOLOADED
## Essentially a collection of signals when a change in cached FEAGI state (or dependent internal variables) change


################################# Morphologies ##################################
signal morphology_added(new_morphology: Morphology) # For when singular morphology is added
signal morphology_removed(removed_morphology: Morphology)  # For when singular morphology is removed
signal morphology_updated(updated_morphology: Morphology) # For when a morphology is updated in cache (COMMON USE: morphology objects are init'd with placeholder values until FEAGI responds with the correct one)

################################ Cortical Areas #################################
signal cortical_area_added(new_cortical_area: CorticalArea) # For when singular cortical area is added
signal cortical_area_removed(removed_cortical_area: CorticalArea)  # For when singular cortical area is removed
signal cortical_area_updated(updated_cortical_area: CorticalArea) # For when a cortical area is updated in cache (COMMON USE: cortical area objects are init'd with placeholder values until FEAGI responds with the correct one)

############################# Cortical Connections ##############################
signal cortical_areas_connected(source_cortical_area: StringName, destination_cortical_area: StringName, number_of_mappings: int) # When two cortical areas are connected
signal cortical_areas_disconnected(source_cortical_area: StringName, destination_cortical_area: StringName) # When an existing conneciton is removed completely
signal cortical_areas_connection_modified(source_cortical_area: StringName, destination_cortical_area: StringName, number_of_mappings: int) # When an existing connection between 2 cortical areas is modified

################################ Feagi General ##################################
signal delay_between_bursts_updated(seconds_delay_between_bursts: float) # The delay from one activity burst to the next, in seconds
signal available_circuit_listing_updated(available_circuits: PackedStringArray) # The available circuits available, by name
