extends Node
## AUTOLOADED
## Essentially a collection of signals when a change FEAGI state (that is NOT cached) is detected
## Primarily used in cases of getting most recent info from FEAGI

## FEAGI reloaded its genome
signal genome_was_reset()

## We got visualization data from Websocket for BV
signal retrieved_visualization_data(data: Array)


signal retrieved_mapping_information(source_area: CorticalArea, destination_area: CorticalArea, mappings: CorticalMappingProperties)
