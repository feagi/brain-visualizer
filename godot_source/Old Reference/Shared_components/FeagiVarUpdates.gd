extends Node
# Autoloaded object (Named "FeagiVarUpdates") to store all signals that are emitted when a variable changes

# Broad FEAGI
signal burstEngine_stimulationPeriod(burstRate: float)
signal genome_fileName(fileName: StringName)
signal genome_morphologyList(morphologyArray: PackedStringArray)
signal genome_corticalMap(corticalMap: Dictionary)
signal genome_corticalLocations2D(corticalLocations: Dictionary)
signal healthCheck(serviceStatuses: Dictionary)
signal connectome_corticalAreas_list_detailed(corticalAreasMappings: Dictionary)


# Internal Broad
signal Internal_corticalMapSummary(summary: Dictionary)

# Specific
signal corticalAreaUpdated( corticalArea: CorticalArea)
signal morphologyUpdated( morphology: MorphologyBase)

