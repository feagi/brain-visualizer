extends RefCounted
class_name MappingsCache


var established_mappings: Dictionary: # Mappings Established in the FEAGI Connectom, key;d by source_cortical_ID -> destination_cortical_ID -> [MappingProperties]
	get: return _established_mappings


var _established_mappings: Dictionary
var _connection_chains: Dictionary



func FEAGI_established_mapping(source: BaseCorticalArea, destination: BaseCorticalArea, mappings: Array[MappingProperty]):
	pass

func get_mappings_from_source_cortical_area(source: BaseCorticalArea):
	pass

func get_mappings_toward_destination_cortical_area(destination: BaseCorticalArea):
	pass














