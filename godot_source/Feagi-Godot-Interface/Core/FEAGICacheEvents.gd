extends Node
## AUTOLOADED
## Essentially a collection of signals when a change in cached FEAGI state (or dependent internal variables) change


################################# Morphologies ##################################
signal morphology_added(new_morphology: Morphology) # For when singular morphology is added
signal morphology_removed(removed_morphology: Morphology)  # For when singular morphology is added
signal morphology_updated(updated_morphology: Morphology) # For when a morphology is updated in cache (COMMON USE: morphology objects are init'd with placeholder values until FEAGI responds with the correct one)


