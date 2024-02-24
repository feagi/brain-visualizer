extends Node
## AUTOLOADED
## Essentially a collection of signals when a change FEAGI state (that is NOT cached) is detected
## Primarily used in cases of getting most recent info from FEAGI

## FEAGI reloaded its genome
signal genome_is_about_to_reset()

## We got visualization data from Websocket for BV
signal retrieved_visualization_data(data: Array)

## When we get a listing of circuits
signal retrieved_circuit_listing(circuit_file_names: PackedStringArray)

## When amppings between 2 areas are updated
signal when_mappings_confirmed_updated(source_area: BaseCorticalArea, destination_area: BaseCorticalArea)

## We got details of a specific circuit
signal retrieved_circuit_details(circuit_details: CircuitDetails)

## Emits when we retrieved the latest list of morphologies from feagi
signal retrieved_latest_morphology_listing(morphologies: Array[String])
## Emits when we retrieved arrays of source -> destination mappings (each are 2 element array themselves), and the accompying relevant morphology it relates to
signal retrieved_latest_usuage_of_morphology(relevant_morphology: Morphology, usage: Array[Array])

signal retrieved_latest_latency(latency_in_ms: int)

## Retrieved latest health info
signal retrieved_latest_FEAGI_health(burst_engine: bool, genome_availibility: bool, genome_validity: bool, brain_readiness: bool)

## User selected a cortical area in BV or CB
signal user_selected_cortical_area(cortical_area: BaseCorticalArea)
# TODO this should be moved to the UI manager
