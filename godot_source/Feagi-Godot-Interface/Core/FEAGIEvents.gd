extends Node
## AUTOLOADED
## Essentially a collection of signals when a change FEAGI state (that is NOT cached) is detected
## Primarily used in cases of getting most recent info from FEAGI

signal genome_was_reset()
signal retrieved_visualization_data(data: Array)
signal retrieved_circuit_size(circuit_name: StringName, size_whd: Vector3i)