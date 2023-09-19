extends Node
## AUTOLOADED
## Essentially a collection of signals when a change FEAGI state (that is NOT cached) is detected
## Primarily used in cases of getting most recent info from FEAGI

## FEAGI reloaded its genome
signal genome_is_about_to_reset()

## We got visualization data from Websocket for BV
signal retrieved_visualization_data(data: Array)
signal retrieved_circuit_size(circuit_name: StringName, size_whd: Vector3i)
#signal retrieved_mapping_information(source_area: CorticalArea, destination_area: CorticalArea, mappings: CorticalMappingProperties)

## Emits when we retrieved the latest list of morphologies from feagi
signal retrieved_latest_morphology_listing(morphologies: Array[String])
## Emits when we retrieved arrays of source -> destination mappings (each are 2 element array themselves), and the accompying relevant morphology it relates to
signal retrieved_latest_usuage_of_morphology(relevant_morphology: Morphology, usage: Array[Array])
