extends Object
class_name CacheSignals

# Broad FEAGI
signal burstEngine_stimulationPeriod(burstRate: float)
signal genome_fileName(fileName: String)
signal genome_morphologyList(morphologyArray: PackedStringArray)
signal genome_corticalMap(corticalMap: Dictionary)
signal healthCheck(serviceStatuses: Dictionary)
signal connectome_corticalAreas_list_detailed(corticalAreasMappings: Dictionary)

# Specific
signal corticalAreaUpdated( corticalArea: CorticalArea)
signal morphologyUpdated( morphology: MorphologyBase)

